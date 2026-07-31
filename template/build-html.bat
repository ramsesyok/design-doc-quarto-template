@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
rem ============================================================
rem  HTML build for internal review (Windows / cmd). See build-html.sh for details.
rem  Usage (from the repository root):  template\build-html.bat [content-dir]
rem   - Output: <content-dir>\_book\ (per-chapter HTML + site_libs\ + search.json).
rem     Open _book\index.html to review; zip _book\ to share.
rem   - Distribution HTML bakes mermaid to the same vector SVG as the PDF, so
rem     MERMAID_SVG=1 is passed (the author's quarto preview omits it and renders
rem     mermaid client-side with Quarto's bundled runtime).
rem   - Figure/table numbers are re-numbered to "chapter.section-index" by postprocess-html.mjs.
rem  NOTE: keep this file ASCII only. cmd.exe misparses multibyte (Japanese)
rem        text in .bat files, so comments/messages must stay in English.
rem ============================================================

set "TEMPLATE_ROOT=%~dp0"
if "%TEMPLATE_ROOT:~-1%"=="\" set "TEMPLATE_ROOT=%TEMPLATE_ROOT:~0,-1%"

set "CONTENT_DIR=%~1"
if "%CONTENT_DIR%"=="" set "CONTENT_DIR=docs"

if not exist "%CONTENT_DIR%\_quarto.yml" (
  echo ERROR: "%CONTENT_DIR%\_quarto.yml" not found. 1>&2
  echo        Run from the repository root and pass the content dir as the 1st argument. 1>&2
  exit /b 1
)

rem Prepare the writing environment (idempotent): place lib.typ / design-doc.css + mermaid browser config.
call "%TEMPLATE_ROOT%\setup.bat" "%CONTENT_DIR%"
if errorlevel 1 (
  echo ERROR: setup failed. 1>&2
  exit /b 1
)

pushd "%CONTENT_DIR%" || exit /b 1

rem Distribution HTML bakes mermaid to the same vector SVG as the PDF (MERMAID_SVG=1).
set "MERMAID_SVG=1"
call quarto render --to html
if errorlevel 1 (
  echo ERROR: quarto render failed. 1>&2
  popd
  exit /b 1
)

node "%TEMPLATE_ROOT%\postprocess-html.mjs" _book
if errorlevel 1 (
  echo ERROR: postprocess-html.mjs failed. 1>&2
  popd
  exit /b 1
)

popd

echo OK: open %CONTENT_DIR%\_book\index.html in your browser.
endlocal
