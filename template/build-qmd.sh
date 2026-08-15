#!/usr/bin/env bash
# Quarto book (qmd → typst → PDF) ビルドスクリプト（発行者が実行）
#
# 使い方（template/ の位置はどこでもよい。執筆フォルダのパスを渡す）:
#   ./template/build-qmd.sh <執筆フォルダのパス>     # 省略時は docs
#   例) ./template/build-qmd.sh ~/work/order-design/docs
#
# 執筆者が編集するのは <執筆フォルダ>/chapters 以下の qmd と _quarto.yml だけ。
# 様式・変換・テンプレートの実体はすべて template/（このスクリプトと同じ場所）にある。
# Quarto は typst バイナリを同梱しているため、Quarto さえ導入すれば動く。
# mermaid を使う場合のみ template/ での npm ci と Chrome/Edge が要る（setup が設定）。
#
# 先頭で setup を呼ぶので、機構ファイル・PDF 用 partial・mermaid 用ブラウザ設定は
# 自動で整う。typst の設定は _quarto-publish.yml にあるので --profile publish を付ける。
# TEMPLATE_ROOT を渡すため、template/ が doc リポジトリの外にあっても動く。
set -euo pipefail

TEMPLATE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTENT_DIR="${1:-docs}"
if [ ! -f "$CONTENT_DIR/_quarto.yml" ]; then
  echo "エラー: '$CONTENT_DIR/_quarto.yml' が見つかりません。" >&2
  echo "       第1引数に執筆フォルダのパスを渡してください（例: ~/work/order-design/docs）。" >&2
  exit 1
fi
CONTENT_ROOT="$(cd "$CONTENT_DIR" && pwd)"

# ビルド環境を整える（冪等）: 機構ファイル・PDF 用 partial・mermaid 用ブラウザ設定。
"$TEMPLATE_ROOT/setup.sh" "$CONTENT_ROOT"

cd "$CONTENT_ROOT"
TEMPLATE_ROOT="$TEMPLATE_ROOT" quarto render --to typst --profile publish

# 発行版・中間版の PDF は執筆フォルダ直下に取り出して残す（_book/ は作り直す）。
# doc リポジトリではこの PDF をコミットして「中間版」として共有する。
cp _book/*.pdf design-doc.pdf
echo "OK -> $CONTENT_DIR/design-doc.pdf"
