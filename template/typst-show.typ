// Quarto 用テンプレートパーシャル。
// qmd のフロントマター（title / subtitle / author / doc-number / company /
// toc / toc-title / toc-depth）を lib.typ の design-doc() に引き渡す。
#show: design-doc.with(
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
$if(company)$
  company: "$company$",
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
