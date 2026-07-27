#!/usr/bin/env bash
# <執筆フォルダ>/diagrams/*.mmd を SVG 化する（qmd から直接貼る静的図を更新したときだけ実行）。
#
# 使い方（リポジトリのルートから実行する）:
#   ./template/render-diagrams.sh [執筆フォルダ名]    # 省略時は docs
#
# mermaid-cli と設定は template/（このスクリプトと同じ場所）を使う（npm ci 済みであること）。
# ブラウザは EXECUTABLE_BROWSER（既存 Edge/Chromium）を指定可能。
# 章本文の ```mermaid フェンスはビルド時に design-doc.lua が自動変換するので対象外。
set -euo pipefail

TEMPLATE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTENT_DIR="${1:-docs}"
CONTENT_ROOT="$(cd "$CONTENT_DIR" && pwd)"

MMDC="$TEMPLATE_ROOT/node_modules/@mermaid-js/mermaid-cli/src/cli.js"
MMDC_CONF="$TEMPLATE_ROOT/mermaid-config.json"

BROWSER="${EXECUTABLE_BROWSER:-}"
PUPPETEER_JSON="$(mktemp)"
if [ -n "$BROWSER" ]; then
  printf '{"executablePath": "%s"}' "$BROWSER" | sed 's/\\/\\\\/g' > "$PUPPETEER_JSON"
else
  echo '{}' > "$PUPPETEER_JSON"
fi
trap 'rm -f "$PUPPETEER_JSON"' EXIT

cd "$CONTENT_ROOT"
for mmd in diagrams/*.mmd; do
  svg="${mmd%.mmd}.svg"
  echo "mermaid: $mmd -> $svg"
  # テーマ等は mermaid-config.json に集約（-t を併用すると -c が無効化される）
  node "$MMDC" -i "$mmd" -o "$svg" \
    -b transparent -p "$PUPPETEER_JSON" -c "$MMDC_CONF"
done
echo "OK"
