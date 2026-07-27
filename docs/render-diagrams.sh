#!/usr/bin/env bash
# diagrams/*.mmd を SVG 化する（mermaid 図を更新したときだけ実行）
# mermaid-cli は typst/ 自身の node_modules を利用する（npm ci 済みであること）。
# ブラウザは EXECUTABLE_BROWSER（既存 Edge/Chromium）を指定可能。
set -euo pipefail

BROWSER="${EXECUTABLE_BROWSER:-}"
PUPPETEER_JSON="$(mktemp)"
if [ -n "$BROWSER" ]; then
  printf '{"executablePath": "%s"}' "$BROWSER" | sed 's/\\/\\\\/g' > "$PUPPETEER_JSON"
else
  echo '{}' > "$PUPPETEER_JSON"
fi

for mmd in diagrams/*.mmd; do
  svg="${mmd%.mmd}.svg"
  echo "mermaid: $mmd -> $svg"
  # テーマ等は mermaid-config.json に集約（-t を併用すると -c が無効化される）
  npx mmdc -i "$mmd" -o "$svg" \
    -b transparent -p "$PUPPETEER_JSON" -c mermaid-config.json
done
rm -f "$PUPPETEER_JSON"
echo "OK"
