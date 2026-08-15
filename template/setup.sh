#!/usr/bin/env bash
# 発行者のビルド環境を整える（冪等なので何度実行しても安全）。ビルドの先頭で自動実行される。
#
# 使い方（template/ の位置はどこでもよい。執筆フォルダのパスを渡す）:
#   ./template/setup.sh <執筆フォルダのパス>     # 省略時は docs
#
# やること:
#   1) 機構ファイル（design-doc.lua / design-doc.css / postprocess-html.js /
#      mermaid-config.json / .template-version）を執筆フォルダへ置く。
#      → 実体は update-doc.sh。doc リポジトリではこれらは**コミット対象**なので、
#        テンプレートを更新したあとにビルドすると git の差分として現れる。
#   2) PDF 用の機構を執筆フォルダへ置く（いずれも .gitignore 済み。git には載らない）:
#      - lib.typ … Typst の import が「プロジェクト外を読めない」制約に掛かるため
#      - typst-template.typ / typst-show.typ … 様式の partial
#      - _quarto-publish.yml … typst 用のプロファイル（--profile publish で効く）
#   3) mermaid 図のベクター SVG 化に使う Chrome/Edge を検出し、template/puppeteer.json に
#      その実行パスを書く（Chromium はダウンロードしない）。
#
# **これは発行者だけが実行する。** 執筆者は Quarto と VSCode 拡張だけで HTML を出せる
# （mermaid は Quarto 同梱のランタイムでブラウザ内描画。node も template/ も要らない）。
set -euo pipefail

TEMPLATE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTENT_DIR="${1:-docs}"
if [ ! -f "$CONTENT_DIR/_quarto.yml" ]; then
  echo "エラー: '$CONTENT_DIR/_quarto.yml' が見つかりません。" >&2
  echo "       第1引数に執筆フォルダのパスを渡してください（例: ~/work/order-design/docs）。" >&2
  exit 1
fi
CONTENT_ROOT="$(cd "$CONTENT_DIR" && pwd)"

# 1) 機構ファイル（HTML 側。doc リポジトリではコミット対象）
"$TEMPLATE_ROOT/update-doc.sh" "$CONTENT_ROOT"

# 2) PDF 用の機構（冪等・常に上書き）
cp -f "$TEMPLATE_ROOT/lib.typ"             "$CONTENT_ROOT/lib.typ"
cp -f "$TEMPLATE_ROOT/typst-template.typ"  "$CONTENT_ROOT/typst-template.typ"
cp -f "$TEMPLATE_ROOT/typst-show.typ"      "$CONTENT_ROOT/typst-show.typ"
cp -f "$TEMPLATE_ROOT/quarto-publish.yml"  "$CONTENT_ROOT/_quarto-publish.yml"
echo "配置: $CONTENT_DIR/lib.typ, typst-template.typ, typst-show.typ, _quarto-publish.yml"

# 3) mermaid 用ブラウザ（Chrome → Edge の順に検出）。EXECUTABLE_BROWSER があれば優先。
to_win_path() { printf '%s' "$1" | sed -E 's#^/([a-zA-Z])/#\1:/#; s#\\#/#g'; }
BROWSER="${EXECUTABLE_BROWSER:-}"
if [ -z "$BROWSER" ]; then
  for p in \
    "/c/Program Files/Google/Chrome/Application/chrome.exe" \
    "/c/Program Files (x86)/Google/Chrome/Application/chrome.exe" \
    "/c/Program Files/Microsoft/Edge/Application/msedge.exe" \
    "/c/Program Files (x86)/Microsoft/Edge/Application/msedge.exe" \
    "/usr/bin/google-chrome" "/usr/bin/google-chrome-stable" \
    "/usr/bin/chromium" "/usr/bin/chromium-browser" "/usr/bin/microsoft-edge" \
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
    "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge"; do
    if [ -f "$p" ]; then BROWSER="$p"; break; fi
  done
fi

PP="$TEMPLATE_ROOT/puppeteer.json"
if [ -n "$BROWSER" ]; then
  WINP="$(to_win_path "$BROWSER")"
  # JSON 用にバックスラッシュをエスケープ（WINP は既に / なので通常は変化なし）
  ESC="$(printf '%s' "$WINP" | sed 's/\\/\\\\/g')"
  # 強くロックされた環境向けに --no-sandbox を入れておく（通常環境でも無害）。
  printf '{"executablePath": "%s", "args": ["--no-sandbox"]}' "$ESC" > "$PP"
  echo "mermaid 用ブラウザ: $WINP"
  echo "  -> $PP に記録しました"
else
  echo "警告: Chrome / Edge が見つかりませんでした。" >&2
  echo "      納品 PDF・配布 HTML の mermaid をベクター化できません。" >&2
  echo "      EXECUTABLE_BROWSER=<chrome/msedge の実行ファイル> を指定して再実行してください。" >&2
fi

echo "OK: '$CONTENT_DIR' のビルド準備が完了しました。"
