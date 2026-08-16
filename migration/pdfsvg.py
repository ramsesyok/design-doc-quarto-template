#!/usr/bin/env python3
"""提出用 PDF から、図をベクターの SVG として取り出す。

PowerPoint の図は、原本（.pptx）からは**形が取り出せない**。図形の文字は拾えても、
枠・矢印・配置は失われる。一方、提出用 PDF にはベクターのまま入っているため、
図に関してだけは PDF が最良の入力元になる。

本スクリプトはページ単位で SVG を書き出す。ラスタライズは起きない。
PowerPoint も LibreOffice も要らない。

必要なもの
----------
PyMuPDF（``pip install pymupdf``）。

どのページが図か
----------------
Word ＋ PowerPoint の結合 PDF では、本文ページと PPT 由来ページで**用紙サイズや
向きが違う**ことが多い。まず ``--list`` で確認してから選別する::

    python migration/pdfsvg.py 提出版.pdf --list

出力例::

    ページサイズの分布
      595 x 842 (縦)  41 ページ  ← 最も多いので本文とみなす
      842 x 595 (横)   7 ページ

    ページ  サイズ        文字  描画  画像  判定
         9  842x595 (横)   210    31     0  別サイズ
        26  595x842 (縦)  1050    16     0  本文

使い方
------
    python migration/pdfsvg.py 提出版.pdf --list
    python migration/pdfsvg.py 提出版.pdf -o docs/diagrams --landscape --md figures.md
    python migration/pdfsvg.py 提出版.pdf -o docs/diagrams --pages 9,12-15

文字の扱い
----------
既定は**文字を文字のまま**残す（軽く、検索も効く）。ただし閲覧側に同じフォントが
無いと字形がずれる。配布先のフォント環境が読めないときは ``--outline-text`` を付けて
輪郭化する。自己完結する代わりに 7 倍ほど重くなる。
"""

from __future__ import annotations

import argparse
import re
import sys
from collections import Counter
from pathlib import Path

try:
    import fitz  # PyMuPDF
except ImportError:
    print("エラー: PyMuPDF がありません。`pip install pymupdf` を実行してください。", file=sys.stderr)
    raise SystemExit(1)


def parse_pages(spec: str, total: int) -> list:
    """"3-7,12" のような指定を 0 始まりのページ番号リストにする。"""
    pages = []
    for chunk in spec.split(","):
        chunk = chunk.strip()
        if not chunk:
            continue
        m = re.match(r"^(\d+)\s*-\s*(\d+)$", chunk)
        if m:
            start, end = int(m.group(1)), int(m.group(2))
            if start > end:
                start, end = end, start
            pages.extend(range(start - 1, end))
        elif chunk.isdigit():
            pages.append(int(chunk) - 1)
        else:
            raise SystemExit(f"エラー: ページ指定 '{chunk}' を解釈できません。")
    out = sorted({p for p in pages if 0 <= p < total})
    if not out:
        raise SystemExit("エラー: 指定されたページが範囲内にありません。")
    return out


def _size_key(page) -> tuple:
    return (round(page.rect.width), round(page.rect.height))


def survey(doc) -> list:
    """ページごとの素性を集める。"""
    rows = []
    for index, page in enumerate(doc):
        text = page.get_text().strip()
        try:
            drawings = len(page.get_drawings())
        except Exception:
            drawings = 0
        rows.append({
            "index": index,
            "size": _size_key(page),
            "landscape": page.rect.width > page.rect.height,
            "chars": len(re.sub(r"\s", "", text)),
            "drawings": drawings,
            "images": len(page.get_images(full=True)),
        })
    return rows


def classify(rows) -> tuple:
    """本文サイズを推定し、各ページに判定を付ける。"""
    counts = Counter(r["size"] for r in rows)
    body_size = counts.most_common(1)[0][0] if counts else None
    for r in rows:
        if r["size"] != body_size:
            r["verdict"] = "別サイズ"
        elif r["chars"] < 200 and r["drawings"] >= 20:
            r["verdict"] = "図が主体"
        else:
            r["verdict"] = "本文"
    return body_size, counts


def render_list(rows, counts, body_size, stream) -> None:
    stream.write("ページサイズの分布\n")
    for size, count in counts.most_common():
        orient = "横" if size[0] > size[1] else "縦"
        mark = "  ← 最も多いので本文とみなす" if size == body_size else ""
        stream.write(f"  {size[0]} x {size[1]} ({orient})  {count} ページ{mark}\n")
    stream.write("\n")

    stream.write("ページ  サイズ           文字   描画  画像  判定\n")
    for r in rows:
        orient = "横" if r["landscape"] else "縦"
        size = f"{r['size'][0]}x{r['size'][1]} ({orient})"
        stream.write(f"{r['index'] + 1:>6}  {size:<15} {r['chars']:>5} {r['drawings']:>6} "
                     f"{r['images']:>5}  {r['verdict']}\n")
    stream.write("\n")

    candidates = [r["index"] + 1 for r in rows if r["verdict"] != "本文"]
    if candidates:
        spec = ",".join(str(p) for p in candidates)
        stream.write(f"図の候補: {len(candidates)} ページ\n")
        stream.write(f"  --pages {spec}\n")
    else:
        stream.write("図の候補は見つかりませんでした。--pages で明示的に指定してください。\n")


def _trim_box(page):
    """描画と文字が占める範囲を求め、少しだけ余白を足す。"""
    box = None
    for block in page.get_text("blocks"):
        rect = fitz.Rect(block[:4])
        box = rect if box is None else box | rect
    try:
        for drawing in page.get_drawings():
            rect = drawing.get("rect")
            if rect:
                box = rect if box is None else box | rect
    except Exception:
        pass
    if box is None or box.is_empty:
        return None
    box = fitz.Rect(box.x0 - 6, box.y0 - 6, box.x1 + 6, box.y1 + 6)
    return box & page.rect


def export(doc, pages, outdir: Path, prefix: str, outline_text: bool, trim: bool) -> list:
    outdir.mkdir(parents=True, exist_ok=True)
    written = []
    for index in pages:
        page = doc[index]
        if trim:
            box = _trim_box(page)
            if box is not None and not box.is_empty:
                page.set_cropbox(box)
        svg = page.get_svg_image(text_as_path=outline_text)
        path = outdir / f"{prefix}{index + 1:03d}.svg"
        path.write_text(svg, encoding="utf-8")
        written.append((index, path, len(svg)))
    return written


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(
        description="提出用 PDF から、図をベクターの SVG として取り出す。",
        epilog="どのページを選ぶかは --list で確認する。詳しくは migration/README.md を参照。")
    parser.add_argument("source", help="入力の PDF")
    parser.add_argument("-o", "--out", metavar="DIR", help="SVG の出力先（例: docs/diagrams）")
    parser.add_argument("--list", action="store_true", dest="do_list",
                        help="ページ一覧を表示するだけ（選別に使う）")
    parser.add_argument("--pages", metavar="SPEC", help="ページ指定（例: 9,12-15。1始まり）")
    parser.add_argument("--landscape", action="store_true", help="横向きページだけを対象にする")
    parser.add_argument("--size", metavar="WxH", help="このサイズのページだけを対象にする（例: 842x595）")
    parser.add_argument("--exclude-body", action="store_true",
                        help="本文と判定されたページを除く")
    parser.add_argument("--outline-text", action="store_true",
                        help="文字を輪郭化する（フォント非依存になるが重くなる）")
    parser.add_argument("--trim", action="store_true", help="ページの余白を落とす")
    parser.add_argument("--prefix", default="p", help="出力ファイル名の接頭辞（既定: p）")
    parser.add_argument("--md", metavar="FILE", help="貼り付け用の markdown を書き出す")
    parser.add_argument("--image-prefix", default="/diagrams",
                        help="markdown に書く画像パスの前置き（既定: /diagrams）")
    args = parser.parse_args(argv)

    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")

    source = Path(args.source)
    if not source.exists():
        print(f"エラー: {source} がありません。", file=sys.stderr)
        return 1

    doc = fitz.open(source)
    rows = survey(doc)
    body_size, counts = classify(rows)

    if args.do_list:
        render_list(rows, counts, body_size, sys.stdout)
        return 0

    if not args.out:
        print("エラー: -o/--out が要ります（--list で確認するだけなら --list を付けてください）。",
              file=sys.stderr)
        return 1

    # ---- 対象ページを決める
    if args.pages:
        pages = parse_pages(args.pages, doc.page_count)
    else:
        pages = [r["index"] for r in rows]
        if args.landscape:
            pages = [i for i in pages if rows[i]["landscape"]]
        if args.size:
            m = re.match(r"^(\d+)\s*[xX×]\s*(\d+)$", args.size.strip())
            if not m:
                print(f"エラー: --size '{args.size}' を解釈できません（例: 842x595）。", file=sys.stderr)
                return 1
            want = (int(m.group(1)), int(m.group(2)))
            pages = [i for i in pages if rows[i]["size"] == want]
        if args.exclude_body:
            pages = [i for i in pages if rows[i]["verdict"] != "本文"]
        if not (args.landscape or args.size or args.exclude_body):
            print("警告: ページを絞っていないため、全 "
                  f"{doc.page_count} ページを書き出します。", file=sys.stderr)

    if not pages:
        print("エラー: 条件に合うページがありません。--list で確認してください。", file=sys.stderr)
        return 1

    written = export(doc, pages, Path(args.out), args.prefix, args.outline_text, args.trim)

    total = sum(size for _, _, size in written)
    print(f"{len(written)} ページを SVG に書き出しました（合計 {total / 1024:,.0f} KB）: {args.out}")
    for index, path, size in written[:10]:
        print(f"  p.{index + 1:<4} {path.name:<12} {size / 1024:>7,.0f} KB")
    if len(written) > 10:
        print(f"  … ほか {len(written) - 10} ページ")

    if args.md:
        landscape = {r["index"]: r["landscape"] for r in rows}
        lines = ["<!-- 提出用 PDF から取り出した図。キャプションと label を書き換えて使う。",
                 "     IPO 図とフローチャートは、貼らずに .ipo / mermaid へ作り直すこと。 -->", ""]
        for index, path, _size in written:
            image = (f"![（キャプションを書く）]({args.image_prefix}/{path.name})"
                     f"{{#fig-{path.stem} width=80%}}")
            if landscape.get(index):
                lines += ["::: {.landscape}", image, ":::", ""]
            else:
                lines += [image, ""]
        Path(args.md).write_text("\n".join(lines), encoding="utf-8")
        print(f"  貼り付け用: {args.md}")

    if not args.outline_text:
        print("\n文字は文字のまま残しています。閲覧側に同じフォントが無いと字形がずれます。")
        print("自己完結させるなら --outline-text を付けて出し直してください。")
    return 0


if __name__ == "__main__":
    sys.exit(main())
