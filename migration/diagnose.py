#!/usr/bin/env python3
"""既存設計書（Word / PowerPoint）の移行コストを、変換する前に見積もる。

OOXML（.docx / .pptx）の zip を直接読むだけなので、pandoc も外部ライブラリも要らない。
原本を1つも変換しないまま、「どのファイルが安く、どのファイルが高いか」を数字にする。

使い方
------
    python migration/diagnose.py <ファイルまたはフォルダ> [...]
    python migration/diagnose.py C:/work/原本 --out shindan.md
    python migration/diagnose.py C:/work/原本 --format csv --out shindan.csv

読み方
------
**見出し（スタイル）** が移行コストを最も左右する。
Word の「見出し1〜9」スタイルで書かれた段落の数である。ここが 0 のファイルは、
太字＋フォントサイズの直接書式で見出しを表現しており、pandoc に掛けると
**全部が平坦な段落になる**。章立てを一から起こす作業が発生するため「高」と判定する。

**疑似見出し** は、見出しスタイルを使っていないが見出しらしく見える段落
（短い・太字または本文より大きい）の数である。これが見出しスタイルの数を
上回るなら、スタイルと直接書式が混在している。

**図形** は、テキストボックス・オートシェイプ・SmartArt・グラフの概数である。
これらは pandoc の変換で**跡形もなく消える**。数が多いファイルは、提出用 PDF から
図を回収する作業が別途要る。

**図表番号** は本文中に手で書かれた「図3.2-1」「表 7-1」の異なり数である。
テンプレートの `{#fig-x}` / `@fig-x` へ載せ替える対象そのものであり、
自動化できない層 C の作業量を直接表す。

判定
----
| 判定 | 条件 | 意味 |
|------|------|------|
| 低   | 見出しスタイルが主 | ほぼ pandoc 任せで流し込める |
| 中   | スタイルと直接書式が混在 | 見出しの振り直しが部分的に要る |
| 高   | 見出しスタイル未使用 | 章立てを一から起こす |

判定は層 A（文章・表）の話であり、図形と図表番号の数は判定に含めていない。
それらは層 B・層 C の作業量として別に読むこと。
"""

from __future__ import annotations

import argparse
import csv
import json
import re
import sys
import zipfile
from collections import Counter
from dataclasses import dataclass, field, asdict
from pathlib import Path
import xml.etree.ElementTree as ET

# 本文中に手で書かれた図表番号（「図3.2-1」「表 7-1」「図１－２」など）
FIGREF = re.compile(r"[図表][ 　]*[0-9０-９]+(?:[.．\-－‐−―ー][ 　]*[0-9０-９]+)*")

# 見出しスタイル名（英語版 Word / 日本語版 Word の両方）
HEADING_NAME = re.compile(r"^(?:heading\s*([1-9])|見出し\s*([1-9]))$", re.IGNORECASE)


# ---------------------------------------------------------------- XML ユーティリティ

def _local(tag: str) -> str:
    """名前空間を除いたタグ名を返す。"""
    return tag.rsplit("}", 1)[-1] if "}" in tag else tag


def _family(tag: str) -> str:
    """タグの名前空間を、扱いやすい短い記号に丸める。

    OOXML には strict / transitional で URI の違う版があるため、URI の完全一致では
    照合しない。含まれる語で判定する。
    """
    if not tag.startswith("{"):
        return ""
    uri = tag[1:tag.index("}")]
    if "wordprocessingShape" in uri:
        return "wps"
    if "wordprocessingml" in uri:
        return "w"
    if "presentationml" in uri:
        return "p"
    if "markup-compatibility" in uri:
        return "mc"
    if "/math" in uri:
        return "m"
    if "vml" in uri:
        return "v"
    if "drawingml" in uri:
        return "a"
    return ""


def _attr(el: ET.Element, name: str):
    """名前空間を無視して属性を引く。"""
    for key, value in el.attrib.items():
        if _local(key) == name:
            return value
    return None


def _parent_map(root: ET.Element) -> dict:
    return {child: parent for parent in root.iter() for child in parent}


def _ancestors(el: ET.Element, parents: dict):
    cur = parents.get(el)
    while cur is not None:
        yield cur
        cur = parents.get(cur)


def _text_of(el: ET.Element) -> str:
    """配下のテキストノード（w:t / a:t）を連結する。"""
    return "".join(t.text or "" for t in el.iter() if _local(t.tag) == "t")


def _parse(zf: zipfile.ZipFile, name: str):
    try:
        return ET.fromstring(zf.read(name))
    except (KeyError, ET.ParseError):
        return None


# ---------------------------------------------------------------- 診断結果

@dataclass
class Report:
    path: str
    kind: str                      # docx / pptx / error
    verdict: str = ""              # 低 / 中 / 高 / －
    notes: list = field(default_factory=list)
    error: str = ""

    # docx
    paragraphs: int = 0
    headings: int = 0
    heading_levels: dict = field(default_factory=dict)
    pseudo_headings: int = 0
    tables: int = 0
    merged_cells: int = 0
    shapes: int = 0
    images: int = 0
    equations: int = 0
    figrefs: int = 0
    revisions: int = 0
    chars: int = 0

    # pptx
    slides: int = 0
    titled_slides: int = 0
    connectors: int = 0
    noted_slides: int = 0
    diagram_slides: int = 0

    @property
    def rank(self) -> int:
        """着手順の並べ替えキー（安いものが先）。"""
        return {"低": 0, "中": 1, "高": 2}.get(self.verdict, 3)


# ---------------------------------------------------------------- docx

def _heading_styles(zf: zipfile.ZipFile) -> dict:
    """styles.xml から「styleId → 見出しレベル」の対応を作る。

    日本語版 Word は styleId が `a3` のような機械的な名前になることがあるため、
    styleId ではなく w:name と w:outlineLvl で見出しかどうかを判定する。
    """
    root = _parse(zf, "word/styles.xml")
    if root is None:
        return {}

    result = {}
    for style in root.iter():
        if _local(style.tag) != "style" or _attr(style, "type") != "paragraph":
            continue
        style_id = _attr(style, "styleId")
        if not style_id:
            continue

        level = None
        for child in style.iter():
            tag = _local(child.tag)
            if tag == "name":
                m = HEADING_NAME.match((_attr(child, "val") or "").strip())
                if m:
                    level = int(m.group(1) or m.group(2))
            elif tag == "outlineLvl" and level is None:
                try:
                    outline = int(_attr(child, "val"))
                except (TypeError, ValueError):
                    continue
                if 0 <= outline <= 8:
                    level = outline + 1
        if level is not None:
            result[style_id] = level
    return result


def _analyze_docx(path: Path, zf: zipfile.ZipFile) -> Report:
    rep = Report(path=str(path), kind="docx")

    root = _parse(zf, "word/document.xml")
    if root is None:
        rep.kind = "error"
        rep.error = "word/document.xml を読めない（.docx ではないか、破損している）"
        return rep

    heading_styles = _heading_styles(zf)
    parents = _parent_map(root)
    body_text = []

    # 本文のフォントサイズ（半ポイント単位）の最頻値を「本文の大きさ」とみなす
    sizes = Counter()
    for el in root.iter():
        if _family(el.tag) == "w" and _local(el.tag) == "sz":
            try:
                sizes[int(_attr(el, "val"))] += 1
            except (TypeError, ValueError):
                pass
    body_sz = sizes.most_common(1)[0][0] if sizes else 21  # 既定 10.5pt

    def _inside(el, *names) -> bool:
        return any(_local(a.tag) in names for a in _ancestors(el, parents))

    for el in root.iter():
        family, tag = _family(el.tag), _local(el.tag)

        if family == "w" and tag == "p":
            # 図形やテキストボックスの中の段落は本文ではない
            if _inside(el, "txbxContent"):
                continue

            text = _text_of(el).strip()
            body_text.append(text)

            style_id = None
            for child in el.iter():
                if _local(child.tag) == "pStyle":
                    style_id = _attr(child, "val")
                    break

            level = heading_styles.get(style_id) if style_id else None
            if level is not None:
                rep.headings += 1
                rep.heading_levels[level] = rep.heading_levels.get(level, 0) + 1
                rep.paragraphs += 1
                continue

            rep.paragraphs += 1

            # 見出しスタイルを使っていない「見出しらしい段落」を数える。
            # 表のセルは短く太字になりがちなので対象から外す。
            if text and len(text) <= 40 and not _inside(el, "tbl"):
                bold = any(_local(c.tag) == "b" and _attr(c, "val") not in ("0", "false")
                           for c in el.iter())
                big = any(_local(c.tag) == "sz" and _int(_attr(c, "val")) >= body_sz + 4
                          for c in el.iter())
                if bold or big:
                    rep.pseudo_headings += 1

        elif family == "w" and tag == "tbl":
            rep.tables += 1
        elif family == "w" and tag in ("vMerge", "gridSpan"):
            rep.merged_cells += 1
        elif family == "w" and tag in ("ins", "del"):
            rep.revisions += 1
        elif family == "m" and tag == "oMath":
            rep.equations += 1

        # 図形・テキストボックス・SmartArt・グラフ。
        # mc:AlternateContent は同じ図形の新旧表現を包むので、それ自体を1個と数え、
        # 中の wps:wsp / v:shape は二重に数えない。
        elif family == "mc" and tag == "AlternateContent":
            rep.shapes += 1
        elif (family == "wps" and tag == "wsp") or (family == "v" and tag in ("shape", "group", "rect", "oval")):
            if not _inside(el, "AlternateContent"):
                rep.shapes += 1
        elif family == "a" and tag == "graphicData":
            uri = _attr(el, "uri") or ""
            if "diagram" in uri or "chart" in uri:
                rep.shapes += 1

    rep.images = sum(1 for n in zf.namelist() if n.startswith("word/media/"))

    joined = "\n".join(body_text)
    rep.chars = len(joined.replace("\n", ""))
    rep.figrefs = len({m.group(0).replace(" ", "").replace("　", "") for m in FIGREF.finditer(joined)})

    # ---- 判定（層 A のみ）
    if rep.headings == 0:
        rep.verdict = "高"
        rep.notes.append("見出しスタイルが1つも無い。変換すると全部が平坦な段落になるため、章立てを一から起こすことになる")
    elif rep.pseudo_headings > rep.headings:
        rep.verdict = "中"
        rep.notes.append(f"見出しスタイル {rep.headings} に対し、直接書式の見出しらしい段落が {rep.pseudo_headings} ある。混在している")
    else:
        rep.verdict = "低"

    if rep.shapes:
        rep.notes.append(f"図形・テキストボックス等 {rep.shapes} 個は変換で失われる。提出用 PDF から回収する")
    if rep.figrefs:
        rep.notes.append(f"手書きの図表番号 {rep.figrefs} 種は `label=` / `@fig-x` へ載せ替える（層 C）")
    if rep.merged_cells:
        rep.notes.append(f"結合セル {rep.merged_cells} 箇所は、グリッド表の結合としてそのまま保存される")
    if rep.revisions:
        rep.notes.append(f"変更履歴が {rep.revisions} 箇所ある。`--track-changes=accept` を付けて変換する")
    return rep


def _int(value) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        return 0


# ---------------------------------------------------------------- pptx

def _analyze_pptx(path: Path, zf: zipfile.ZipFile) -> Report:
    rep = Report(path=str(path), kind="pptx")

    slide_re = re.compile(r"^ppt/slides/slide(\d+)\.xml$")
    slides = sorted((n for n in zf.namelist() if slide_re.match(n)),
                    key=lambda n: int(slide_re.match(n).group(1)))
    if not slides:
        rep.kind = "error"
        rep.error = "ppt/slides/ が無い（.pptx ではないか、破損している）"
        return rep

    rep.slides = len(slides)
    texts = []

    for name in slides:
        root = _parse(zf, name)
        if root is None:
            continue

        shapes = connectors = pictures = tables = 0
        has_title = False

        for el in root.iter():
            family, tag = _family(el.tag), _local(el.tag)
            if family == "p" and tag == "sp":
                shapes += 1
            elif family == "p" and tag == "cxnSp":
                connectors += 1
            elif family == "p" and tag == "pic":
                pictures += 1
            elif family == "a" and tag == "tbl":
                tables += 1
            elif family == "p" and tag == "ph":
                if (_attr(el, "type") or "") in ("title", "ctrTitle"):
                    has_title = True

        rep.shapes += shapes
        rep.connectors += connectors
        rep.images += pictures
        rep.tables += tables
        rep.titled_slides += int(has_title)
        # コネクタがある、または図形が多いスライドは「図が主体」とみなす
        if connectors > 0 or shapes >= 6:
            rep.diagram_slides += 1
        texts.append(_text_of(root))

    # 発表者ノート（pandoc は落とすが python-pptx なら拾える）
    notes_re = re.compile(r"^ppt/notesSlides/notesSlide\d+\.xml$")
    for name in (n for n in zf.namelist() if notes_re.match(n)):
        root = _parse(zf, name)
        if root is not None and re.sub(r"[\s0-9]", "", _text_of(root)):
            rep.noted_slides += 1

    joined = "\n".join(texts)
    rep.chars = len(joined.replace("\n", ""))
    rep.figrefs = len({m.group(0).replace(" ", "").replace("　", "") for m in FIGREF.finditer(joined)})

    # ---- 判定（スライドのうちどれだけが「図」か）
    ratio = rep.diagram_slides / rep.slides if rep.slides else 0
    if ratio >= 0.6:
        rep.verdict = "高"
        rep.notes.append(f"{rep.slides} 枚中 {rep.diagram_slides} 枚が図主体。文字だけを変換しても図は失われるため、"
                         "IPO は `.ipo` に作り直し、それ以外は提出用 PDF から SVG で回収する")
    elif ratio >= 0.25:
        rep.verdict = "中"
        rep.notes.append(f"{rep.slides} 枚中 {rep.diagram_slides} 枚が図主体。図の扱いを1枚ずつ判断する")
    else:
        rep.verdict = "低"
        rep.notes.append("図主体のスライドが少ない。文字と表の抽出でおおむね移せる")

    if rep.titled_slides < rep.slides:
        rep.notes.append(f"タイトルプレースホルダの無いスライドが {rep.slides - rep.titled_slides} 枚ある。"
                         "見出しとして拾えないので、章立ては手で設計する")
    if rep.noted_slides:
        rep.notes.append(f"発表者ノートが {rep.noted_slides} 枚にある。pandoc は落とすので python-pptx で抽出する")
    if rep.connectors:
        rep.notes.append(f"コネクタ（矢印）が {rep.connectors} 本ある。これらは変換で完全に失われる")
    return rep


# ---------------------------------------------------------------- 走査

def _collect(targets, recurse: bool):
    """引数のパスから、診断対象のファイル一覧を作る。"""
    found = []
    for target in targets:
        path = Path(target)
        if path.is_dir():
            pattern = "**/*" if recurse else "*"
            found.extend(p for p in sorted(path.glob(pattern))
                         if p.suffix.lower() in (".docx", ".pptx", ".doc", ".ppt"))
        elif path.exists():
            found.append(path)
        else:
            found.append(path)  # 存在しないことをエラー行として報告する
    # Office のロックファイル（~$xxx.docx）は除く
    return [p for p in found if not p.name.startswith("~$")]


def analyze(path: Path) -> Report:
    if not path.exists():
        return Report(path=str(path), kind="error", error="ファイルが見つからない")

    suffix = path.suffix.lower()
    if suffix in (".doc", ".ppt"):
        return Report(path=str(path), kind="error",
                      error="旧形式（バイナリ）。Word / PowerPoint で .docx / .pptx に保存し直す必要がある")

    try:
        with zipfile.ZipFile(path) as zf:
            if suffix == ".docx":
                return _analyze_docx(path, zf)
            if suffix == ".pptx":
                return _analyze_pptx(path, zf)
            return Report(path=str(path), kind="error", error=f"対象外の拡張子（{suffix}）")
    except zipfile.BadZipFile:
        return Report(path=str(path), kind="error", error="zip として開けない（破損、またはパスワード保護）")
    except Exception as exc:  # 1ファイルの失敗で全体を止めない
        return Report(path=str(path), kind="error", error=f"{type(exc).__name__}: {exc}")


# ---------------------------------------------------------------- 出力

def _md_table(header, rows) -> list:
    out = ["| " + " | ".join(header) + " |",
           "|" + "|".join("---" for _ in header) + "|"]
    out.extend("| " + " | ".join(str(c) for c in row) + " |" for row in rows)
    return out


def render_md(reports) -> str:
    docs = [r for r in reports if r.kind == "docx"]
    ppts = [r for r in reports if r.kind == "pptx"]
    errs = [r for r in reports if r.kind == "error"]
    lines = ["# 移行コストの事前診断", ""]

    if docs:
        lines += ["## Word（.docx）", ""]
        lines += _md_table(
            ["ファイル", "段落", "見出し", "疑似見出し", "表", "結合", "図形", "画像", "数式", "図表番号", "判定"],
            [[Path(r.path).name, r.paragraphs, r.headings, r.pseudo_headings, r.tables,
              r.merged_cells, r.shapes, r.images, r.equations, r.figrefs, r.verdict] for r in docs])
        lines.append("")

    if ppts:
        lines += ["## PowerPoint（.pptx）", ""]
        lines += _md_table(
            ["ファイル", "スライド", "タイトル有", "図主体", "図形", "コネクタ", "表", "画像", "ノート", "判定"],
            [[Path(r.path).name, r.slides, r.titled_slides, r.diagram_slides, r.shapes,
              r.connectors, r.tables, r.images, r.noted_slides, r.verdict] for r in ppts])
        lines.append("")

    graded = [r for r in reports if r.kind in ("docx", "pptx")]
    if graded:
        lines += ["## 着手順（安いものから）", ""]
        for i, r in enumerate(sorted(graded, key=lambda r: (r.rank, r.shapes + r.figrefs)), 1):
            lines.append(f"{i}. **{Path(r.path).name}** — 判定 {r.verdict}")
            lines.extend(f"    - {note}" for note in r.notes)
        lines.append("")

        total_shapes = sum(r.shapes for r in graded)
        total_figrefs = sum(r.figrefs for r in graded)
        lines += ["## 合計", ""]
        lines += _md_table(
            ["項目", "値", "意味"],
            [["ファイル数", len(graded), f"Word {len(docs)} ／ PowerPoint {len(ppts)}"],
             ["本文の文字数", f"{sum(r.chars for r in graded):,}", "層 A の分量"],
             ["失われる図形", total_shapes, "層 B。提出用 PDF から回収する対象"],
             ["手書きの図表番号", total_figrefs, "層 C。`@fig-x` へ載せ替える対象（自動化できない）"]])
        lines.append("")

    if errs:
        lines += ["## 診断できなかったファイル", ""]
        lines += _md_table(["ファイル", "理由"],
                           [[Path(r.path).name, r.error] for r in errs])
        lines.append("")

    lines += ["---", "",
              "判定は層 A（文章・表）についてのものである。図形と図表番号の数は判定に含めていないので、",
              "層 B・層 C の作業量として別に読むこと。詳しくは `migration/README.md` を参照。"]
    return "\n".join(lines)


def render_csv(reports, stream) -> None:
    fields = ["path", "kind", "verdict", "paragraphs", "headings", "pseudo_headings",
              "tables", "merged_cells", "shapes", "images", "equations", "figrefs",
              "revisions", "chars", "slides", "titled_slides", "connectors",
              "noted_slides", "diagram_slides", "error"]
    writer = csv.DictWriter(stream, fieldnames=fields, extrasaction="ignore", lineterminator="\n")
    writer.writeheader()
    for r in reports:
        writer.writerow(asdict(r))


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(
        description="既存設計書（.docx / .pptx）の移行コストを、変換する前に見積もる。",
        epilog="判定の読み方は migration/README.md を参照。")
    parser.add_argument("targets", nargs="+", metavar="対象",
                        help="診断するファイル、またはフォルダ")
    parser.add_argument("--format", choices=("md", "csv", "json"), default="md",
                        help="出力形式（既定: md）")
    parser.add_argument("--out", metavar="FILE",
                        help="出力先ファイル（既定: 標準出力）。UTF-8 で書く")
    parser.add_argument("--no-recurse", action="store_true",
                        help="フォルダを再帰的に探さない")
    args = parser.parse_args(argv)

    paths = _collect(args.targets, recurse=not args.no_recurse)
    if not paths:
        print("診断対象の .docx / .pptx がありません。", file=sys.stderr)
        return 1

    reports = [analyze(p) for p in paths]

    if args.out:
        stream = open(args.out, "w", encoding="utf-8", newline="")
    else:
        stream = sys.stdout
        if hasattr(stream, "reconfigure"):
            # Windows の既定コードページでは日本語が化けるため UTF-8 に切り替える
            stream.reconfigure(encoding="utf-8", errors="replace")

    try:
        if args.format == "csv":
            render_csv(reports, stream)
        elif args.format == "json":
            json.dump([asdict(r) for r in reports], stream, ensure_ascii=False, indent=2)
            stream.write("\n")
        else:
            stream.write(render_md(reports) + "\n")
    finally:
        if args.out:
            stream.close()
            print(f"診断結果を書き出しました: {args.out}", file=sys.stderr)

    return 0


if __name__ == "__main__":
    sys.exit(main())
