# 設計書テンプレート（Quarto + PDF / HTML）

Markdown（Quarto qmd）だけを書けば、客先提出品質の PDF 設計書（＋社内レビュー用の
静的 HTML）が作れるテンプレートです。執筆者は本文の Markdown に集中し、会社様式
（外枠・資料番号欄・社名・縦横混在・IPO図）・章番号・図表番号・相互参照・改ページは
基盤側が受け持ちます。

PDF 生成には Quarto と、その同梱の Typst バックエンドを使います。

> 執筆で使う記法（Quarto の相互参照・横向きページ・IPO図・改ページ・ファイル分割など）は
> **[AUTHORING.md（執筆ガイド）](AUTHORING.md)** にまとめています。まず読むのはこちら。

## 主な機能

- 目次の自動生成（章番号・リーダー線・実ページ番号つき。本文を直せば自動追従）
- 章番号の自動採番（4階層 1.1.1.1 まで）
- 図表番号は「章.節-連番」形式（例: 図 3.2-1、表 3.1-1。連番は節ごとにリセット）
- 図・表の相互参照（本文中の「図 3.2-1」を自動生成）
- 表のセル結合（大分類/中分類の縦結合を自動化。HTML タグを書かせない）
- ポートレート／ランドスケープの混在、IPO 図の横向き定型ページ
- mermaid（フローチャート／ステート図等）。執筆者プレビューはブラウザ内描画（node 不要）、
  納品 PDF・配布 HTML はビルド時にベクター SVG 化して貼付
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
├── .gitattributes           … 改行コードの固定（*.sh=LF / *.bat=CRLF）
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
    ├── setup.sh / setup.bat  … 執筆環境の初期化（lib.typ/css 配置 + mermaid 用ブラウザ設定）
    ├── build-qmd.sh          … book → PDF
    ├── build-html.sh         … book → 静的 HTML（章ごと分割）
    └── render-diagrams.sh    … diagrams/*.mmd → SVG（静的図を更新したときだけ）
```

**配布・持ち出しの単位**: 執筆者は `template/`（オフライン運用なら `node_modules`
ごと）と執筆フォルダをコピーし、`setup` を一度実行すれば PDF/HTML を出力できる環境が
整います。

執筆者が触るのは基本的に `docs/chapters/**.qmd` と、章を増減するときの
`docs/_quarto.yml` の `chapters:` だけです。様式の調整は `template/lib.typ` 冒頭の
「【1】調整パラメータ」に集約しています。仕組みの詳細は `template/PIPELINE.md` を参照してください。

## セットアップ（最初に一度だけ）

前提: [Quarto](https://quarto.org/) が導入済みであること（Typst バックエンドは同梱）。
**コマンドはすべてリポジトリのルートから**実行します。

```bash
./template/setup.sh docs          # Windows の cmd なら  template\setup.bat docs
```

`setup` は (1) `template/lib.typ` と `design-doc.css` を執筆フォルダへ配置し、
(2) mermaid 図の SVG 化に使う Chrome/Edge を検出して `template/puppeteer.json` に
記録します（Chromium はダウンロードしません）。どちらも `.gitignore` 済みです。
これを一度やっておけば、下記のビルドスクリプトでも **VSCode の Quarto 拡張**
（quarto preview / render）でも、PDF/HTML を出力できます。

> **執筆者は node.js 不要です。** `quarto preview`（HTML）での mermaid は Quarto 同梱の
> ランタイムでブラウザ内描画されるため、node も npm も Chrome/Edge 設定も要りません
> （上記 (2) は納品 PDF・配布 HTML を作る係だけが必要。→「mermaid を使う場合」）。
> 執筆者に必要なのは Quarto と、css を配置するための `setup` だけです。

> `template/lib.typ` や `design-doc.css` を改修したら `setup` を再実行してください（冪等・上書き）。
> ビルドスクリプトは内部で `setup` を呼ぶので、スクリプト経由なら再実行は自動です。

### VSCode の推奨設定（表を書くなら日本語も等幅にする）

Windows の VSCode の既定のエディタフォントは Consolas で、**日本語の字形が含まれません**。
日本語は OS のフォールバックフォントで表示されるため、日本語の文字幅が半角の2倍ちょうどに
ならず、**パイプ表やグリッド表の罫線が画面上で揃わなくなります**（表だけ極端に書きづらいのは
これが原因です）。

日本語も等幅になるフォント（`BIZ UDゴシック` など。日本語環境の Windows 10/11 に標準で
入っています）を `editor.fontFamily` の**先頭**に指定してください。リポジトリ内の
`.vscode/settings.json` に書けばこの設計書を開いたときだけ効きます（環境全体に効かせたい
ならユーザー設定に書きます）。

```json
{
  "editor.fontFamily": "'BIZ UDゴシック', Consolas, monospace"
}
```

> 表を書くときだけ効かせたい場合は、言語ごとの設定にもできます:
> `"[quarto]": { "editor.fontFamily": "'BIZ UDゴシック', Consolas, monospace" }`

これは**エディタの表示だけ**の設定で、PDF・HTML の出力フォントには影響しません
（出力側の書体は `template/lib.typ` が決めます）。列幅も罫線の文字数ではなく
セルの内容量から自動計算されるため、画面上で罫線が揃っていなくても出力は崩れません
（→ [AUTHORING.md「表」](AUTHORING.md#6-表)）。

## ビルド

```bash
# PDF（納品物）
./template/build-qmd.sh docs      # → docs/design-doc.pdf

# 静的 HTML（社内レビュー用・章ごとに分割）
./template/build-html.sh docs     # → docs/_book/index.html
```

Windows の cmd では、同じ引数で `.bat` 版を使います（出力先は `.sh` 版と同じ）:

```bat
template\build-qmd.bat docs
template\build-html.bat docs
```

- 末尾の `docs` は執筆フォルダ名（省略時 `docs`）。フォルダを改名したらその名前を渡します。
- ビルドスクリプトは先頭で `setup` を呼ぶので、単体で実行すれば初期化も済みます。
- PDF と HTML は執筆フォルダの `_book/` を共有し、後から走ったほうが前の出力を消します。
  そのため `build-qmd.sh` は PDF を `docs/design-doc.pdf` に取り出します。両方残すときは
  PDF → HTML の順で実行してください。
- HTML は `docs/_book/` 一式で自己完結します（CSS を同梱）。閲覧は `index.html` を開くか、
  `cd docs/_book && python -m http.server` で配信、共有は `_book/` を zip すればよいです。

### PDF は必ず `quarto render` 経由で作る（`typst compile` 直叩きは不可）

callout（`::: {.callout-note}` など）のアイコンは **Font Awesome** の字形です。実体は
Quarto 同梱の `<Quarto>/share/formats/typst/fonts/`（`Font Awesome 6 Free-Solid-900.otf` ほか）
にあり、**`quarto render` が Typst に `--font-path` で渡すことで初めて見つかります**。
OS にインストールされているフォントではありません。

そのため、中間生成物の `.typ` を取り出して素の `typst compile` に掛けると、アイコンが
すべて豆腐（□）になります。ビルドは必ず `template/build-qmd.sh`（＝内部で `quarto render`）
か VSCode の Quarto 拡張から行ってください。

どうしても `typst compile` を直接使って様式を試したいときは、フォントの場所を明示します:

```bash
quarto typst compile index.typ out.pdf --font-path "/c/Program Files/Quarto/share/formats/typst/fonts"
```

```bat
:: Windows cmd
quarto typst compile index.typ out.pdf --font-path "C:\Program Files\Quarto\share\formats\typst\fonts"
```

> 出来上がった PDF にアイコンが載ったかは、埋め込みフォントに
> `FontAwesome6Free-Solid` が含まれるかで確認できます。

### 執筆フォルダ（docs）を改名したいとき

`docs/` は**リポジトリ直下・`template/` と兄弟**である限り、自由に改名できます。

```bash
git mv docs 設計書              # 例: docs → 設計書
./template/build-qmd.sh 設計書   # ビルドは新しい名前を渡すだけ
```

`_quarto.yml` は機構を `../template/...` で参照し、ビルドスクリプトは渡された
フォルダ名を基準に動くため、改名しても設定の書き換えは不要です。

### mermaid を使う場合

`docs/chapters/**.qmd` に ` ```mermaid ` フェンスで図を書きます。出力先で処理が変わります。

- **執筆者のプレビュー（`quarto preview` / VSCode 拡張の HTML）** … Quarto 同梱の mermaid
  でブラウザ内描画されます。**node も npm も Chrome/Edge 設定も不要**で、図を編集すれば
  即プレビューに反映されます。執筆者はこのまま書くだけです。
- **納品 PDF と配布 HTML（`build-qmd.sh` / `build-html.sh`）** … mermaid-cli でベクター SVG に
  焼き、PDF と HTML で図を一致させます。**この経路だけ** node と Chrome/Edge が要ります
  （＝下記は PDF/配布 HTML を作る係だけの手順）。

> プレビューの図は Quarto 標準テーマで描かれるため、最終成果物（`htmlLabels:false` の SVG）
> とは見た目が少し異なることがあります。内容確認には十分です。

#### PDF・配布 HTML を作る係だけが入れるもの

納品 PDF・配布 HTML を出す環境にだけ、mermaid-cli（node）と Chrome/Edge を用意します。

```bash
cd template
PUPPETEER_SKIP_DOWNLOAD=true npm ci        # 依存は template/ に入れる（Chromium は落とさない）
cd ..
./template/setup.sh docs                    # Chrome/Edge を検出して記録
```

SVG 化には **Chrome か Edge**（Chromium 系ブラウザ）が1つあれば十分です。Chromium 自体は
ダウンロードしません（npm とは別の Google 配信のため、閉域では失敗しやすい）。`setup` が
手元の Chrome/Edge を自動検出して `template/puppeteer.json` に記録し、`design-doc.lua` が
それを参照します。**自動検出できないときだけ**、パスを明示して再実行します:

```bash
EXECUTABLE_BROWSER="/path/to/chrome-or-msedge" ./template/setup.sh docs
```

Windows の cmd はインライン指定ができないので、`set` してから実行します:

```bat
set "EXECUTABLE_BROWSER=C:\Program Files\Google\Chrome\Application\chrome.exe"
template\setup.bat docs
```

Chrome/Edge がまったく無い環境や、`--no-sandbox` 等の追加オプションが要る場合は
`template/puppeteer.json` を直接編集できます。SVG は `docs/diagrams/` に内容ハッシュ名で
キャッシュされ、同じ図は再変換されません（＝図を新規に書かなければ Chrome/Edge は不要）。

`diagrams/order-flow.svg` のように qmd から直接参照している静的図を更新したいときは、
`docs/diagrams/*.mmd` を編集して `./template/render-diagrams.sh docs` を実行します。

### 環境変数

ビルドの挙動は次の環境変数で調整できます。**通常は何も設定する必要はありません**
（ビルドスクリプト／`.bat` が必要なものを自動で設定し、`design-doc.lua` は
プロジェクト位置を自力で解決します）。

| 変数 | 効果 | 既定 / 設定者 |
|---|---|---|
| `MERMAID_SVG` | `1` のとき **HTML でも** mermaid をベクター SVG に焼く（PDF と図を一致させ、図表採番に載せる）。未設定なら Quarto 同梱 mermaid でクライアント描画＝**node 不要**。 | `build-html.sh`/`.bat` が内部で `1` を設定。執筆者の `quarto preview` は未設定 |
| `EXECUTABLE_BROWSER` | mermaid の SVG 化に使う Chrome/Edge の実行ファイルを明示する。`setup` の自動検出が外れる環境で使う。 | 未設定（`setup` が `template/puppeteer.json` に自動記録） |
| `PUPPETEER_SKIP_DOWNLOAD` | `true` で `npm ci` 時に Chromium をダウンロードしない（手元の Chrome/Edge を使うため）。 | 手動（依存導入時のみ） |
| `DOC_ROOT` / `TEMPLATE_ROOT` | （上級）フィルタが自力解決する執筆フォルダ / `template/` の場所を明示的に上書きする。拡張や特殊な配置で必要なときだけ。 | 未設定（自己解決） |

- **執筆者は基本的に無関係です。** `MERMAID_SVG` はビルド係向けで、執筆者が
  `quarto preview` するときは未設定のまま＝ブラウザ内描画（node 不要）になります。
- **設定の仕方（cmd と bash で書式が違う）**: cmd は `VAR=値 コマンド` のインライン指定が
  できません。`set` で先に定義してから実行します（`setlocal` 内なら以降のプロセスに継承）。

```bash
# bash（その1コマンドにだけ効かせる）
MERMAID_SVG=1 quarto render --to html
```

```bat
:: Windows cmd（set してから実行）
set "MERMAID_SVG=1"
quarto render --to html
```
