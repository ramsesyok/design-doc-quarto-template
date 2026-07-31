@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
rem ============================================================
rem  社内レビュー用 HTML ビルド（Windows / cmd 版）。詳細は build-html.sh を参照。
rem  使い方（リポジトリのルートから）:  template\build-html.bat [執筆フォルダ名]
rem   - 出力: 執筆フォルダ\_book\ （章ごとの HTML + site_libs\ + search.json）。
rem     _book\index.html を開けばレビューでき、共有は _book\ を zip すればよい。
rem   - 配布 HTML は mermaid を PDF と同じベクター SVG に焼くため MERMAID_SVG=1 を渡す
rem     （執筆者の quarto preview だけは付けず、Quarto 同梱 mermaid でクライアント描画）。
rem   - 図表番号は postprocess-html.mjs で「章.節-連番」に振り直す。
rem ============================================================

set "TEMPLATE_ROOT=%~dp0"
if "%TEMPLATE_ROOT:~-1%"=="\" set "TEMPLATE_ROOT=%TEMPLATE_ROOT:~0,-1%"

set "CONTENT_DIR=%~1"
if "%CONTENT_DIR%"=="" set "CONTENT_DIR=docs"

if not exist "%CONTENT_DIR%\_quarto.yml" (
  echo エラー: "%CONTENT_DIR%\_quarto.yml" が見つかりません。 1>&2
  echo        リポジトリのルートから実行し、第1引数に執筆フォルダ名を渡してください。 1>&2
  exit /b 1
)

rem 執筆環境を整える（冪等）: lib.typ / design-doc.css の配置 + mermaid 用ブラウザ設定。
call "%TEMPLATE_ROOT%\setup.bat" "%CONTENT_DIR%"
if errorlevel 1 (
  echo エラー: setup に失敗しました。 1>&2
  exit /b 1
)

pushd "%CONTENT_DIR%" || exit /b 1

rem 配布 HTML は mermaid を PDF と同じベクター SVG に焼く（MERMAID_SVG=1）。
set "MERMAID_SVG=1"
call quarto render --to html
if errorlevel 1 (
  echo エラー: quarto render に失敗しました。 1>&2
  popd
  exit /b 1
)

node "%TEMPLATE_ROOT%\postprocess-html.mjs" _book
if errorlevel 1 (
  echo エラー: postprocess-html.mjs に失敗しました。 1>&2
  popd
  exit /b 1
)

popd

echo OK: %CONTENT_DIR%\_book\index.html をブラウザで開いてください。
endlocal
