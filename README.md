# 設計書テンプレート（Quarto + PDF）

Markdown（Quarto qmd）だけを書けば、客先提出品質の PDF 設計書が作れるテンプレートです。
執筆者は本文の Markdown に集中し、会社様式（外枠・資料番号欄・社名・縦横混在・IPO図）・
章番号・図表番号・相互参照・改ページは基盤側（`lib.typ` と Lua フィルタ）が受け持ちます。

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

## ディレクトリ構成

```
design-doc-quarto-template/
├── README.md                … このファイル
├── .gitignore
└── docs/
    ├── PIPELINE.md           … 出力経路と様式調整箇所の解説（保守者向け・最初に読む）
    ├── _quarto.yml           … book 設定（章の並び・出力形式・doc-number）
    ├── index.qmd             … 前付け（採番されない）
    ├── chapters/             … 本文。章＝フォルダ / 節＝サブフォルダ / 項＝ファイル
    ├── build-qmd.sh          … book → PDF（quarto render）
    ├── typst-show.typ        … フロントマター → design-doc() の引数
    ├── typst-template.typ    … Quarto 既定テンプレートの差し替え口（lib.typ を取り込む）
    ├── design-doc.lua        … 執筆記法（mermaid / .landscape / .ipo / セル結合 / 表幅）の変換
    ├── lib.typ               … 様式の単一ソース（外枠・採番・IPO・横向き）
    ├── mermaid-config.json   … mermaid 設定（htmlLabels:false 必須）
    ├── package.json          … mermaid-cli（mermaid を使う場合のみ npm ci）
    ├── render-diagrams.sh    … diagrams/*.mmd → SVG（静的図を更新したときだけ）
    └── diagrams/             … 静的図（order-flow.svg など。mermaid の生成 SVG はここにキャッシュ）
```

執筆者が触るのは基本的に `docs/chapters/**.qmd` と、章を増減するときの
`docs/_quarto.yml` の `chapters:` だけです。様式の調整は `docs/lib.typ` 冒頭の
「【1】調整パラメータ」に集約しています。仕組みの詳細は `docs/PIPELINE.md` を参照してください。

## ビルド

前提: [Quarto](https://quarto.org/) が導入済みであること（Typst バックエンドは同梱）。

```bash
cd docs
./build-qmd.sh          # → docs/design-doc.pdf（納品物）
```

`build-qmd.sh` は `quarto render --to typst` を実行し、`_book/` に出た PDF を
`docs/design-doc.pdf` に取り出します。

### mermaid を使う場合

`docs/chapters/**.qmd` の ` ```mermaid ` フェンスはビルド時に mermaid-cli で SVG 化されます。
この機能を使うときだけ、追加の準備が要ります。

```bash
cd docs
PUPPETEER_SKIP_DOWNLOAD=true npm ci
export EXECUTABLE_BROWSER="/path/to/edge-or-chrome"   # 既存の Edge/Chromium を指す
./build-qmd.sh
```

`EXECUTABLE_BROWSER` は Chromium の追加ダウンロードを避けるため、手元の
Edge/Chrome の実行ファイルを指します。SVG は `docs/diagrams/` に内容ハッシュ名で
キャッシュされ、同じ図は再変換されません。

`diagrams/order-flow.svg` のように qmd から直接参照している静的図を更新したい
ときは、`docs/diagrams/*.mmd` を編集して `./render-diagrams.sh` を実行します。

## ロードマップ

- HTML 版（社内レビュー用・章ごとに分割）の移植。`design-doc.lua` は既に
  `FORMAT == 'html'` の分岐を備えており、`_quarto.yml` に `format.html` と
  レビュー用 CSS・後処理を足すことで有効化できます（詳細は `docs/PIPELINE.md`）。
