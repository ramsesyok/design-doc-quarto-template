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
# mermaid を使う場合のみ template/ での npm ci と EXECUTABLE_BROWSER が要る。
set -euo pipefail

TEMPLATE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTENT_DIR="${1:-docs}"
if [ ! -f "$CONTENT_DIR/_quarto.yml" ]; then
  echo "エラー: '$CONTENT_DIR/_quarto.yml' が見つかりません。" >&2
  echo "       リポジトリのルートから実行し、第1引数に執筆フォルダ名を渡してください。" >&2
  exit 1
fi
CONTENT_ROOT="$(cd "$CONTENT_DIR" && pwd)"

export EXECUTABLE_BROWSER="${EXECUTABLE_BROWSER:-}"
export TEMPLATE_ROOT
# book では Lua フィルタ実行時の CWD が章ファイルのディレクトリになるため、
# design-doc.lua に「執筆フォルダ（＝図の出力先の親）」を絶対パスで教える。
export DOC_ROOT="$CONTENT_ROOT"

# lib.typ は typst の import が「プロジェクト外を読めない」ため、執筆フォルダ直下へ
# 一時コピーしてから render する（typst-template.typ は #import "lib.typ" で拾う）。
# .gitignore 済み。ビルド終了時（成功・失敗どちらでも）に必ず消す。
cp "$TEMPLATE_ROOT/lib.typ" "$CONTENT_ROOT/lib.typ"
trap 'rm -f "$CONTENT_ROOT/lib.typ"' EXIT

cd "$CONTENT_ROOT"
quarto render --to typst

# 納品物である PDF は執筆フォルダ直下に取り出して残す（_book/ は作り直す）。
cp _book/*.pdf design-doc.pdf
echo "OK -> $CONTENT_DIR/design-doc.pdf"
