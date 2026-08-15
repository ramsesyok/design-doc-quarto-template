#!/usr/bin/env bash
# 配布用 HTML ビルドスクリプト（Quarto book → 章ごとの HTML。発行者が実行）
#
# 使い方（template/ の位置はどこでもよい。執筆フォルダのパスを渡す）:
#   ./template/build-html.sh <執筆フォルダのパス>    # 省略時は docs
#
# 出力: <執筆フォルダ>/_book/ （章ごとの HTML + 共通アセット site_libs/ +
#       全文検索 search.json）。_book/index.html をブラウザで開くだけで読めて、
#       共有は _book/ を zip すればよい。design-doc.css は _book/ に取り込まれるので
#       _book/ 単体で自己完結する。
#
# 執筆者も同じ HTML を `quarto preview` で出せる。違いは mermaid だけで、
# ここでは PDF と同じベクター SVG に焼く（MERMAID_SVG=1。node と Chrome/Edge が要る）。
# 図表番号の振り直しは _quarto.yml の post-render（postprocess-html.js）が行うので、
# このスクリプトからは呼ばない（二重に走らせない）。
set -euo pipefail

TEMPLATE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTENT_DIR="${1:-docs}"
if [ ! -f "$CONTENT_DIR/_quarto.yml" ]; then
  echo "エラー: '$CONTENT_DIR/_quarto.yml' が見つかりません。" >&2
  echo "       第1引数に執筆フォルダのパスを渡してください（例: ../受注管理-設計書/docs）。" >&2
  exit 1
fi
CONTENT_ROOT="$(cd "$CONTENT_DIR" && pwd)"

# ビルド環境を整える（冪等）: 機構ファイル・PDF 用 partial・mermaid 用ブラウザ設定。
"$TEMPLATE_ROOT/setup.sh" "$CONTENT_ROOT"

cd "$CONTENT_ROOT"
# 配布 HTML は mermaid を PDF と同じベクター SVG に焼く（執筆者のプレビューだけは
# MERMAID_SVG を渡さず Quarto 同梱 mermaid でクライアント描画＝node 不要）。
MERMAID_SVG=1 TEMPLATE_ROOT="$TEMPLATE_ROOT" quarto render --to html

echo "OK -> $CONTENT_DIR/_book/index.html （ブラウザで開く）"
