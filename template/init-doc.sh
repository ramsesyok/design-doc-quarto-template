#!/usr/bin/env bash
# 設計書リポジトリ（doc リポジトリ）の原型を作る（発行者が最初に一度だけ実行）。
#
# 使い方（template/ の位置はどこでもよい。作る先のパスを渡す）:
#   ./template/init-doc.sh <doc リポジトリのパス> [執筆フォルダ名] [--no-render]
#   例) ./template/init-doc.sh ~/work/order-design
#       ./template/init-doc.sh ~/work/order-design design-doc
#
# **作る先は絶対パスで渡すこと。** 相対パスは CWD 基準で解決される（このスクリプト
# の位置からではない）。init-doc は「無いものを作る」ので誤りを検出できず、
# エラーにならないまま意図しない場所に作られる。
#
# 作るもの:
#   <doc リポジトリ>/
#   ├── .gitignore, .gitattributes, README.md, .vscode/settings.json
#   └── <執筆フォルダ>/  … _quarto.yml, index.qmd, chapters/, diagrams/
#                          ＋ 機構ファイル（update-doc.sh が置く）
#
# 置いたあと HTML を1回ビルドして、執筆者が確認できる状態になっているか検証する
# （`--no-render` を付けると省略）。**既にあるファイルは上書きしない**ので、
# 既存の doc リポジトリに対して実行しても本文は壊れない。
#
# このあと発行者が行うこと:
#   1) <執筆フォルダ>/_quarto.yml の表題・資料番号・会社名・章の並びを直す
#   2) index.qmd（前付け）と chapters/ の章立てを文書に合わせて作る
#   3) git init → commit → 執筆者に共有する
# **template/ は doc リポジトリの中に置かない**（`git clean` で消える・誤コミットの元）。
set -euo pipefail

TEMPLATE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCAFFOLD="$TEMPLATE_ROOT/scaffold"

REPO_DIR=""
CONTENT_NAME="docs"
DO_RENDER=1
for arg in "$@"; do
  case "$arg" in
    --no-render) DO_RENDER=0 ;;
    *) if [ -z "$REPO_DIR" ]; then REPO_DIR="$arg"; else CONTENT_NAME="$arg"; fi ;;
  esac
done
if [ -z "$REPO_DIR" ]; then
  echo "エラー: 作成先のパスを渡してください。" >&2
  echo "使い方: ./template/init-doc.sh <doc リポジトリのパス> [執筆フォルダ名] [--no-render]" >&2
  echo "        例: ./template/init-doc.sh ~/work/order-design（絶対パス推奨）" >&2
  exit 1
fi

mkdir -p "$REPO_DIR"
REPO_ROOT="$(cd "$REPO_DIR" && pwd)"
CONTENT_ROOT="$REPO_ROOT/$CONTENT_NAME"
mkdir -p "$CONTENT_ROOT"

# パスに ASCII 以外の文字（日本語など）があると、Windows では Quarto から Lua
# フィルタへ渡る時点で文字が壊れ、mermaid の SVG 化（PDF・配布 HTML）が失敗する。
# 執筆・プレビューはできてしまうため、作る時点で止めておく。
case "$CONTENT_ROOT" in
  *[!\ -~]*)
    echo "エラー: パスに ASCII 以外の文字が含まれています:" >&2
    echo "  $CONTENT_ROOT" >&2
    echo "  Windows では mermaid の SVG 化（PDF・配布 HTML）が失敗します。" >&2
    echo "  リポジトリ名・執筆フォルダ名を ASCII（例 docs / design-doc）にしてください。" >&2
    exit 1 ;;
esac

# 既存ファイルは上書きしない（再実行しても本文が消えない）。
copy_new() {
  local src="$1" dst="$2"
  if [ -e "$dst" ]; then
    echo "  skip (既存): ${dst#"$REPO_ROOT"/}"
    return
  fi
  mkdir -p "$(dirname "$dst")"
  cp "$src" "$dst"
  echo "  作成: ${dst#"$REPO_ROOT"/}"
}

echo "doc リポジトリを作ります: $REPO_ROOT （執筆フォルダ: $CONTENT_NAME）"

# 1) リポジトリ直下（ドット付きの名前は scaffold 側で持てないので、ここで付け替える）
copy_new "$SCAFFOLD/repo/gitignore"          "$REPO_ROOT/.gitignore"
copy_new "$SCAFFOLD/repo/gitattributes"      "$REPO_ROOT/.gitattributes"
copy_new "$SCAFFOLD/repo/vscode/settings.json" "$REPO_ROOT/.vscode/settings.json"
if [ -e "$REPO_ROOT/README.md" ]; then
  echo "  skip (既存): README.md"
else
  sed "s/{{CONTENT_DIR}}/$CONTENT_NAME/g" "$SCAFFOLD/repo/README.md" > "$REPO_ROOT/README.md"
  echo "  作成: README.md"
fi

# 2) 執筆フォルダ（本文の雛形）
while IFS= read -r rel; do
  copy_new "$SCAFFOLD/content/$rel" "$CONTENT_ROOT/$rel"
done < <(cd "$SCAFFOLD/content" && find . -type f | sed 's|^\./||' | sort)

# 2') 表紙・前付け（cover.typ）。文書ごとに書き換えてコミットするファイルなので、
#     雛形（scaffold）ではなく template/ から直接置く（実体を1か所にするため）。
#     既にあれば上書きしない。
copy_new "$TEMPLATE_ROOT/cover.typ" "$CONTENT_ROOT/cover.typ"

# 3) 機構ファイル（毎回上書き。実体は template/ の1か所）
"$TEMPLATE_ROOT/update-doc.sh" "$CONTENT_ROOT"

# 4) 執筆者が見る HTML が出せる状態かをその場で確かめる
if [ "$DO_RENDER" = "1" ]; then
  echo "HTML を1回ビルドして確認します（執筆者と同じ経路。node は使いません）..."
  (cd "$CONTENT_ROOT" && quarto render --to html)
  echo "OK -> $CONTENT_NAME/_book/index.html"
fi

cat <<EOS

完了しました。次にやること:
  1) $CONTENT_NAME/_quarto.yml の表題・資料番号・会社名・章の並びを直す
  2) $CONTENT_NAME/index.qmd（前付け）と $CONTENT_NAME/chapters/ を文書に合わせて作る
  3) 表紙・前書きを出すなら _quarto.yml に cover: true を書き、$CONTENT_NAME/cover.typ を直す
  4) cd "$REPO_ROOT" && git init && git add -A && git commit -m "初回セットアップ"
  5) 執筆者に共有する（利用マニュアルの PDF/HTML も一緒に配る）
EOS
