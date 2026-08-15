# 詳細ガイド（発行者・保守者向け）

README は最短手順にしてあります。このファイルには、その裏側（リポジトリの構成・
配布の単位・ビルドの仕組み・mermaid を PDF に載せるための準備・環境変数）を
まとめています。**設計書を書くだけなら読む必要はありません。**

- 執筆の記法 … 利用マニュアル（`manual/`）6〜10章
- 様式（外枠・採番・IPO図）の調整、変換の内部 … [template/PIPELINE.md](template/PIPELINE.md)

---

## 1. 2つのリポジトリ

**様式のリポジトリ（このリポジトリ）**と、**設計書リポジトリ**は別物です。
`template/` は設計書リポジトリの中に置きません。

```
【保守者】quarto-template/                … このリポジトリ
├── README.md / ADVANCED.md
├── .gitignore / .gitattributes / .vscode/settings.json
├── docs/                     … サンプル（受注管理システム。記法の実例＋様式の検証用）
├── manual/                   … 利用マニュアルの原稿（執筆フォルダの一つ）
└── template/                 … 様式・変換・ビルドの実体
    ├── PIPELINE.md           … 出力経路と様式調整箇所の解説（保守者向け・最初に読む）
    ├── VERSION               … テンプレートの版（init-doc / update-doc が書き込む）
    ├── lib.typ               … 様式の単一ソース（外枠・採番・IPO・横向き）
    ├── typst-template.typ    … Quarto 既定テンプレートの差し替え口（lib.typ を取り込む）
    ├── typst-show.typ        … フロントマター → design-doc() の引数
    ├── quarto-publish.yml    … PDF 用のプロファイル（→ <執筆>/『_quarto-publish.yml』）
    ├── design-doc.lua        … 執筆記法（mermaid / .landscape / .ipo / .tbl）の変換
    ├── design-doc.css        … HTML の見た目
    ├── postprocess-html.js   … HTML の図表番号を「章.節-連番」に振り直す後処理
    ├── mermaid-config.json   … mermaid 設定（htmlLabels:false 必須）
    ├── package.json          … mermaid-cli（mermaid を使う場合のみ npm ci）
    ├── scaffold/             … 設計書リポジトリの雛形（init-doc が配る）
    ├── init-doc.sh / .bat    … 設計書リポジトリを新規作成
    ├── update-doc.sh / .bat  … 既存の設計書リポジトリの機構ファイルを更新
    ├── setup.sh / setup.bat  … ビルド準備（機構＋PDF 用部品の配置、mermaid 用ブラウザ設定）
    ├── build-qmd.sh / .bat   … book → PDF
    ├── build-html.sh / .bat  … book → 静的 HTML（章ごと分割）
    └── render-diagrams.sh    … diagrams/*.mmd → SVG（静的図を更新したときだけ）

【発行者・執筆者】order-design/            … 設計書リポジトリ（git で共有）
├── .gitignore / .gitattributes / README.md / .vscode/settings.json
└── docs/                     … 執筆フォルダ（名前は init-doc の第2引数で変えられる）
    ├── _quarto.yml           … book 設定（章の並び・doc-number・html 設定）
    ├── index.qmd             … 前付け（採番されない）
    ├── chapters/             … 本文。章＝フォルダ / 節＝サブフォルダ / 項＝ファイル
    ├── diagrams/             … 静的図と mermaid 生成 SVG のキャッシュ置き場
    ├── design-doc.lua        ┐
    ├── design-doc.css        │ 機構ファイル（コミットする）。実体は template/。
    ├── postprocess-html.js   │ init-doc / update-doc / setup が配置する
    ├── mermaid-config.json   │
    ├── .template-version     ┘ どの版のテンプレートで置いたかの記録
    └── design-doc.pdf        … 中間版（発行者が定期的に作ってコミットする）
```

発行者の手元では、このリポジトリの代わりに**リリース ZIP を展開したフォルダ**を使います。
展開したまま使い、中身を取り出しません。

```
C:\tools\
└── quarto-template-1.1.0/   … リリース ZIP を展開したもの（＝ここで作業する）
    ├── README.md / ADVANCED.md
    ├── manual/              … 利用マニュアル（PDF / HTML。執筆者へ配る）
    └── template/            … 上と同じ中身（node_modules は既定で非同梱）

C:\work\
└── order-design/            … 設計書リポジトリ
    └── docs/
```

版がフォルダ名に入るので、新しいリリースは別フォルダに展開され、新旧を並べて置けます。

### 誰が何を配置するか

| コマンド | 実行者 | 置くもの | git |
|---|---|---|---|
| `init-doc` | 発行者（最初の1回） | 雛形一式＋機構ファイル | コミットする |
| `update-doc` | 発行者（テンプレート更新時） | 機構ファイルのみ | 差分をコミットする |
| `setup` | ビルドが自動で呼ぶ | 機構ファイル＋ PDF 用部品（`lib.typ` / typst partials / `_quarto-publish.yml`）＋ `puppeteer.json` | PDF 用部品は `.gitignore` |

**PDF 用の設定を `_quarto.yml` に書かない理由**: typst の `template-partials` は
実在するファイルを要求するため、設計書リポジトリ（`template/` が無い）で
`quarto render`（フォーマット無指定＝全形式）が必ず失敗します。プロファイル
（`_quarto-publish.yml` ＋ `--profile publish`）に分けると、執筆者の既定は HTML だけに
なります。

**執筆者の HTML が発行版と一致する理由**: 図表番号の振り直し
（`postprocess-html.js`）を `_quarto.yml` の `project.post-render` に登録してあり、
`quarto render` / `quarto preview` のたびに **Quarto 同梱の Deno** で走ります
（node 不要）。発行版との差は mermaid の描き方だけです。

## 2. 執筆フォルダを改名したいとき

執筆フォルダ名は自由です（`init-doc` の第2引数で決め、あとから `git mv` でも変えられます）。
`_quarto.yml` は機構ファイルを**同じフォルダ内の相対名**で参照し、スクリプトは渡された
パスを基準に動くため、改名しても設定の書き換えは不要です。

```bash
git mv docs design-doc                                # 例: docs → design-doc
./template/build-qmd.sh ~/work/order-design/design-doc  # ビルドは新しいパスを渡すだけ
```

**パスに ASCII 以外の文字（日本語など）は使えません。** Windows では Quarto から
Lua フィルタへ渡る時点でパスの文字が U+FFFD に置換されて届き、mermaid の SVG 化
（PDF・配布 HTML）が成立しません。`init-doc` はこれを検出して止めます。

## 3. ビルドの詳細

```bash
cd ~/tools/quarto-template-1.1.0

# PDF（発行版・中間版）
./template/build-qmd.sh ~/work/order-design/docs      # → <執筆フォルダ>/design-doc.pdf

# 静的 HTML（配布用・章ごとに分割）
./template/build-html.sh ~/work/order-design/docs     # → <執筆フォルダ>/_book/index.html
```

Windows（PowerShell / cmd）では、同じ引数で `.bat` 版を使います（出力先は同じ）:

```bat
cd C:\tools\quarto-template-1.1.0
.\template\build-qmd.bat C:\work\order-design\docs
.\template\build-html.bat C:\work\order-design\docs
```

- 引数は**執筆フォルダのパス**（省略時 `docs`）。**絶対パスを推奨**します。相対パスも
  使えますが、スクリプトの位置ではなく**いまいるフォルダ**からの相対として解釈されます
  （スクリプト自身の位置は `%~dp0` / `BASH_SOURCE` から求めるので、`template/` を
  どこに置いても、どう呼び出しても影響しません）。
- `build-*` / `setup` / `update-doc` は執筆フォルダに `_quarto.yml` が無ければ
  その場でエラーになるため、パスを間違えても何も壊れません。`init-doc` だけは
  「無いものを作る」コマンドなので検出できません（→ 下の注意）。
- ビルドスクリプトは先頭で `setup` を呼ぶので、単体で実行すれば準備も済みます。
- `build-qmd` は `--profile publish` を付けて typst の設定を読み込ませます。
- 図表番号の振り直しは `post-render`（`postprocess-html.js`）が行うので、
  ビルドスクリプトからは呼びません（二重に走らせると番号が壊れます）。
- PDF と HTML は執筆フォルダの `_book/` を共有し、**後から走ったほうが前の出力を消します**。
  そのため `build-qmd.sh` は PDF を `<執筆フォルダ>/design-doc.pdf` に取り出します。
  両方残すときは PDF → HTML の順で実行してください。
- HTML は `_book/` 一式で自己完結します（CSS を同梱）。閲覧は `index.html` を開くか、
  `cd <執筆フォルダ>/_book && python -m http.server` で配信、共有は `_book/` を zip すれば
  よいです。**再ビルドの前にサーバーを止めてください**（`_book/` を掴んだままだと
  `os error 32` でビルドが失敗します）。

### 中間版 PDF の運用

`<執筆フォルダ>/design-doc.pdf` は設計書リポジトリの**コミット対象**です
（`_book/` は生成物なので `.gitignore`）。執筆者は HTML で内容を確認しますが、
次のものは HTML では確認できません。**発行者が定期的に中間版 PDF を作ってコミットし、
執筆者がそれを見る**、という運用を前提にしています。

- 紙の様式（外枠・資料番号欄・社名・ページ番号）と改ページ位置
- 横向きページ（`.landscape`）、`.tbl` の分割（「（1／3）」の形）
- mermaid の最終的な見た目（プレビューはブラウザ内描画、発行版は mermaid-cli の SVG）

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

## 4. mermaid を使う場合

`chapters/**.qmd` に ` ```mermaid ` フェンスで図を書きます。出力先で処理が変わります。

- **執筆者のプレビュー（`quarto preview` / VSCode 拡張の HTML）** … Quarto 同梱の mermaid
  でブラウザ内描画されます。**node も npm も Chrome/Edge 設定も不要**で、図を編集すれば
  即プレビューに反映されます。執筆者はこのまま書くだけです。
- **発行版 PDF と配布 HTML（`build-qmd` / `build-html`）** … mermaid-cli でベクター SVG に
  焼き、PDF と HTML で図を一致させます。**この経路だけ** node と Chrome/Edge が要ります
  （＝下記は発行者だけの手順）。

どちらも設定は `mermaid-config.json` の1か所です（`theme` / `htmlLabels:false` /
フォント）。プレビュー側にも同じ設定を注入しているので、見た目はほぼ揃います。
ただし**描画エンジンの版が違う**ため（プレビューは Quarto 同梱の mermaid、発行版は
mermaid-cli）、まれに図の形が変わります。中間版 PDF で確認してください。

### 発行者だけが入れるもの

発行版 PDF・配布 HTML を出す環境にだけ、mermaid-cli（node）と Chrome/Edge を用意します。

```bash
cd ~/tools/quarto-template-1.1.0/template
PUPPETEER_SKIP_DOWNLOAD=true npm ci          # 依存は template/ に入れる（Chromium は落とさない）
cd ..
./template/setup.sh ~/work/order-design/docs  # Chrome/Edge を検出して記録
```

SVG 化には **Chrome か Edge**（Chromium 系ブラウザ）が1つあれば十分です。Chromium 自体は
ダウンロードしません（npm とは別の Google 配信のため、閉域では失敗しやすい）。`setup` が
手元の Chrome/Edge を自動検出して `template/puppeteer.json` に記録し、`design-doc.lua` が
それを参照します。**自動検出できないときだけ**、パスを明示して再実行します:

```bash
EXECUTABLE_BROWSER="/path/to/chrome-or-msedge" ./template/setup.sh ~/work/order-design/docs
```

Windows の cmd はインライン指定ができないので、`set` してから実行します:

```bat
cd C:\tools\quarto-template-1.1.0
set "EXECUTABLE_BROWSER=C:\Program Files\Google\Chrome\Application\chrome.exe"
.\template\setup.bat C:\work\order-design\docs
```

Chrome/Edge がまったく無い環境や、`--no-sandbox` 等の追加オプションが要る場合は
`template/puppeteer.json` を直接編集できます。SVG は `<執筆フォルダ>/diagrams/` に内容
ハッシュ名でキャッシュされ、同じ図は再変換されません（＝図を新規に書かなければ
Chrome/Edge は不要）。

`diagrams/order-flow.svg` のように qmd から直接参照している静的図を更新したいときは、
`diagrams/*.mmd` を編集して `./template/render-diagrams.sh ~/work/order-design/docs` を
実行します（`.bat` 版はありません。Windows では Git Bash から実行してください）。

## 5. 環境変数

ビルドの挙動は次の環境変数で調整できます。**通常は何も設定する必要はありません**
（ビルドスクリプト／`.bat` が必要なものを自動で設定し、`design-doc.lua` は
プロジェクト位置を自力で解決します）。

| 変数 | 効果 | 既定 / 設定者 |
|---|---|---|
| `MERMAID_SVG` | `1` のとき **HTML でも** mermaid をベクター SVG に焼く（PDF と図を一致させ、図表採番に載せる）。未設定なら Quarto 同梱 mermaid でクライアント描画＝**node 不要**。 | `build-html.sh`/`.bat` が内部で `1` を設定。執筆者の `quarto preview` は未設定 |
| `EXECUTABLE_BROWSER` | mermaid の SVG 化に使う Chrome/Edge の実行ファイルを明示する。`setup` の自動検出が外れる環境で使う。 | 未設定（`setup` が `template/puppeteer.json` に自動記録） |
| `PUPPETEER_SKIP_DOWNLOAD` | `true` で `npm ci` 時に Chromium をダウンロードしない（手元の Chrome/Edge を使うため）。 | 手動（依存導入時のみ） |
| `TEMPLATE_ROOT` | `template/` の場所。**設計書リポジトリの外に置く構成では必須**（`build-*` が自動で渡す）。未設定なら執筆フォルダの隣（`../template`）を見る。 | `build-qmd`/`build-html` が設定 |
| `DOC_ROOT` | （上級）フィルタが自力解決する執筆フォルダの場所を明示的に上書きする。特殊な配置のときだけ。 | 未設定（自己解決） |

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

## 6. リリースを作る（保守者）

発行者へ配る一式は `make-release` で作ります。マニュアルのビルドから zip 化までを
1コマンドで行うので、**ビルド順（PDF → HTML）の間違い**や入れ忘れが起きません。

```bat
:: このリポジトリのルートで実行する
.\template\make-release.bat
```

```bash
./template/make-release.sh
```

出力は `release/quarto-template-<版>/`（展開済み）と同名の `.zip` です。
第1引数で出力先を変えられます。

**発行者はこの ZIP を展開したフォルダをそのまま使います**（中身を取り出しません）。
版がフォルダ名に入るので、新旧のリリースを並べて置けます。

| オプション | 効果 |
|---|---|
| `--with-node-modules` | `template/node_modules` も同梱する（閉域向け。約 330MB 増える） |
| `--with-sample` | サンプル文書（`docs/`）も同梱する（原稿と図だけ。生成物は除く） |
| `--no-build` | マニュアルを再ビルドせず、既にある成果物を使う |

同梱されるもの:

```
quarto-template-<版>/
├── README-release.md   … 発行者向けのはじめかた
├── README.md / ADVANCED.md
├── manual/利用マニュアル.pdf, manual/html/   … 執筆者へ配る
└── template/           … node_modules と puppeteer.json は除く
```

- 版は `template/VERSION` から取ります。**リリース前に上げてください**（設計書
  リポジトリ側の `.template-version` と突き合わせて更新要否が判断されます）。
- 版を上げたら、**このファイル・`README.md`・`manual/` の実行例に埋め込まれた
  版番号も揃えてください**（展開フォルダ名に版が入るため、`quarto-template-1.1.0`
  のような記述が全体で30箇所ほどあります）。あわせて「新しい版を受け取ったとき」の
  説明で使う版番号（現行＋1）もずらします。手順は利用マニュアル17章にあります。
- 配布物の中の `.bat` は CRLF、`.sh` は LF に正規化されます。**LF のままの `.bat` は
  cmd.exe が `for` / `if` の複数行ブロックを解釈できず壊れます**（実測）。
- zip 化は `zip` → bsdtar（Windows 同梱の `tar.exe`）→ python の順に試します。
  **GNU tar は zip を作れません**（`tar -a -c -f x.zip` は中身が tar のままになる）。
