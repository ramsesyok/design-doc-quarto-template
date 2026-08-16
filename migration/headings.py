#!/usr/bin/env python3
"""見出しに手で振られた章・節番号を削除する。

Word から変換した markdown の見出しには「## 1.1 目的」のように番号が文字列として
残っている。テンプレートは章番号を自動採番するため、そのままにすると二重になる。

誤爆をどう防ぐか
----------------
行頭の数字を機械的に消すと「## 2038年問題」のような正当なタイトルを壊す。
本スクリプトは、**番号が見出しの構造と辻褄が合っているときだけ**削除する。

1. **階層数が見出しレベルと一致するか** … ``## 1.1 目的`` はレベル2で番号も2階層。一致する。
2. **上位の見出しの番号と繋がっているか** … 第1章の下の ``## 3.11 の教訓`` は
   上位が「1」なのに番号が「3」で始まるため、章番号ではないと判断する。

どちらかを満たさない見出しは**削除せずに報告**する。番号らしき文字列が
見出しの一部である可能性を、機械では捨てきれないためである。

既定は dry-run（変更しない）。書き換えるには ``--apply`` を付ける。

使い方
------
    python migration/headings.py step1.md                      # 変更内容を確認する
    python migration/headings.py step1.md -o step2.md --apply  # 適用する
"""

from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass
from pathlib import Path

ZEN2HAN = str.maketrans("０１２３４５６７８９", "0123456789")

NUM = r"[0-9０-９]+(?:[.．][0-9０-９]+)*"

# 「第3章 システム構成」— 章・節・項の語があるので、後ろの空白は無くてよい
NUMBERED_WITH_UNIT = re.compile(
    rf"^(?:第[ 　]*)?(?P<num>{NUM})[ 　]*(?P<unit>[章節項編])[ 　]*[.．、:：]?[ 　]*(?P<title>\S.*)$")

# 「1.1 目的」「1. 概要」— 語が無いので、番号とタイトルの間に空白を要求する
NUMBERED_PLAIN = re.compile(
    rf"^(?P<num>{NUM})[ 　]*[.．、:：]?[ 　]+(?P<title>\S.*)$")

HEADING = re.compile(r"^(?P<hashes>#{1,6})[ 　]+(?P<text>.+?)[ 　]*$")
FENCE = re.compile(r"^(?P<indent>\s*)(?P<fence>```+|~~~+)")


@dataclass
class Change:
    line: int          # 1始まり
    level: int
    before: str
    after: str = ""
    ok: bool = False
    reason: str = ""


def _code_lines(lines) -> set:
    inside, marker, indent, result = False, "", "", set()
    for i, line in enumerate(lines):
        m = FENCE.match(line)
        if not inside and m:
            inside, marker, indent = True, m.group("fence")[0] * 3, m.group("indent")
            result.add(i)
        elif inside:
            result.add(i)
            if m and m.group("fence").startswith(marker) and len(m.group("indent")) <= len(indent) + 3:
                inside = False
    return result


def _parts(num: str):
    return num.translate(ZEN2HAN).replace("．", ".").split(".")


def plan(text: str):
    """見出しごとの削除可否を判定する。書き換えはしない。"""
    lines = text.splitlines()
    code = _code_lines(lines)
    changes = []
    # レベルごとに、直前に確定した番号（parts）を覚えておく
    seen: dict = {}

    for i, line in enumerate(lines):
        if i in code:
            continue
        h = HEADING.match(line)
        if not h:
            continue

        level = len(h.group("hashes"))
        body = h.group("text").strip()
        change = Change(line=i + 1, level=level, before=body)

        m = NUMBERED_WITH_UNIT.match(body) or NUMBERED_PLAIN.match(body)
        if not m:
            continue                                  # 番号が付いていない見出しは触らない

        parts = _parts(m.group("num"))
        title = m.group("title").strip()

        if not title:
            change.reason = "番号を取るとタイトルが残らない"
        elif len(parts) != level:
            change.reason = f"番号が{len(parts)}階層だが見出しはレベル{level}"
        elif level > 1 and seen.get(level - 1) is not None and parts[:-1] != seen[level - 1]:
            parent = ".".join(seen[level - 1])
            change.reason = f"上位の番号 {parent} と繋がっていない"
        else:
            change.ok = True
            change.after = title

        if change.ok:
            seen[level] = parts
            for deeper in [k for k in seen if k > level]:
                del seen[deeper]
        changes.append(change)

    return lines, code, changes


def apply(lines, changes):
    """判定 ok の見出しだけを書き換えた行の一覧を返す。"""
    out = list(lines)
    for change in changes:
        if not change.ok:
            continue
        index = change.line - 1
        h = HEADING.match(out[index])
        out[index] = f"{h.group('hashes')} {change.after}"
    return out


def _render_plan(changes, stream) -> None:
    good = [c for c in changes if c.ok]
    bad = [c for c in changes if not c.ok]

    if good:
        stream.write(f"削除する番号 {len(good)} 件\n\n")
        width = max(len(c.before) for c in good)
        for c in good:
            stream.write(f"  {c.line:>5}  {'#' * c.level:<6} {c.before:<{width}}  →  {c.after}\n")
        stream.write("\n")

    if bad:
        stream.write(f"削除しない見出し {len(bad)} 件（手で確認すること）\n\n")
        width = max(len(c.before) for c in bad)
        for c in bad:
            stream.write(f"  {c.line:>5}  {'#' * c.level:<6} {c.before:<{width}}  … {c.reason}\n")
        stream.write("\n")

    if not changes:
        stream.write("番号付きの見出しは見つかりませんでした。\n")


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(
        description="見出しに手で振られた章・節番号を削除する（既定は dry-run）。",
        epilog="判定の考え方は migration/README.md を参照。")
    parser.add_argument("source", help="入力の markdown")
    parser.add_argument("-o", "--out", help="出力先（--apply と併用する）")
    parser.add_argument("--apply", action="store_true",
                        help="実際に書き換える。付けない場合は変更内容を表示するだけ")
    args = parser.parse_args(argv)

    source = Path(args.source)
    if not source.exists():
        print(f"エラー: {source} がありません。", file=sys.stderr)
        return 1

    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")

    text = source.read_text(encoding="utf-8")
    lines, _code, changes = plan(text)
    _render_plan(changes, sys.stdout)

    if not args.apply:
        print("dry-run です。書き換えるには --apply を付けてください。")
        return 0

    if not args.out:
        print("エラー: --apply には -o/--out が要ります。", file=sys.stderr)
        return 1

    Path(args.out).write_text("\n".join(apply(lines, changes)) + "\n", encoding="utf-8")
    print(f"書き出しました: {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
