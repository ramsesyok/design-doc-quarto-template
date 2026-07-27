# Quarto 版のしくみ（PDF / 静的HTML の出力と様式調整）

**1つの qmd 一式から PDF と静的 HTML の両方**を出す仕組みと、どこを触れば何が
変わるかをまとめる。テンプレートを改修するとき最初に読む。

- 対象読者は**テンプレートを保守する人**（このファイルは `template/` に置く）。
  執筆者向けの記法は `README.md` を参照。
- 用語: 「様式」= 会社の紙のフォーマット（外枠・資料番号欄・社名・ページ番号）。

## 0. フォルダの分担

```
リポジトリ/
├── template/     ← 様式・変換・ビルドの実体（このフォルダ。執筆者は触らない）
│   ├── lib.typ, typst-template.typ, typst-show.typ, design-doc.lua, design-doc.css,
│   ├── postprocess-html.mjs, mermaid-config.json, package.json,
│   ├── setup.sh, setup.bat, build-qmd.sh, build-html.sh, render-diagrams.sh, PIPELINE.md
│   └── (setup 実行後: puppeteer.json / node_modules … いずれも .gitignore)
└── docs/         ← 執筆フォルダ（既定名。執筆者が改名してよい）
    ├── _quarto.yml, index.qmd, chapters/, diagrams/
    └── (setup/ビルド後: lib.typ, design-doc.css, _book/ … いずれも .gitignore)
```

- 執筆フォルダ名は自由（`docs` 以外でもよい）。ビルドは**リポジトリのルートから**
  `./template/build-qmd.sh <執筆フォルダ名>` で呼ぶ（省略時 `docs`）。
- `template/` と執筆フォルダは**兄弟**である前提。`_quarto.yml` は partial・filter を
  `../template/...` で参照する。`design-doc.lua` は**環境変数に依存せず**、
  `quarto.project.directory`（Quarto がフィルタに渡す）から執筆フォルダを、その隣の
  `../template` から template を自力で特定する。→ **ビルドスクリプトでも VSCode の
  Quarto 拡張（quarto preview / render）でも同じに動く**（§5 参照）。
- **setup（重要）**: 環境変数で渡せない2つだけは `setup.sh`/`setup.bat` が執筆フォルダへ
  **永続コピー**しておく（ビルドごとに消さず置きっぱなし。どちらも `.gitignore` 済み）:
  - `lib.typ` … typst の import が「プロジェクト外を読めない」制約に掛かるため（PDF）。
  - `design-doc.css` … Quarto がローカル css として `_book/` に取り込み、単体で配信・
    zip できるようにするため（HTML）。
  併せて setup は mermaid 用の Chrome/Edge を検出し `template/puppeteer.json` に記録する。
  ビルドスクリプトは先頭で setup を呼ぶので、拡張派・スクリプト派どちらも同じ状態になる。

---

## 1. 全体像

```
                    docs/chapters/**.qmd         ← 執筆者が書くのはここだけ
                    docs/_quarto.yml             ← 章の並び・出力設定
                              │
                              │  quarto render
                              ▼
                    ┌──────────────────┐
                    │  design-doc.lua  │  Pandoc フィルタ（FORMAT で分岐）
                    └────────┬─────────┘
              typst 出力      │      html 出力
        ┌─────────────────────┴────────────────────┐
        ▼                                          ▼
  typst-template.typ                        Quarto の book HTML 生成
  typst-show.typ      ← template-partials          │
        │                                          ▼
        ▼                                   postprocess-html.mjs
     lib.typ          ← 様式の単一ソース      （図表番号を PDF に合わせる）
        │                                          │
        ▼                                          ▼
  _book/*.pdf → design-doc.pdf              _book/（章ごとの HTML）
     ＝ 納品物                                  ＝ 社内レビュー用
```

**同じ qmd から2系統が出る**のが要点。執筆者の記法は完全に共通で、
分岐は `design-doc.lua` の `FORMAT` 判定1か所に閉じている。

### ビルドコマンド

```
# リポジトリのルートから実行する（末尾は執筆フォルダ名。省略すると docs）
./template/setup.sh docs         # 初回のみ（配置 + ブラウザ検出）。ビルドも内部で呼ぶ
./template/build-qmd.sh docs     # → docs/design-doc.pdf（納品物）
./template/build-html.sh docs    # → docs/_book/index.html（社内レビュー用）
```

どちらも執筆フォルダの `_book/` を出力先に使い、**後から走ったほうが前の出力を
消す**。そのため `build-qmd.sh` は PDF を `<執筆フォルダ>/design-doc.pdf` に取り出す。
両方を残したいときは PDF → HTML の順に実行する。

VSCode の Quarto 拡張から `quarto preview`/`render` を直接使う場合は、先に一度
`setup` を実行しておけば同じように出力できる（拡張はビルドスクリプトを経由しないため）。

---

## 2. ファイルの役割

場所欄: **docs** = 執筆フォルダ / **tpl** = `template/`。

| ファイル | 場所 | 役割 | 影響する出力 |
|---|---|---|---|
| `_quarto.yml` | docs | 章の並び、出力形式、画面幅（`grid:`）、資料番号 | 両方 |
| `index.qmd` | docs | 前付け（採番なし）。HTML のトップページ | 両方 |
| `chapters/**.qmd` | docs | 本文 | 両方 |
| `diagrams/` | docs | qmd が直接貼る静的図 + mermaid 生成 SVG の置き場 | 両方 |
| `design-doc.lua` | tpl | mermaid / `.landscape` / `.ipo` / セル結合 / 表幅 | 両方 |
| `typst-show.typ` | tpl | フロントマター → `design-doc()` の引数 | PDF |
| `typst-template.typ` | tpl | Quarto 既定テンプレートの差し替え口（`lib.typ` を import） | PDF |
| `lib.typ` | tpl | **様式の単一ソース**（枠・採番・IPO・横向き）。setup が docs へ永続コピー | PDF |
| `design-doc.css` | tpl | レビュー HTML の見た目。setup が docs へ永続コピー | HTML |
| `postprocess-html.mjs` | tpl | 図表番号を「章.節-連番」に振り直す | HTML |
| `mermaid-config.json` | tpl | mermaid のテーマ・`htmlLabels: false` | 両方 |
| `setup.sh` / `setup.bat` | tpl | 初期化: lib.typ/css の配置 + Chrome/Edge 検出→`puppeteer.json` | — |
| `puppeteer.json` | tpl | setup 生成の machine ローカル設定（ブラウザパス）。`.gitignore` 済み | mermaid |
| `build-qmd.sh` / `build-html.sh` | tpl | ビルド入口（引数 = 執筆フォルダ名。先頭で setup を呼ぶ） | — |

---

## 3. PDF 側のしくみ

### 3.1 Quarto から lib.typ へ届くまで

Quarto の typst 出力は既定のテンプレートを持っているが、**`template-partials`
で2つの partial を差し替えて**自前の様式に載せ替えている（`_quarto.yml`）。

- `typst-template.typ` … Quarto 既定の本体を空にする役
- `typst-show.typ` … フロントマターの値を `design-doc()` の引数に渡す役

```
title / subtitle / author / doc-number / company / toc …
        ↓ typst-show.typ
#show: design-doc.with(title: …, doc-number: …, toc: true, …)
```

**注意**: Quarto 既定の目次生成は `typst-template.typ` 側にあり、差し替えた
結果として機能しない。目次は `lib.typ` の `#outline()` が出している。

### 3.2 lib.typ の構成

冒頭に **【1】調整パラメータ** の節があり、寸法・色・文字サイズはすべて
そこに名前付き定数として集約してある。様式の微調整は原則そこだけ触ればよい。

| 変えたいもの | 触る定数 |
|---|---|
| 外枠の位置・大きさ（縦） | `FRAME-P-POS` / `FRAME-P-SIZE` |
| 本文を書ける領域（縦） | `PAGE-P-MARGIN` |
| 外枠の線の太さ | `FRAME` |
| 資料番号の枠の大きさ | `DOCNUM-INSET` / `DOCNUM-SIZE` |
| 資料番号とページ番号の間隔 | `DOCNUM-PAGE-GAP` |
| 社名の位置（縦ページ） | `FOOTER-DESCENT` |
| 社名の字間 | `COMPANY-TRACKING` |
| 外枠の位置・大きさ（横） | `FRAME-L-POS` / `FRAME-L-SIZE` |
| 資料番号の高さ（横ページ） | `DOCNUM-L-Y` |
| 本文を書ける領域（横） | `PAGE-L-MARGIN` / `PAGE-IPO-MARGIN` |
| IPO の列比・欄の高さ | `IPO-COLS` / `IPO-BODY-ROW` ほか |
| 本文・見出しの文字サイズ | `BODY-SIZE` / `HEAD-SIZES` |

自動で追従する箇所（手で計算し直さなくてよい）:

- **資料番号の枠が外枠の上辺に接地する**位置は `measure()` で実測している。
  文字サイズや inset を変えても接地は保たれる。
- **横ページの資料番号の左右位置**は `FRAME-L-POS.x + FRAME-L-SIZE.width` で
  求めている。外枠を動かせば資料番号も付いてくる。

### 3.3 採番

- 章番号: `set heading(numbering: "1.1.1")` の1か所。付録を `A.1` にする等は
  ここを差し替える。
- 図表番号（**章.節-連番**、例 図 3.2-1）:
  - `set figure(numbering: …)` が `section-prefix(here())-n` を組む
  - h1/h2 の show ルールで `reset-floats()` を呼び、連番を節ごとに 0 に戻す
  - `show ref` が **対象図表の location** でカウンタを読み直す
    （参照した位置で読むと節番号がずれる）
  - リセット対象の kind は4つ: qmd の図表フローが出す `quarto-float-fig` /
    `quarto-float-tbl` と、生の Typst で `#figure`（`image`/`table`）を直接書いた場合の
    保険。qmd 経路（前者2つ）だけを直すと、typst 生ブロックに図表を置いたときに
    連番がずれるので、**4つとも 0 に戻す**。

### 3.4 変更したら

**必ず再ビルドして PDF を目視確認する。** ページ単位で見るなら（ルートから）:

```
./template/setup.sh docs      # lib.typ を配置（未実施なら。実施済みなら省略可）
cd docs
# _quarto.yml の typst: に keep-typ: true を一時的に足してから
quarto render --to typst
typst compile index.typ "chk-{n}.png" --format png --font-path "C:/Windows/Fonts" --ppi 70
```

見た目を変えないリファクタのときは、**変更前後の PNG を `cmp` で比較**すると
確実（本ファイル追加時の lib.typ 整理も全10ページ一致を確認している）。

---

## 4. HTML 側のしくみ

### 4.1 なぜ章ごとに分割するのか

設計書は 400〜1000ページ規模になる。単一 HTML（`embed-resources: true`）だと
図が base64 で内包され、**1000ページ＋図200枚で約27MB** になり閲覧も添付も
破綻する（実測: 本文のみ 288ページで 2.1MB、図1枚あたり約110KB）。

book にすると、閲覧者が1ページで読むのは **約25KB**、共通アセットは
`site_libs/` に1回だけ置かれ、全文検索（`search.json`）も自動で付く。

### 4.2 図表番号を後処理で直す理由

**Quarto の図表採番（crossref）は、すべての Lua フィルタより後段で走る。**
`at: pre-quarto` / `post-quarto` のどちらで見ても、その時点で表には id も
キャプションも付いておらず、参照は未解決の `Cite` のまま。したがって
フィルタでは上書きできず、**生成された HTML を直すのが唯一の方法**
（実測で確認済み）。

`postprocess-html.mjs` は2パス構成:

1. `_quarto.yml` の `chapters:` の順に全章を走査し、見出しの `data-number` から
   章・節を拾って連番を確定する（連番は文書全体で決まるため章をまたぐ）
2. 全ファイルのキャプションと `a.quarto-xref` を、確定した番号に差し替える

書き換えるのは `figcaption` の「図 1.1: 」と相互参照リンクの本文の**2か所だけ**。
章順は `_quarto.yml` から読むので二重管理にならない。

**落とし穴**: 「図」と番号の間の NBSP は、book 出力では実体参照 `&nbsp;`、
単一 HTML 出力では生の U+00A0 と形が違う。正規表現は `(?:\s|&nbsp;)*` で
両対応にしてある（片方だけにすると 0 件マッチになる）。

### 4.3 見た目の調整箇所

| 変えたいもの | 触る場所 |
|---|---|
| 画面全体の幅・左ペインの幅 | `_quarto.yml` の `format.html.grid` |
| 章番号を出すか | `_quarto.yml` の `number-sections` |
| 表・IPO・図の見た目 | `design-doc.css` |
| 図表番号の書式 | `postprocess-html.mjs` |

現在は **1920px 基準**（左ペイン 300px + 本文 1380px + 右余白 240px）。
Quarto 既定は 250 + 800 + 250 ≒ 1280px。左ペインの 300px は
「章番号 + 見出し15文字」が折り返さずに収まる幅。

### 4.4 ブラウザで確認するとき

**`file://` では確認できない**（プレビューが最初に開いたページに固定され、
ナビゲートしても古い内容を返し続ける）。HTTP で配信すること:

```
cd docs/_book && python -m http.server 8899   # → http://localhost:8899/
```

- **再ビルドの前にサーバーを止める。** `_book/` を掴んだままだと
  `Device or resource busy` / `os error 32` でビルドが失敗する。
- CSS だけ直した場合、HTML に `?v=` を付けてもブラウザは
  `design-doc.css` をキャッシュする。`link` の href にクエリを足して読み直させる。

---

## 5. design-doc.lua（両方に効く変換）

執筆者の記法を様式機能に対応付ける Pandoc フィルタ。`FORMAT` で出力先を見て
分岐する。**typst の生ブロック（RawBlock）は HTML 出力時に捨てられる**ため、
HTML では div 構造として組み立て直している。

| 記法 | typst 出力 | html 出力 |
|---|---|---|
| ` ```mermaid ` | SVG 化して `image()` | 同左（同じ SVG を使う） |
| `::: {.landscape}` | `#landscape[...]` | div のまま（CSS で横スクロール） |
| `::: {.ipo}` | `#ipo(...)` | `.ipo` div 構造 |
| `::: {.merge-rows}` | 縦に連続する同値セルを rowspan 結合 | 同左 |
| すべての表 | 列幅を本文幅いっぱいに正規化 | CSS の `width: 100%` |

### book 特有の注意（パスまわり）

- **実行時の CWD が「いま処理している章ファイルのディレクトリ」になる**
  （章の階層ごとに変わる）。そのため相対パスは使えず、執筆フォルダの絶対パスが要る。
  フィルタは**環境変数に依存せず**次の順で自己解決する（→ 拡張・素の `quarto render`
  でもそのまま動く）:
  - `ROOT`（執筆フォルダ）= `DOC_ROOT` env → `quarto.project.directory` →
    `QUARTO_PROJECT_DIR` env → `'.'`。図の出力先 `diagrams/` の親。
  - `TMPL`（`template/`）= `TEMPLATE_ROOT` env → `ROOT/../template`。
    mermaid-cli（`node_modules`）・`mermaid-config.json`・`puppeteer.json` の場所。
  env は「明示的に上書きしたいとき」だけ使う。通常は何も export しなくてよい。
- **mermaid のブラウザ**は env に頼らない。`EXECUTABLE_BROWSER` があればそれを、
  無ければ setup が書いた `TMPL/puppeteer.json`（Chrome/Edge のパス）を使う。
  どちらも無ければ `{}`（mmdc 同梱 Chromium を試す）。
- mermaid の SVG は `ROOT/diagrams` に内容ハッシュで置くが、AST に載せる
  パスは章ファイルからの相対でなければ Quarto が解決できない（`diag_rel()`）。
- **画像はプロジェクトルート基準の `/diagrams/...` で書く。** `../` を使うと
  Windows で `chapters\01-overview/../../` とバックスラッシュ結合され、
  typst 0.15 以降が拒否する（Quarto 同梱の 0.14.2 は通るので気付きにくい）。

---

## 6. 変更するときのチェックリスト

- [ ] PDF を再ビルドして目視確認したか（見た目を変えない変更なら PNG 比較）
- [ ] HTML も再ビルドしたか（PDF だけ直すと採番がずれることがある）
- [ ] IPO の列比を変えたなら、`lib.typ` の `IPO-COLS` と
      `design-doc.css` の `.ipo-frame` の**両方**を直したか
- [ ] 採番規則を変えたなら、`lib.typ` と `postprocess-html.mjs` の**両方**か
- [ ] 機構ファイルを増減したなら、それが `template/` にあるか。執筆フォルダ直下へ
      配置が要るもの（typst import / `_book` 自己完結）なら、`setup.sh`/`setup.bat` の
      コピー対象と `.gitignore` も更新したか
- [ ] 執筆者に見える記法を増やしていないか（増やすなら `README.md` の説明も更新する）
