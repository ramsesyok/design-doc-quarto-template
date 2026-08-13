// Quarto 用テンプレートパーシャル。
// 様式の実体は lib.typ（単一ソース）。ここでは取り込むだけ。
#import "lib.typ": *

// callout のアイコンを HTML 版に寄せる（note を 〇にi、important を 〇に! にする）。
// 中身は lib.typ の【6】。Quarto 既定の callout は definitions.typ 側で定義されており
// lib.typ からは見えないので、包み直しだけをここで行う。
#let _quarto-callout = callout
#let callout = with-html-callout-icons(_quarto-callout)
