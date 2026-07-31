#!/usr/bin/env bash
# 社内レビュー用 HTML ビルドスクリプト（Quarto book → 章ごとの HTML）
#
# 使い方（リポジトリのルートから実行する）:
#   ./template/build-html.sh [執筆フォルダ名]    # 省略時は docs
#
# 出力: <執筆フォルダ>/_book/ （章ごとの HTML + 共通アセット site_libs/ +
#       全文検索 search.json）。_book/index.html をブラウザで開くだけでレビューでき、
#       共有は _book/ を zip すればよい。design-doc.css は _book/ に取り込まれるので
#       _book/ 単体で自己完結する。
#
# 納品物は PDF（./template/build-qmd.sh）。HTML では紙の様式（外枠・資料番号欄・
# 社名・ページ番号）は出さず、指摘箇所の特定に使う章番号・図表番号・相互参照を残す。
# 図表番号は Quarto 既定（図 1.1 …）ではなく PDF と同じ「章.節-連番」に
# postprocess-html.mjs で振り直す（Quarto の採番は全 Lua フィルタより後段で走るため）。
set -euo pipefail

TEMPLATE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTENT_DIR="${1:-docs}"
if [ ! -f "$CONTENT_DIR/_quarto.yml" ]; then
  echo "エラー: '$CONTENT_DIR/_quarto.yml' が見つかりません。" >&2
  echo "       リポジトリのルートから実行し、第1引数に執筆フォルダ名を渡してください。" >&2
  exit 1
fi
CONTENT_ROOT="$(cd "$CONTENT_DIR" && pwd)"

# 執筆環境を整える（冪等）: lib.typ / design-doc.css の配置 + mermaid 用ブラウザ設定。
"$TEMPLATE_ROOT/setup.sh" "$CONTENT_DIR"

cd "$CONTENT_ROOT"
# 配布 HTML は mermaid を PDF と同じベクター SVG に焼く（執筆者プレビューだけは
# MERMAID_SVG を渡さず Quarto 同梱 mermaid でクライアント描画＝node 不要）。
MERMAID_SVG=1 quarto render --to html
node "$TEMPLATE_ROOT/postprocess-html.mjs" _book

echo "OK -> $CONTENT_DIR/_book/index.html （ブラウザで開く）"
