#!/usr/bin/env python3
"""pandoc が出した markdown の表と図に、テンプレートの採番機構を載せる。

Word から変換した markdown には、「表1.1-1　ユーザ属性一覧」のような**手で振られた番号**が
文字列として残っている。本スクリプトはそれを拾って、

* 表を ``::: {.tbl caption="…" label="tbl-1-1-1"}`` で囲む
* 図に ``{#fig-1-1-1}`` を付け、画像パスを ``/diagrams/…`` へ書き換える
* 本文中の「表1.1-1」を ``@tbl-1-1-1`` へ置換する
* 元番号と label の対応表を出力する

に変換する。以後は番号がテンプレート側で自動採番され、図表を増減しても本文は直らない。

前提となる変換コマンド
----------------------
表の書式を固定し、行を折り返さないこと。simple table（罫線が空白揃えのもの）は
テキストからの検出が困難なため、拡張を切ってパイプ表・グリッド表に寄せる::

    quarto pandoc -f docx -t markdown-simple_tables-multiline_tables \\
        --wrap=none --track-changes=accept \\
        --extract-media=diagrams/ch01 第1章.docx -o ch01.md

使い方
------
    python migration/tbl.py ch01.md -o ch01.tbl.md --map refs.tsv

出力される対応表（``--map``）は、あとで参照の取りこぼしを追うときに使う。

やらないこと
------------
``merge-cols`` は付けない。Word の結合セルはグリッド表の結合として既に保存されており、
手で結合を書いたグリッド表に ``merge-cols`` は効かない（利用マニュアル9章）。
``widths`` も、元の列幅が変換で失われているため推測しない。
"""

from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

# 全角数字を ASCII に寄せる
ZEN2HAN = str.maketrans("０１２３４５６７８９", "0123456789")

# 「表1.1-1」「図 １－２」などの番号。区切りは半角・全角の点とダッシュを許す
NUM = r"[0-9０-９]+(?:[.．\-－‐−―ー][0-9０-９]+)*"

# キャプション行（「表1.1-1　ユーザ属性一覧」）
CAPTION = re.compile(rf"^(?P<kind>[表図])[ 　]*(?P<num>{NUM})[ 　.．、:：]*(?P<title>.*)$")

# 本文中の参照（「表1.1-1」「図 1.1-1」）
REFERENCE = re.compile(rf"(?P<kind>[表図])[ 　]*(?P<num>{NUM})")

# pandoc が出す表キャプション行（": …" または "Table: …"）
PANDOC_CAPTION = re.compile(r"^(?::|Table:)[ 　]+(?P<text>.+?)[ 　]*$")

# 画像（--wrap=none 前提で1行に収まる）
IMAGE = re.compile(r"!\[(?P<alt>[^\]]*)\]\((?P<src>[^)\s]+)(?P<title>\s+\"[^\"]*\")?\)(?P<attr>\{[^}]*\})?")

FENCE = re.compile(r"^(?P<indent>\s*)(?P<fence>```+|~~~+)")


@dataclass
class Definition:
    """図表番号1つぶんの定義。"""
    kind: str          # 表 / 図
    raw: str           # 元番号（1.1-1）
    key: str           # 正規化した番号（1-1-1）
    label: str         # tbl-1-1-1 / fig-1-1-1
    title: str
    line: int          # 定義があった行（1始まり）
    refs: int = 0      # 本文からの参照回数


@dataclass
class Result:
    text: str
    definitions: list = field(default_factory=list)
    unresolved: dict = field(default_factory=dict)   # 参照されたが定義の無い番号
    uncaptioned: int = 0                              # キャプションの無い表
    unnumbered: list = field(default_factory=list)    # キャプションはあるが番号が無い表


# ---------------------------------------------------------------- 補助

def _normalize(num: str) -> str:
    """「1.1-1」「１．１－１」を「1-1-1」に揃える。"""
    return re.sub(r"[.．\-－‐−―ー]", "-", num.translate(ZEN2HAN))


def _quote(text: str) -> str:
    """属性値に入れられる形にする（二重引用符は全角に逃がす）。"""
    return text.replace('"', "”").strip()


def _code_lines(lines) -> set:
    """フェンス付きコードブロックの行番号（0始まり）を集める。"""
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


def _is_grid_start(line: str) -> bool:
    return bool(re.match(r"^\s*\+[-=+:\s]+\+\s*$", line))


def _is_table_body(line: str) -> bool:
    stripped = line.lstrip()
    return stripped.startswith("|") or stripped.startswith("+")


def _find_tables(lines, code: set):
    """表ブロックの (開始行, 終了行) を返す。終了行は含む。"""
    blocks, i, n = [], 0, len(lines)
    while i < n:
        if i in code or not lines[i].strip():
            i += 1
            continue
        stripped = lines[i].lstrip()
        if _is_grid_start(lines[i]) or (stripped.startswith("|") and "|" in stripped[1:]):
            start = i
            while i < n and i not in code and _is_table_body(lines[i]):
                i += 1
            if i - start >= 2:          # 1行だけのものは表とみなさない
                blocks.append((start, i - 1))
            continue
        i += 1
    return blocks


def _looks_like_simple_table(lines, code: set) -> bool:
    """simple table（空白揃えの表）が残っていないか調べる。"""
    for i, line in enumerate(lines):
        if i in code:
            continue
        if re.match(r"^\s{2,}-{2,}(\s+-{2,})+\s*$", line):
            return True
    return False


# ---------------------------------------------------------------- 本体

def convert(text: str, image_prefix: str = "/diagrams") -> Result:
    lines = text.splitlines()
    code = _code_lines(lines)
    result = Result(text="")

    definitions: dict = {}          # (kind, key) -> Definition
    used_labels: set = set()
    caption_lines: set = set()      # 参照置換の対象から外す行
    table_caption: dict = {}        # 表の開始行 -> (Definition or None, caption 文字列, 消す行)

    def _define(kind: str, raw: str, title: str, line_no: int):
        key = _normalize(raw)
        prefix = "tbl" if kind == "表" else "fig"
        label = f"{prefix}-{key}"
        if label in used_labels:                     # 同じ番号が二度出た場合の逃げ道
            suffix = 2
            while f"{label}-{suffix}" in used_labels:
                suffix += 1
            label = f"{label}-{suffix}"
        used_labels.add(label)
        definition = Definition(kind=kind, raw=raw, key=key, label=label,
                                title=title, line=line_no + 1)
        definitions[(kind, key)] = definition
        return definition

    # ---- 第1パス: 表とキャプションを対応づける
    for start, end in _find_tables(lines, code):
        caption_index = None
        probe = end + 1
        while probe < len(lines) and not lines[probe].strip():
            probe += 1
        if probe < len(lines) and probe not in code:
            m = PANDOC_CAPTION.match(lines[probe])
            if m:
                caption_index = probe
        if caption_index is None:                    # 表の直前の段落も見る
            probe = start - 1
            while probe >= 0 and not lines[probe].strip():
                probe -= 1
            if probe >= 0 and probe not in code and CAPTION.match(lines[probe].strip()):
                caption_index = probe

        if caption_index is None:
            result.uncaptioned += 1
            continue

        raw_caption = lines[caption_index].strip()
        m = PANDOC_CAPTION.match(raw_caption)
        caption_text = m.group("text") if m else raw_caption

        c = CAPTION.match(caption_text)
        if c:
            definition = _define("表", c.group("num"), c.group("title").strip(), start)
            table_caption[start] = (definition, c.group("title").strip(), caption_index)
        else:
            result.unnumbered.append(caption_text)
            table_caption[start] = (None, caption_text, caption_index)
        caption_lines.add(caption_index)

    # ---- 第1パス（図）: 画像の alt、無ければ隣接する段落から番号を拾う
    #
    # pandoc は Word の図表番号スタイルを alt に畳み込むことが多いが、素の段落として
    # 書かれた図番号は画像の次（まれに前）の行に取り残される。両方を見る。
    table_body = {i for start, end in _find_tables(lines, code) for i in range(start, end + 1)}
    image_defs: dict = {}           # 画像の行番号 -> Definition
    image_caption: dict = {}        # 画像の行番号 -> 捨てるキャプション行

    def _probe(index: int, step: int):
        """index から step 方向へ、空行を飛ばして最初の実行を返す。"""
        probe = index + step
        while 0 <= probe < len(lines) and not lines[probe].strip():
            probe += step
        if not (0 <= probe < len(lines)):
            return None
        if probe in code or probe in caption_lines or probe in table_body:
            return None
        return probe

    for i, line in enumerate(lines):
        if i in code:
            continue
        m = IMAGE.search(line)
        if not m:
            continue

        c = CAPTION.match(m.group("alt").strip())
        if c:
            image_defs[i] = _define("図", c.group("num"), c.group("title").strip(), i)
            caption_lines.add(i)
            continue

        for step in (1, -1):                          # 次の段落 → 前の段落の順で探す
            probe = _probe(i, step)
            if probe is None:
                continue
            c = CAPTION.match(lines[probe].strip())
            if c and c.group("kind") == "図":
                image_defs[i] = _define("図", c.group("num"), c.group("title").strip(), probe)
                image_caption[i] = probe
                caption_lines.add(probe)
                break

    # ---- 第2パス: 本文の参照を @label へ置換する
    def _replace(match):
        kind, raw = match.group("kind"), match.group("num")
        definition = definitions.get((kind, _normalize(raw)))
        if definition is None:
            result.unresolved.setdefault(f"{kind}{raw}", 0)
            result.unresolved[f"{kind}{raw}"] += 1
            return match.group(0)
        definition.refs += 1
        return f"@{definition.label}"

    for i, line in enumerate(lines):
        if i in code or i in caption_lines:
            continue
        lines[i] = REFERENCE.sub(_replace, line)

    # ---- 第3パス: 表を囲み、図に属性を付ける
    out = []
    skip = {index for _, _, index in table_caption.values()} | set(image_caption.values())
    starts = {start: (end, table_caption[start]) for start, end in _find_tables(lines, code)
              if start in table_caption}

    i = 0
    while i < len(lines):
        if i in skip:                                # 元のキャプション行は捨てる
            # 直前が空行、直後も空行なら片方を落として空行の重複を避ける
            if out and not out[-1].strip() and i + 1 < len(lines) and not lines[i + 1].strip():
                i += 1
            i += 1
            continue

        if i in starts:
            end, (definition, title, _) = starts[i]
            attrs = [".tbl", f'caption="{_quote(title)}"']
            if definition is not None:
                attrs.append(f'label="{definition.label}"')
            out.append("::: {" + " ".join(attrs) + "}")
            out.extend(lines[i:end + 1])
            out.append(":::")
            i = end + 1
            continue

        if i in image_defs:
            definition = image_defs[i]
            out.append(_rewrite_image(lines[i], definition, image_prefix))
            i += 1
            continue

        line = lines[i]
        if i not in code and IMAGE.search(line):     # 番号の無い画像もパスだけ直す
            line = _rewrite_image(line, None, image_prefix)
        out.append(line)
        i += 1

    result.text = "\n".join(out) + "\n"
    result.definitions = sorted(definitions.values(), key=lambda d: d.line)
    return result


def _rewrite_image(line: str, definition, image_prefix: str) -> str:
    """画像のパスを /diagrams/… に直し、必要なら {#fig-x} を付ける。"""
    def _sub(m):
        src = m.group("src")
        if not re.match(r"^([a-zA-Z]+:|/|#)", src):          # 相対パスだけ書き換える
            src = src.lstrip("./")
            root = image_prefix.strip("/")
            src = f"/{src}" if src.startswith(root + "/") else f"{image_prefix}/{src}"
        alt = m.group("alt")
        attr = m.group("attr") or ""
        if definition is not None:
            alt = definition.title
            inner = attr[1:-1].strip() if attr else ""
            # 既存の属性から幅指定は捨てる（元の実寸は版面に合わないことが多い）
            inner = re.sub(r"\b(width|height)=\"[^\"]*\"\s*", "", inner).strip()
            attr = "{" + " ".join(x for x in (f"#{definition.label}", inner) if x) + "}"
        return f"![{alt}]({src}){attr}"
    return IMAGE.sub(_sub, line)


# ---------------------------------------------------------------- 入出力

def _write_map(path: Path, definitions) -> None:
    with open(path, "w", encoding="utf-8", newline="") as fh:
        fh.write("種別\t元番号\tlabel\tタイトル\t定義行\t参照回数\n")
        for d in definitions:
            fh.write(f"{d.kind}\t{d.kind}{d.raw}\t{d.label}\t{d.title}\t{d.line}\t{d.refs}\n")


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(
        description="markdown の表・図に .tbl と {#fig-x} を付け、本文の参照を @label へ置換する。",
        epilog="前提となる pandoc の変換コマンドは migration/README.md を参照。")
    parser.add_argument("source", help="入力の markdown（pandoc の出力）")
    parser.add_argument("-o", "--out", help="出力先（既定: 標準出力）")
    parser.add_argument("--map", metavar="FILE", help="元番号と label の対応表を書き出す（TSV）")
    parser.add_argument("--image-prefix", default="/diagrams",
                        help="画像パスの前置き（既定: /diagrams）")
    args = parser.parse_args(argv)

    source = Path(args.source)
    if not source.exists():
        print(f"エラー: {source} がありません。", file=sys.stderr)
        return 1

    text = source.read_text(encoding="utf-8")
    lines = text.splitlines()
    if _looks_like_simple_table(lines, _code_lines(lines)):
        print("警告: simple table（空白揃えの表）らしき行があります。", file=sys.stderr)
        print("      -t markdown-simple_tables-multiline_tables を付けて変換し直してください。", file=sys.stderr)

    result = convert(text, image_prefix=args.image_prefix)

    if args.out:
        Path(args.out).write_text(result.text, encoding="utf-8")
    else:
        if hasattr(sys.stdout, "reconfigure"):
            sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        sys.stdout.write(result.text)

    if args.map:
        _write_map(Path(args.map), result.definitions)

    # ---- 作業結果の要約は標準エラーへ（出力を汚さない）
    tables = sum(1 for d in result.definitions if d.kind == "表")
    figures = sum(1 for d in result.definitions if d.kind == "図")
    total_refs = sum(d.refs for d in result.definitions)
    print(f"表 {tables} 件・図 {figures} 件に採番を付け、本文の参照 {total_refs} 箇所を @label へ置換しました。",
          file=sys.stderr)

    orphans = [d for d in result.definitions if d.refs == 0]
    if orphans:
        print(f"  参照されていない図表が {len(orphans)} 件あります（本文から引かれていない）:", file=sys.stderr)
        for d in orphans[:10]:
            print(f"    {d.kind}{d.raw}  {d.title}（{d.line} 行目）", file=sys.stderr)
    if result.unresolved:
        print(f"  定義の見つからない参照が {len(result.unresolved)} 種あります（手で確認が要る）:", file=sys.stderr)
        for raw, count in list(result.unresolved.items())[:10]:
            print(f"    {raw} … {count} 箇所", file=sys.stderr)
    if result.uncaptioned:
        print(f"  キャプションの無い表が {result.uncaptioned} 件あります（素の表のまま残しました）。", file=sys.stderr)
    if result.unnumbered:
        print(f"  番号の無いキャプションが {len(result.unnumbered)} 件あります（caption だけ付けました）:", file=sys.stderr)
        for caption in result.unnumbered[:5]:
            print(f"    {caption}", file=sys.stderr)
    if args.map:
        print(f"  対応表: {args.map}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
