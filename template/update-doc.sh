#!/usr/bin/env bash
# 執筆フォルダの「機構ファイル」を template/ の内容に更新する（発行者が実行）。
#
# 使い方（template/ の位置はどこでもよい。執筆フォルダのパスを渡す）:
#   ./template/update-doc.sh <執筆フォルダのパス>      # 例: ../受注管理-設計書/docs
#
# 置くもの（doc リポジトリでは**コミット対象**。執筆者はこれで HTML を出せる）:
#   design-doc.lua        … 独自記法（.tbl / .ipo / .landscape / mermaid）の変換
#   design-doc.css        … HTML の見た目
#   postprocess-html.js   … 図表番号を「章.節-連番」に振り直す後処理（post-render）
#   mermaid-config.json   … mermaid の設定（SVG 化とプレビューで共用する単一ソース）
#   .template-version     … どの版のテンプレートで置いたかの印
#
# 差分が出たらコミットすること（テンプレートの更新が文書リポジトリに入る）。
# PDF 用の機構（lib.typ / typst partials / _quarto-publish.yml）は setup.sh が
# ビルド直前に置く（.gitignore 済み。doc リポジトリには残さない）。
set -euo pipefail

TEMPLATE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTENT_DIR="${1:-docs}"
if [ ! -f "$CONTENT_DIR/_quarto.yml" ]; then
  echo "エラー: '$CONTENT_DIR/_quarto.yml' が見つかりません。" >&2
  echo "       第1引数に執筆フォルダのパスを渡してください（例: ../受注管理-設計書/docs）。" >&2
  exit 1
fi
CONTENT_ROOT="$(cd "$CONTENT_DIR" && pwd)"

for f in design-doc.lua design-doc.css postprocess-html.js mermaid-config.json; do
  cp -f "$TEMPLATE_ROOT/$f" "$CONTENT_ROOT/$f"
done
cp -f "$TEMPLATE_ROOT/VERSION" "$CONTENT_ROOT/.template-version"

echo "更新: $CONTENT_DIR の機構ファイル（テンプレート $(tr -d '\r\n' < "$TEMPLATE_ROOT/VERSION") 版）"
