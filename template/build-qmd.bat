@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
rem ============================================================
rem  PDF ビルド（Windows / cmd 版）。詳細は build-qmd.sh を参照。
rem  使い方（リポジトリのルートから）:  template\build-qmd.bat [執筆フォルダ名]
rem   - qmd → typst → PDF。Quarto は typst を同梱するので Quarto だけで動く。
rem   - 納品物 PDF は執筆フォルダ直下 design-doc.pdf に取り出す（_book\ は作り直す）。
rem   - mermaid はベクター SVG に焼く（typst 経路。node + Chrome/Edge が要る）。
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

call quarto render --to typst
if errorlevel 1 (
  echo エラー: quarto render に失敗しました。 1>&2
  popd
  exit /b 1
)

rem 納品物 PDF を執筆フォルダ直下へ取り出す（_book\ は次のビルドで作り直される）。
copy /Y "_book\*.pdf" "design-doc.pdf" >nul
if errorlevel 1 (
  echo エラー: PDF の取り出しに失敗しました（_book\*.pdf が見つからない）。 1>&2
  popd
  exit /b 1
)

popd

echo OK -^> %CONTENT_DIR%\design-doc.pdf
endlocal
