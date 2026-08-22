// Quarto 用テンプレートパーシャル。
// qmd のフロントマター（title / subtitle / author / doc-number / doc-revision /
// spec / company-ja / company-en / cover / page-start / toc / toc-title / toc-depth）を
// lib.typ の design-doc() に引き渡す。
//
// `cover-fields:`（_quarto.yml の任意のマップ）はそのまま辞書にして fields へ渡す。
// **項目を増やすたびにこのファイルと lib.typ を直す必要が無いのはこの経路だけ。**
// 作成日・部署・機密区分など文書ごとの記載は cover-fields に足して、cover.typ で
// meta.fields.<キー> として使う。値は design-doc.lua がエスケープ済み。
//
// 表紙・前付けの「中身」だけは執筆フォルダの cover.typ にあり（文書ごとに書き換える）、
// その front-matter() を引数として渡す。cover: false のときは呼ばれない。
// **cover.typ は必ず存在する**（setup / init-doc が「無ければ作る」）。
#import "cover.typ": front-matter

#show: design-doc.with(
  front-matter: front-matter,
$if(cover-fields)$
  fields: ($for(cover-fields/pairs)$"$it.key$": "$it.value$",$endfor$),
$endif$
$if(title)$
  title: "$title$",
$endif$
$if(subtitle)$
  subtitle: "$subtitle$",
$endif$
$if(by-author)$
  author: "$for(by-author)$$it.name.literal$$sep$, $endfor$",
$endif$
$if(doc-number)$
  doc-number: "$doc-number$",
$endif$
$if(doc-revision)$
  doc-revision: "$doc-revision$",
$endif$
$if(spec)$
  spec: true,
$endif$
$if(company-ja)$
  company-ja: "$company-ja$",
$endif$
$if(company-en)$
  company-en: "$company-en$",
$endif$
$if(cover)$
  cover: true,
$endif$
$if(page-start)$
  page-start: $page-start$,
$endif$
$if(toc)$
  toc: true,
$endif$
$if(toc-title)$
  toc-title: "$toc-title$",
$endif$
$if(toc-depth)$
  toc-depth: $toc-depth$,
$endif$
)
