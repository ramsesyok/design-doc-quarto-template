#!/usr/bin/env bash
# 発行者へ配るリリースアセットを作る（保守者が実行）。
#
# 使い方（このリポジトリのルートから実行する）:
#   ./template/make-release.sh [出力先フォルダ] [オプション]
#     出力先フォルダ … 省略時は ./release
#     --with-node-modules  template/node_modules も同梱する（閉域向け。約 330MB）
#     --with-sample        サンプル文書（docs/）も同梱する
#     --no-build           マニュアルを再ビルドせず、既にある成果物を使う
#
# 作るもの:
#   <出力先>/quarto-template-<版>/            … 展開済みの一式
#   <出力先>/quarto-template-<版>.zip         … 上を固めたもの
#
# 発行者はこの ZIP を展開したフォルダを**そのまま**使う（中身を取り出さない）。
# 版がフォルダ名に入るので、新旧を並べて置ける。
#
# 中身は README.md / manual（PDF と HTML）/ template 一式。
# ADVANCED.md は保守者専用（版の上げ方・リリースの作り方）なので同梱しない。
# manual の原稿（.qmd）と .git は入れない（発行者は本文を編集しないため）。
set -euo pipefail

TEMPLATE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEMPLATE_ROOT/.." && pwd)"

OUT_DIR=""
WITH_NM=0
WITH_SAMPLE=0
DO_BUILD=1
for arg in "$@"; do
  case "$arg" in
    --with-node-modules) WITH_NM=1 ;;
    --with-sample)       WITH_SAMPLE=1 ;;
    --no-build)          DO_BUILD=0 ;;
    *) if [ -z "$OUT_DIR" ]; then OUT_DIR="$arg"; fi ;;
  esac
done
[ -n "$OUT_DIR" ] || OUT_DIR="$REPO_ROOT/release"

VERSION="$(tr -d ' \r\n' < "$TEMPLATE_ROOT/VERSION")"
NAME="quarto-template-$VERSION"
mkdir -p "$OUT_DIR"
OUT_ROOT="$(cd "$OUT_DIR" && pwd)"
STAGE="$OUT_ROOT/$NAME"

echo "リリースを作ります: $NAME"

# 1) マニュアルをビルドする。**PDF → HTML の順**（どちらも _book/ を使うため、
#    逆順にすると HTML が PDF ビルドで消える）。
if [ "$DO_BUILD" = "1" ]; then
  echo "  マニュアルをビルド中（PDF → HTML の順）..."
  "$TEMPLATE_ROOT/build-qmd.sh"  "$REPO_ROOT/manual" > /dev/null
  "$TEMPLATE_ROOT/build-html.sh" "$REPO_ROOT/manual" > /dev/null
fi
if [ ! -f "$REPO_ROOT/manual/design-doc.pdf" ] || [ ! -f "$REPO_ROOT/manual/_book/index.html" ]; then
  echo "エラー: マニュアルの成果物がありません（PDF と _book/ の両方が要る）。" >&2
  echo "       --no-build を外して実行してください。" >&2
  exit 1
fi

# 2) 収集する（毎回作り直す）
rm -rf "$STAGE"
mkdir -p "$STAGE/manual" "$STAGE/template"

cp "$TEMPLATE_ROOT/release-README.md" "$STAGE/README-release.md"
cp "$REPO_ROOT/README.md"             "$STAGE/README.md"
# ADVANCED.md は保守者専用なので同梱しない（発行者は README + manual で足りる）

cp "$REPO_ROOT/manual/design-doc.pdf" "$STAGE/manual/利用マニュアル.pdf"
cp -r "$REPO_ROOT/manual/_book"       "$STAGE/manual/html"

# template 一式（machine ローカルの puppeteer.json と、既定では node_modules を除く）
for f in "$TEMPLATE_ROOT"/*; do
  base="$(basename "$f")"
  case "$base" in
    node_modules|puppeteer.json) continue ;;
  esac
  cp -r "$f" "$STAGE/template/"
done
if [ "$WITH_NM" = "1" ]; then
  if [ -d "$TEMPLATE_ROOT/node_modules" ]; then
    echo "  node_modules を同梱中（時間がかかります）..."
    cp -r "$TEMPLATE_ROOT/node_modules" "$STAGE/template/node_modules"
  else
    echo "警告: node_modules がありません（先に template で npm ci が要る）。" >&2
  fi
fi

if [ "$WITH_SAMPLE" = "1" ]; then
  mkdir -p "$STAGE/docs"
  # 生成物は入れない（原稿と図だけ）
  for f in "$REPO_ROOT"/docs/*; do
    base="$(basename "$f")"
    case "$base" in
      _book|.quarto|design-doc.pdf|lib.typ|typst-template.typ|typst-show.typ|_quarto-publish.yml) continue ;;
    esac
    cp -r "$f" "$STAGE/docs/"
  done
  rm -f "$STAGE"/docs/diagrams/mmd-* 2>/dev/null || true
fi

# 2.5) 改行コードを配布先の前提にそろえる。
# .bat が LF のままだと、cmd.exe が for/if の複数行ブロックを解釈できず
# 「'xxx' は内部コマンドまたは外部コマンド…ではありません」で落ちる（実測）。
# リポジトリでは .gitattributes が面倒を見るが、リリースは作業ツリーからコピーする
# ので、ここで明示的に直しておく。
if command -v python > /dev/null 2>&1; then
  python - "$STAGE" <<'PY'
import os, sys
root = sys.argv[1]
for dirpath, _dirs, files in os.walk(root):
    for name in files:
        p = os.path.join(dirpath, name)
        if name.endswith('.bat'):
            b = open(p, 'rb').read().replace(b'\r\n', b'\n').replace(b'\n', b'\r\n')
        elif name.endswith('.sh'):
            b = open(p, 'rb').read().replace(b'\r\n', b'\n')
        else:
            continue
        open(p, 'wb').write(b)
PY
fi

# 3) zip に固める。
# **注意**: GNU tar は zip を作れない。`tar -a -c -f x.zip` は拡張子が .zip でも
# 中身は tar のままで、zip として開けないものができる（Git Bash で実測）。
# zip → bsdtar（libarchive。Windows 10/11 同梱の tar.exe はこちら）→ python の順に試す。
ZIP="$OUT_ROOT/$NAME.zip"
rm -f "$ZIP"
make_zip() {
  if command -v zip > /dev/null 2>&1; then
    (cd "$OUT_ROOT" && zip -qr "$NAME.zip" "$NAME") && return 0
  fi
  for t in tar /c/Windows/System32/tar.exe; do
    if command -v "$t" > /dev/null 2>&1 && "$t" --version 2>&1 | grep -qi 'bsdtar\|libarchive'; then
      (cd "$OUT_ROOT" && "$t" -a -c -f "$NAME.zip" "$NAME") && return 0
    fi
  done
  if command -v python > /dev/null 2>&1; then
    python - "$OUT_ROOT" "$NAME" <<'PY' && return 0
import os, sys, zipfile
root, name = sys.argv[1], sys.argv[2]
base = os.path.join(root, name)
with zipfile.ZipFile(os.path.join(root, name + '.zip'), 'w', zipfile.ZIP_DEFLATED) as z:
    for dirpath, _dirs, files in os.walk(base):
        for f in files:
            p = os.path.join(dirpath, f)
            z.write(p, os.path.join(name, os.path.relpath(p, base)))
PY
  fi
  return 1
}
if ! make_zip; then
  echo "警告: zip を作れませんでした（zip / bsdtar / python のいずれも使えません）。" >&2
  echo "      展開済みフォルダはできているので、手で固めてください。" >&2
  ZIP=""
fi

echo
echo "完了しました（テンプレート $VERSION）"
echo "  フォルダ: $STAGE"
[ -n "$ZIP" ] && echo "  ZIP     : $ZIP"
echo
echo "同梱: README / manual（PDF・HTML）/ template"
[ "$WITH_NM" = "1" ]     && echo "      ＋ template/node_modules"
[ "$WITH_SAMPLE" = "1" ] && echo "      ＋ docs（サンプル文書）"
exit 0
