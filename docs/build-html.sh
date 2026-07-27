#!/usr/bin/env bash
# 社内レビュー用 HTML ビルドスクリプト（Quarto book → 章ごとの HTML）
#
# 出力: _book/ （章ごとの HTML + 共通アセット site_libs/ + 全文検索 search.json）
#       _book/index.html をブラウザで開くだけでレビューできる。共有は _book/ を
#       zip すればよい。単一ファイルにしないのは、400〜1000ページ級では図の
#       base64 内包で数十 MB に膨れ、閲覧も配布も破綻するため。
#
# 納品物は PDF（./build-qmd.sh）。HTML では紙の様式（外枠・資料番号欄・社名・
# ページ番号）は出さず、指摘箇所の特定に使う章番号・図表番号・相互参照を残す。
#
# 図表番号は Quarto の既定（図 1.1, 図 1.2 …）ではなく PDF と同じ「章.節-連番」に
# postprocess-html.mjs で振り直す。Quarto の採番は全 Lua フィルタより後段で
# 走るためフィルタでは上書きできず、生成 HTML を直すのが唯一の方法。
set -euo pipefail

export EXECUTABLE_BROWSER="${EXECUTABLE_BROWSER:-}"
export DOC_ROOT="$(pwd)"

quarto render --to html
node postprocess-html.mjs _book

echo "OK -> _book/index.html （ブラウザで開く）"
