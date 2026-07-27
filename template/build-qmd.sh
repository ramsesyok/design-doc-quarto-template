#!/usr/bin/env bash
# Quarto book (qmd → typst → PDF) ビルドスクリプト
#
# 使い方（リポジトリのルートから実行する）:
#   ./template/build-qmd.sh [執筆フォルダ名]     # 省略時は docs
#   例) 執筆フォルダを sekkei に改名したなら:  ./template/build-qmd.sh sekkei
#
# 執筆者が編集するのは <執筆フォルダ>/chapters 以下の qmd と _quarto.yml だけ。
# 様式・変換・テンプレートの実体はすべて template/（このスクリプトと同じ場所）にある。
# Quarto は typst バイナリを同梱しているため、Quarto さえ導入すれば動く。
# mermaid を使う場合のみ template/ での npm ci と Chrome/Edge が要る（setup が設定）。
#
# 先頭で setup を呼ぶので、lib.typ / design-doc.css の配置と mermaid 用ブラウザ設定は
# 自動で整う。design-doc.lua はプロジェクト位置を自力で解決するため env は不要。
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
quarto render --to typst

# 納品物である PDF は執筆フォルダ直下に取り出して残す（_book/ は作り直す）。
cp _book/*.pdf design-doc.pdf
echo "OK -> $CONTENT_DIR/design-doc.pdf"
