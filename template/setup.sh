#!/usr/bin/env bash
# 執筆環境の初期化（一度だけ実行すればよい。冪等なので何度実行しても安全）。
#
# 使い方（リポジトリのルートから実行する）:
#   ./template/setup.sh [執筆フォルダ名]     # 省略時は docs
#
# やること:
#   1) template/ の lib.typ と design-doc.css を執筆フォルダ直下へ配置する。
#      - lib.typ … Typst の import が「プロジェクト外を読めない」制約に掛かるため、
#        プロジェクトルート（執筆フォルダ）内に置く必要がある（PDF）。
#      - design-doc.css … Quarto がローカル css として _book/ に取り込み、
#        _book/ 単体で配信・zip できるようにする（HTML）。
#      どちらも .gitignore 済みなので git には載らない。
#   2) mermaid 図のベクター SVG 化に使う Chrome/Edge を検出し、template/puppeteer.json に
#      その実行パスを書く（Chromium はダウンロードしない）。これは納品 PDF・配布 HTML を
#      作る係にだけ要る（build-*.sh / MERMAID_SVG=1）。**執筆者のプレビューは不要**:
#      quarto preview の HTML は Quarto 同梱 mermaid でブラウザ内描画され node も要らない。
#
# これを実行しておけば、以後はビルドスクリプトでも VSCode の Quarto 拡張
# （quarto preview / render）でも PDF/HTML を出力できる（プレビューは node 不要）。
set -euo pipefail

TEMPLATE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTENT_DIR="${1:-docs}"
if [ ! -f "$CONTENT_DIR/_quarto.yml" ]; then
  echo "エラー: '$CONTENT_DIR/_quarto.yml' が見つかりません。" >&2
  echo "       リポジトリのルートから実行し、第1引数に執筆フォルダ名を渡してください。" >&2
  exit 1
fi
CONTENT_ROOT="$(cd "$CONTENT_DIR" && pwd)"

# 1) 機構ファイルを執筆フォルダへ配置（冪等・常に上書き）
cp -f "$TEMPLATE_ROOT/lib.typ"        "$CONTENT_ROOT/lib.typ"
cp -f "$TEMPLATE_ROOT/design-doc.css" "$CONTENT_ROOT/design-doc.css"
echo "配置: $CONTENT_DIR/lib.typ, $CONTENT_DIR/design-doc.css"

# 2) mermaid 用ブラウザ（Chrome → Edge の順に検出）。EXECUTABLE_BROWSER があれば優先。
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
  echo "      執筆・プレビュー（quarto preview）はこのままで可能です（mermaid はブラウザ内描画）。" >&2
  echo "      納品 PDF・配布 HTML を作るときだけ、EXECUTABLE_BROWSER=<chrome/msedge の実行" >&2
  echo "      ファイル> を指定して setup を再実行してください。" >&2
fi

echo "OK: '$CONTENT_DIR' の初期化が完了しました。"
