// ============================================================
//  表紙・前付け（PDF だけに効く）
//
//  **このファイルが「表紙と前書きの中身」で、文書ごとに書き換えてよい唯一の
//  様式ファイル。** lib.typ（様式の単一ソース）は触らずに済むよう分けてある。
//
//  - 出るのは `_quarto.yml` の `cover: true` のときだけ。`cover: false`（既定）なら
//    このファイルは読まれるが何も出ない。
//  - **doc リポジトリではコミットする。** setup / init-doc は「無ければ作る」だけで、
//    既にあるものは上書きしない（テンプレートを更新しても表紙は残る）。
//  - HTML には表紙が無いので、ここを書き換えても HTML は変わらない。
//
//  ------------------------------------------------------------
//  書き方
//  ------------------------------------------------------------
//  front-matter(meta, front) を定義する。中身はふつうの Typst で、目次より前に
//  そのまま組まれる。ページを分けたいところで pagebreak() を打てば、
//  表紙・承認ページ・改訂履歴・まえがき…と何ページでも置ける。
//
//  meta … `_quarto.yml` の値:
//    meta.title        表題          meta.doc-number   資料番号
//    meta.subtitle     副題          meta.doc-revision 改訂記号
//    meta.author       作成者        meta.doc-id       資料番号＋改訂記号（連結ずみ）
//    meta.company-ja   会社名（日）  meta.spec         スペック様式か（true/false）
//    meta.company-en   会社名（英）  meta.page-start   開始ページ番号
//
//  front … **index.qmd に書いた前付けの本文**（Markdown で書いたもの）。
//    `_quarto.yml` に `front-in-cover: true` と書くと index.qmd の中身が丸ごと
//    ここへ届く（**章の見出しも一緒に回る**ので、本文にも目次にも残らない）。
//    一部だけ回したいときは、その範囲を `::: {.front-matter}` で囲む。
//    **置き場所はこのファイルが決める**:
//      (1) bare-page[ … #front ]   … 表紙のページの中に流し込む（文章のある表紙）
//      (2) front-on-new-page(front) … 表紙の次のページに置く（無ければ何もしない）
//      (3) front をどこにも置かない … PDF には出さない（HTML のトップページには残る）。
//          index.qmd に書くことが無い文書はこれ。`cover: false`（表紙を出さない）
//          ときも、この関数自体が呼ばれないので同じく出ない
//      (4) front-in-cover を書かない … 従来どおり目次の後ろ（本文の先頭）に出る
//    front は「前付けがあれば組み、無ければ何も出さない」content なので、
//    `if front != none` のような判定はできない（判定は front-on-new-page が行う）。
//
//  lib.typ から使える部品（`#import "lib.typ": *` で入る）:
//    default-cover(meta)          既定の表紙（下で使っているもの）
//    bare-page(body, margin: 30mm) 外枠・資料番号を出さない独立ページ
//    front-on-new-page(front)     前付けがあれば改ページして置く（無ければ何もしない）
//    JP-SANS / JP-SERIF           書体
//    RULE / FRAME / BORDER        罫線（太さ＋色）
//    COVER-TITLE-SIZE ほか        既定の表紙の寸法（lib.typ 冒頭【1】）
//
//  注意:
//   - **見出しは `numbering: none, outlined: false` を付ける。** 素の `= まえがき`
//     にすると章カウンタを消費し（本文が2章から始まる）、目次にも載ってしまう。
//     index.qmd 側で書く見出しは `{.unnumbered}` を付ければよい。
//   - ページ番号は表紙から数える。表紙を数えたくないときは `_quarto.yml` の
//     `page-start` で調整するか、本文だけを別文書にする（利用マニュアル4章）。
//   - 図表番号を振りたい図表は前付けに置かない（章番号が 0 になる）。
//
//  ------------------------------------------------------------
//  直したときの確認
//  ------------------------------------------------------------
//    ./template/build-qmd.sh <執筆フォルダのパス>    # → <執筆フォルダ>/design-doc.pdf
//  表紙だけを速く見たいときは、VSCode の Typst 拡張（Tinymist）でこのファイルを
//  開いてもよいが、**最終確認は必ず build-qmd で行う**（拡張が使う Typst は
//  Quarto 同梱のものと版が違うことがある）。
// ============================================================
#import "lib.typ": *

#let front-matter(meta, front) = {
  // 既定: 表題・副題・作成者を中央に置くだけ（様式は本文と同じ＝外枠・資料番号つき）。
  default-cover(meta)

  // index.qmd を `::: {.front-matter}` で囲んだときは、その中身を表紙の次のページへ。
  // 囲んでいなければ何もしない（空のページも作らない）。
  front-on-new-page(front)

  // ------------------------------------------------------------
  // 差し替え例1: 文章を載せる表紙（index.qmd の前付けを表紙ページの中に入れる）
  // index.qmd 側を `::: {.front-matter}` で囲んでおくこと。
  // 上の default-cover(meta) … の塊を消して、下のコメントを外す。
  // ------------------------------------------------------------
  // bare-page[
  //   #set text(font: JP-SANS)
  //   #align(right, text(size: 12pt)[資料番号: #meta.doc-id])
  //   #v(10mm)
  //   #align(center, text(size: 24pt, weight: "bold")[#meta.title])
  //   #v(15mm)
  //   #front                              // ← index.qmd に書いた文章がここに入る
  //   #v(1fr)
  //   #align(center, text(size: 12pt)[#meta.company-ja])
  // ]

  // ------------------------------------------------------------
  // 差し替え例2: 表題と査印欄だけの表紙（前付けは表紙の次のページへ）
  // ------------------------------------------------------------
  // bare-page[
  //   #set align(center)
  //   #set text(font: JP-SANS)
  //   #align(right, text(size: 12pt)[資料番号: #meta.doc-id])
  //   #v(1fr)
  //   #text(size: 24pt, weight: "bold")[#meta.title]
  //   #v(8pt)
  //   #if meta.subtitle != "" { text(size: 14pt)[#meta.subtitle] }
  //   #v(2fr)
  //   #table(
  //     columns: (24mm, 30mm, 30mm, 30mm),
  //     rows: (8mm, 18mm),
  //     stroke: RULE, align: center + horizon,
  //     [], [承認], [審査], [作成],
  //     [署名], [], [], [],
  //   )
  //   #v(1fr)
  //   #text(size: 12pt)[#meta.author]
  //   #v(6pt)
  //   #text(size: 12pt)[#meta.company-ja]
  // ]
  // front-on-new-page(front)              // 表紙の次のページに前付けを置く

  // ------------------------------------------------------------
  // 差し替え例3: cover.typ 側に直接まえがきを書く（index.qmd を使わない場合）
  // 見出しには numbering: none / outlined: false を必ず付ける。
  // ------------------------------------------------------------
  // pagebreak()
  // heading(level: 1, numbering: none, outlined: false)[まえがき]
  // [
  //   本書は、#meta.title について記述したものである。
  // ]
}
