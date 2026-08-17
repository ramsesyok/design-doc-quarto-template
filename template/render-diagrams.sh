#!/usr/bin/env bash
# <執筆フォルダ>/diagrams/*.mmd を SVG 化する（qmd から直接貼る静的図を更新したときだけ実行）。
#
# 使い方（template/ の位置はどこでもよい。執筆フォルダのパスを渡す）:
#   ./template/render-diagrams.sh <執筆フォルダのパス>    # 省略時は docs
#
# mermaid-cli と設定は template/（このスクリプトと同じ場所）を使う（node_modules 同梱版か、
# 接続できる環境で npm ci 済みであること）。mermaid-cli は Quarto 同梱の Deno（`quarto run`）
# で走らせるので node は要らない。
# ブラウザは EXECUTABLE_BROWSER（既存 Edge/Chromium）を指定可能。
# 章本文の ```mermaid フェンスはビルド時に design-doc.lua が自動変換するので対象外。
set -euo pipefail

TEMPLATE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTENT_DIR="${1:-docs}"
CONTENT_ROOT="$(cd "$CONTENT_DIR" && pwd)"

MMDC="$TEMPLATE_ROOT/node_modules/@mermaid-js/mermaid-cli/src/cli.js"
# mermaid の設定は執筆フォルダ直下のものを優先する（design-doc.lua と同じ規則。
# doc リポジトリには機構ファイルとして配布され、そちらが実際に使われるため）。
MMDC_CONF="$TEMPLATE_ROOT/mermaid-config.json"
if [ -f "$CONTENT_ROOT/mermaid-config.json" ]; then
  MMDC_CONF="$CONTENT_ROOT/mermaid-config.json"
fi

# ブラウザ設定: EXECUTABLE_BROWSER があれば優先、無ければ setup 生成の
# template/puppeteer.json を使う（Chrome/Edge。Chromium はダウンロードしない）。
BROWSER="${EXECUTABLE_BROWSER:-}"
if [ -n "$BROWSER" ]; then
  PUPPETEER_JSON="$(mktemp)"
  printf '{"executablePath": "%s"}' "$BROWSER" | sed 's/\\/\\\\/g' > "$PUPPETEER_JSON"
  trap 'rm -f "$PUPPETEER_JSON"' EXIT
elif [ -f "$TEMPLATE_ROOT/puppeteer.json" ]; then
  PUPPETEER_JSON="$TEMPLATE_ROOT/puppeteer.json"
else
  PUPPETEER_JSON="$(mktemp)"; echo '{}' > "$PUPPETEER_JSON"
  trap 'rm -f "$PUPPETEER_JSON"' EXIT
fi

cd "$CONTENT_ROOT"
for mmd in diagrams/*.mmd; do
  svg="${mmd%.mmd}.svg"
  echo "mermaid: $mmd -> $svg"
  # テーマ等は mermaid-config.json に集約（-t を併用すると -c が無効化される）。
  # Quarto 同梱の Deno で走らせる。quarto が使えない環境のためだけに node を残す。
  quarto run "$MMDC" -i "$mmd" -o "$svg" \
    -b transparent -p "$PUPPETEER_JSON" -c "$MMDC_CONF" \
    || node "$MMDC" -i "$mmd" -o "$svg" \
         -b transparent -p "$PUPPETEER_JSON" -c "$MMDC_CONF"
done
echo "OK"
