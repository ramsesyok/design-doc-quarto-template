# 設計書テンプレート リリース一式

このフォルダは**発行者向け**の配布物です。設計書リポジトリを作り、発行版 PDF と
配布 HTML を出すのに必要なものが入っています。

```
design-doc-template-<版>/
├── README.md          … 役割ごとの最短手順（まずこれ）
├── ADVANCED.md        … 構成・ビルドの詳細・mermaid の準備・環境変数
├── manual/            … 利用マニュアル（執筆者へ配るのはこれ）
│   ├── 利用マニュアル.pdf
│   └── html/index.html
└── template/          … 様式・変換・ビルドの実体
```

## はじめかた

1. **Quarto を入れる**（<https://quarto.org/docs/get-started/>）。
2. このフォルダを、設計書リポジトリを置く場所の**隣**に展開する。
   `template/` は設計書リポジトリの中には置かないこと。
3. 設計書リポジトリを作る。

   ```bat
   template\init-doc.bat ..\order-design
   ```

4. `..\order-design\docs\_quarto.yml` の表題・資料番号・会社名・章立てを直し、
   `git init` してコミットし、執筆者へ共有する。
5. **`manual/` の PDF（または `html/`）を執筆者に配る。** 記法はここに書いてある。

詳しい手順は `README.md`、内部の仕組みは `template/PIPELINE.md` を参照。

## mermaid 図を使う場合

発行版 PDF・配布 HTML で mermaid をベクター化する経路にだけ、node と Chrome / Edge が
要ります。`template/node_modules/` が同梱されていない版では、接続できる環境で
次を実行してから持ち込んでください。

```bat
cd template
set "PUPPETEER_SKIP_DOWNLOAD=true"
npm ci
```

## 版の確認

`template/VERSION` にこのリリースの版が入っています。設計書リポジトリ側の
`<執筆フォルダ>/.template-version` と見比べれば、更新が要るか判断できます。
更新は `template\update-doc.bat <執筆フォルダのパス>` です。
