# 保守者ガイド（リポジトリの構成とリリース）

このファイルは**テンプレートを保守する人**向けです。リポジトリに何が入っているか、
版をどう上げるか、リリースをどう作って配るかをまとめています。

**執筆・発行の手順はここにはありません。** 行き先は次のとおりです。

| 知りたいこと | 見る場所 |
|---|---|
| 設計書リポジトリの作り方、PDF・HTML の出し方、mermaid の準備、環境変数 | 利用マニュアル（`manual/`）2・4・11・12章 |
| 記法（表・図・IPO図・横向き） | 利用マニュアル 6〜10章、早見表は15章 |
| うまくいかないとき | 利用マニュアル13章 |
| 様式（外枠・採番・IPO図）の調整、変換の内部 | [template/PIPELINE.md](template/PIPELINE.md) |

---

## 1. リポジトリの構成

**様式のリポジトリ（このリポジトリ）**と、**設計書リポジトリ**は別物です。
`template/` は設計書リポジトリの中に置きません。

```
quarto-template/                 … このリポジトリ（保守者が持つ）
├── README.md                    … リポジトリの入口（何でできているか・役割・流れ）
├── ADVANCED.md                  … このファイル
├── .gitignore / .gitattributes / .vscode/settings.json
├── docs/                        … サンプル（受注管理システム。記法の実例＋様式の検証用）
├── manual/                      … 利用マニュアルの原稿（執筆フォルダの一つ）
└── template/                    … 様式・変換・ビルドの実体
    ├── PIPELINE.md              … 出力経路と様式調整箇所の解説（最初に読む）
    ├── VERSION                  … テンプレートの版（init-doc / update-doc が書き込む）
    ├── lib.typ                  … 様式の単一ソース（外枠・採番・IPO・横向き）
    ├── typst-template.typ       … Quarto 既定テンプレートの差し替え口（lib.typ を取り込む）
    ├── typst-show.typ           … フロントマター → design-doc() の引数
    ├── quarto-publish.yml       … PDF 用のプロファイル（→ <執筆>/_quarto-publish.yml）
    ├── design-doc.lua           … 執筆記法（mermaid / .landscape / .ipo / .tbl）の変換
    ├── design-doc.css           … HTML の見た目
    ├── postprocess-html.js      … HTML の図表番号を「章.節-連番」に振り直す後処理
    ├── mermaid-config.json      … mermaid 設定（htmlLabels:false 必須）
    ├── package.json             … mermaid-cli（mermaid を使う場合のみ npm ci）
    ├── scaffold/                … 設計書リポジトリの雛形（init-doc が配る）
    ├── release-README.md        … リリース直下に置く案内（発行者向けの入口）
    ├── init-doc.sh / .bat       … 設計書リポジトリを新規作成
    ├── update-doc.sh / .bat     … 既存の設計書リポジトリの機構ファイルを更新
    ├── setup.sh / .bat          … ビルド準備（機構＋PDF 用部品の配置、ブラウザ検出）
    ├── build-qmd.sh / .bat      … book → PDF
    ├── build-html.sh / .bat     … book → 静的 HTML（章ごと分割）
    ├── render-diagrams.sh / .bat … diagrams/*.mmd → SVG（静的図を更新したときだけ）
    └── make-release.sh / .bat   … 発行者へ配るリリース一式を作る
```

発行者の手元にはこのリポジトリではなく、**リリース ZIP を展開したフォルダ**が
置かれます（`quarto-template-<版>/`）。展開したまま使い、中身を取り出しません。
版がフォルダ名に入るので、新旧のリリースを並べて置けます。

### 何が設計書リポジトリへ配られるか

リリースを作るときに意識すべき区別です。**機構ファイル4本と `.template-version` は
設計書リポジトリにコミットされる**ため、これらを変更したら版を上げる必要があります。

| ファイル | 配布 | 置く人 |
|---|:---:|---|
| `design-doc.lua` / `design-doc.css` / `postprocess-html.js` / `mermaid-config.json` | ○ | `init-doc` / `update-doc` / ビルド時の `setup` |
| `.template-version`（`VERSION` の写し） | ○ | 同上 |
| `lib.typ` / `typst-template.typ` / `typst-show.typ` / `_quarto-publish.yml` | × | `setup`（PDF を出すときだけ。`.gitignore`） |

配置コマンド（`init-doc` / `update-doc` / `setup`）の責務分担と、なぜ PDF 用の設定を
プロファイル（`_quarto-publish.yml`）に分けるのかは
[PIPELINE.md](template/PIPELINE.md) の「0. フォルダの分担」にあります。
HTML の図表番号を後処理で直している理由は利用マニュアル17章です。

---

## 2. 版を上げる

`template/VERSION` が版です。**配布される機構ファイル4本を変更したら上げてください。**
設計書リポジトリ側の `.template-version` と突き合わせて、発行者が更新要否を判断します。

版を上げたら、**実行例に埋め込まれた版番号も揃えてください。** 展開フォルダ名に版が
入るため（`cd C:\tools\quarto-template-1.1.1`）、ずれていると発行者が手元のフォルダ名と
合わない手順を読むことになります。全体で30箇所ほどあります。

```bat
:: 旧版が残っていないか確認する（VERSION と一致すること）
findstr /S /C:"quarto-template-1." README.md ADVANCED.md template\PIPELINE.md manual\chapters\*.qmd
```

「新しい版を受け取ったとき」の説明で使う版番号（現行＋1）も併せてずらします。

---

## 3. リリースを作る

発行者へ配る一式は `make-release` で作ります。マニュアルのビルドから zip 化までを
1コマンドで行うので、**ビルド順（PDF → HTML）の間違い**や入れ忘れが起きません。

```bat
:: このリポジトリのルートで実行する
.\template\make-release.bat
```

```bash
./template/make-release.sh
```

| 引数・オプション | 効果 |
|---|---|
| 第1引数 | 出力先フォルダ（既定は `release/`） |
| `--with-node-modules` | `template/node_modules` も同梱する（閉域向け。約 330MB 増える） |
| `--with-sample` | サンプル文書（`docs/`）も同梱する（原稿と図だけ。生成物は除く）。発行者へ記法の実例を渡したいときに使う |
| `--no-build` | マニュアルを再ビルドせず、既にある成果物を使う |

出力は `release/quarto-template-<版>/`（展開済み）と同名の `.zip` です。

```
quarto-template-<版>/
├── README-release.md   … 発行者向けのはじめかた（展開したらまずこれ）
├── README.md           … テンプレートの概要と作業の流れ
├── manual/利用マニュアル.pdf, manual/html/   … 発行者が読む・執筆者へ配る
└── template/           … node_modules と puppeteer.json は除く
```

**このファイル（`ADVANCED.md`）は同梱されません。** 保守者専用であり、発行者は
`README-release.md`・`README.md`・利用マニュアルで足ります。

### 作るときの注意

- 配布物の中の `.bat` は CRLF、`.sh` は LF に正規化されます。**LF のままの `.bat` は
  cmd.exe が `for` / `if` の複数行ブロックを解釈できず壊れます**（実測）。
- **zip 化ツールは UTF-8 名フラグ（general purpose bit 11）を立てるものを使います。**
  `manual/利用マニュアル.pdf` が日本語名のためです。**bsdtar（`tar -a`）はローカルの
  ANSI コードページで名前を書き、このフラグを立てません**。その zip を
  `Expand-Archive`・7-Zip・macOS・Linux の `unzip` で展開すると**文字化けします**（実測）。
  - `.bat` … .NET の `ZipFile` → bsdtar（警告つき）
  - `.sh` … python の `zipfile` → Info-ZIP `zip` → bsdtar（警告つき）
- **出力先のパスは短く保ってください。** .NET と python はどちらも、メンバーの
  パスが MAX_PATH（260文字）を超えると失敗します。`.bat` はそのとき bsdtar に
  切り替わるため、**日本語名が文字化けした zip ができます**（警告は出ます）。
  既定の出力先 `release/` は問題ありませんが、第1引数で深い場所を指定すると起こります。
- **`.NET` の `ZipFile` は失敗時に不完全な zip を残します**（実測: 79件中34件で打ち切り）。
  そのため成否は終了コードで判定し、失敗したら残骸を消しています。さらに zip 作成後に
  **ファイル数が展開フォルダと一致するか検査**し、欠けていればエラーにして zip を消します。
  「ファイルがあるかどうか」で成否を判定してはいけません。
- **GNU tar は zip を作れません**（`tar -a -c -f x.zip` は中身が tar のままになる）。
  `.sh` 側は `--version` に `bsdtar` / `libarchive` が含まれるかで判定しています。
- `--no-build` を使うときは、`manual/design-doc.pdf` と `manual/_book/` の**両方**が
  最新であることを確かめてください（片方だけ古いまま同梱される事故を防ぐため）。

---

## 4. リリースを配る

`main` にマージし、**マージ後の `main` からリリースを作り直してから**タグを打ちます
（タグの指すコミットと配布物を一致させるため）。

```bash
gh release create v1.1.1 "release/quarto-template-1.1.1.zip" \
  --target main \
  --title "v1.1.1 — （変更の要約）" \
  --notes-file <リリースノートのファイル>
```

- タグは `v<版>`（`template/VERSION` と揃える）。
- **ZIP を資産として添付します。** 発行者はこれをダウンロードして展開します。
- リリースノートには次を書きます。
  - 発行者のはじめかた（展開してそのまま使う・`cd` して絶対パスで `init-doc`）
  - 主な変更
  - 既存利用者向けの `update-doc` 手順
  - 互換性（配布される機構ファイル4本に変更があるか）

機構ファイル4本に変更が無い版では、既存の設計書リポジトリで `update-doc` を実行しても
実質 `.template-version` の更新だけになります。その旨をノートに書くと、発行者が
更新の要否を判断できます。

---

## 5. 変更したときの検証

様式・変換を直したら、次の順で確認します。手順の詳細は利用マニュアル17章にあります。

1. `setup` を再実行して執筆フォルダへ反映する（忘れると古い写しのまま検証してしまう）
2. サンプル文書（`docs/`）で PDF・HTML の両方を出し、体裁を確認する
3. 本書（`manual/`）でも出力を確認する（記法の網羅度が高く、退行を見つけやすい）
4. `postprocess-html.js` を直したときは、同じ `_book/` に2回続けて流しても結果が
   変わらないこと（冪等性）を必ず確認する

様式のどこを触れば何が変わるかは [PIPELINE.md](template/PIPELINE.md) の
「3. PDF 側のしくみ」に集約してあります。
