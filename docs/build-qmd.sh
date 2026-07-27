#!/usr/bin/env bash
# Quarto book (qmd → typst → PDF) ビルドスクリプト
# 執筆者が編集するのは chapters/ 以下の qmd と _quarto.yml の chapters だけ。
# 様式は lib.typ に集約している。
# Quarto は typst バイナリを同梱しているため、Quarto さえ導入すれば動く。
# mermaid を使う場合のみ docs/ での npm ci と EXECUTABLE_BROWSER が必要。
set -euo pipefail

export EXECUTABLE_BROWSER="${EXECUTABLE_BROWSER:-}"
# book では Lua フィルタ実行時の CWD が章ファイルのディレクトリになるため、
# design-doc.lua に mermaid の入出力先をプロジェクトルート基準で教える。
export DOC_ROOT="$(pwd)"

quarto render --to typst

# 納品物である PDF は docs/ 直下に取り出して残す（_book/ はビルドのたびに作り直す）。
cp _book/*.pdf design-doc.pdf
echo "OK -> design-doc.pdf"
