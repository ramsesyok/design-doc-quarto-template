# 設計書テンプレート（Quarto + PDF / HTML）

Markdown（Quarto qmd）だけを書けば、客先提出品質の PDF 設計書（＋社内レビュー用の
静的 HTML）が作れるテンプレートです。執筆者は本文の Markdown に集中し、会社様式
（外枠・資料番号欄・社名・縦横混在・IPO図）・章番号・図表番号・相互参照・改ページは
基盤側が受け持ちます。

PDF 生成には Quarto と、その同梱の Typst バックエンドを使います。

## 主な機能

- 目次の自動生成（章番号・リーダー線・実ページ番号つき。本文を直せば自動追従）
- 章番号の自動採番（4階層 1.1.1.1 まで）
- 図表番号は「章.節-連番」形式（例: 図 3.2-1、表 3.1-1。連番は節ごとにリセット）
- 図・表の相互参照（本文中の「図 3.2-1」を自動生成）
- 表のセル結合（大分類/中分類の縦結合を自動化。HTML タグを書かせない）
- ポートレート／ランドスケープの混在、IPO 図の横向き定型ページ
- mermaid（フローチャート／ステート図等）をビルド時に SVG 化して貼付
- 章・節ごとのファイル分割（`{{< include >}}`）でも採番は文書全体で連続
- 章の途中で改ページ（`{{< pagebreak >}}`）
- 同じ qmd から PDF（納品物）と静的 HTML（社内レビュー用・章ごとに分割）を出力

## ディレクトリ構成

執筆者が触るのは **`docs/` だけ**。様式・変換・ビルドの実体はすべて `template/` に
分離してあります。

```
design-doc-quarto-template/
├── README.md                … このファイル
├── .gitignore
│
├── docs/                     … 執筆フォルダ（このフォルダ名は変更可。下記参照）
│   ├── _quarto.yml           … book 設定（章の並び・出力形式・doc-number）
│   ├── index.qmd             … 前付け（採番されない）
│   ├── chapters/             … 本文。章＝フォルダ / 節＝サブフォルダ / 項＝ファイル
│   └── diagrams/             … qmd が直接貼る静的図（order-flow.svg 等）と
│                               mermaid 生成 SVG のキャッシュ置き場
│
└── template/                 … 様式・変換・ビルドの実体（執筆者は触らない）
    ├── PIPELINE.md           … 出力経路と様式調整箇所の解説（保守者向け・最初に読む）
    ├── lib.typ               … 様式の単一ソース（外枠・採番・IPO・横向き）
    ├── typst-template.typ    … Quarto 既定テンプレートの差し替え口（lib.typ を取り込む）
    ├── typst-show.typ        … フロントマター → design-doc() の引数
    ├── design-doc.lua        … 執筆記法（mermaid / .landscape / .ipo / セル結合 / 表幅）の変換
    ├── design-doc.css        … レビュー HTML の見た目
    ├── postprocess-html.mjs  … HTML の図表番号を「章.節-連番」に振り直す後処理
    ├── mermaid-config.json   … mermaid 設定（htmlLabels:false 必須）
    ├── package.json          … mermaid-cli（mermaid を使う場合のみ npm ci）
    ├── build-qmd.sh          … book → PDF
    ├── build-html.sh         … book → 静的 HTML（章ごと分割）
    └── render-diagrams.sh    … diagrams/*.mmd → SVG（静的図を更新したときだけ）
```

執筆者が触るのは基本的に `docs/chapters/**.qmd` と、章を増減するときの
`docs/_quarto.yml` の `chapters:` だけです。様式の調整は `template/lib.typ` 冒頭の
「【1】調整パラメータ」に集約しています。仕組みの詳細は `template/PIPELINE.md` を参照してください。

## ビルド

前提: [Quarto](https://quarto.org/) が導入済みであること（Typst バックエンドは同梱）。
**ビルドはリポジトリのルートから**実行します。

```bash
# PDF（納品物）
./template/build-qmd.sh docs      # → docs/design-doc.pdf

# 静的 HTML（社内レビュー用・章ごとに分割）
./template/build-html.sh docs     # → docs/_book/index.html
```

- 末尾の `docs` は執筆フォルダ名（省略時 `docs`）。フォルダを改名したらその名前を渡します。
- PDF と HTML は執筆フォルダの `_book/` を共有し、後から走ったほうが前の出力を消します。
  そのため `build-qmd.sh` は PDF を `docs/design-doc.pdf` に取り出します。両方残すときは
  PDF → HTML の順で実行してください。
- HTML は `docs/_book/` 一式で自己完結します（CSS を同梱）。閲覧は `index.html` を開くか、
  `cd docs/_book && python -m http.server` で配信、共有は `_book/` を zip すればよいです。

### 執筆フォルダ（docs）を改名したいとき

`docs/` は**リポジトリ直下・`template/` と兄弟**である限り、自由に改名できます。

```bash
git mv docs 設計書              # 例: docs → 設計書
./template/build-qmd.sh 設計書   # ビルドは新しい名前を渡すだけ
```

`_quarto.yml` は機構を `../template/...` で参照し、ビルドスクリプトは渡された
フォルダ名を基準に動くため、改名しても設定の書き換えは不要です。

### mermaid を使う場合

`docs/chapters/**.qmd` の ` ```mermaid ` フェンスはビルド時に mermaid-cli で SVG 化されます。
この機能を使うときだけ、追加の準備が要ります。

```bash
cd template
PUPPETEER_SKIP_DOWNLOAD=true npm ci        # 依存は template/ に入れる
cd ..
export EXECUTABLE_BROWSER="/path/to/edge-or-chrome"   # 既存の Edge/Chromium を指す
./template/build-qmd.sh docs
```

`EXECUTABLE_BROWSER` は Chromium の追加ダウンロードを避けるため、手元の Edge/Chrome の
実行ファイルを指します。SVG は `docs/diagrams/` に内容ハッシュ名でキャッシュされ、同じ図は
再変換されません。

`diagrams/order-flow.svg` のように qmd から直接参照している静的図を更新したいときは、
`docs/diagrams/*.mmd` を編集して `./template/render-diagrams.sh docs` を実行します。
