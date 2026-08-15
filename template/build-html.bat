@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
rem ============================================================
rem  Distribution HTML build (Windows / cmd). See build-html.sh for details.
rem  Usage:  template\build-html.bat <path-to-writing-folder>
rem   - Output: <content-dir>\_book\ (per-chapter HTML + site_libs\ + search.json).
rem     Open _book\index.html to review; zip _book\ to share.
rem   - Distribution HTML bakes mermaid to the same vector SVG as the PDF, so
rem     MERMAID_SVG=1 is passed (the author's quarto preview omits it and renders
rem     mermaid client-side with Quarto's bundled runtime).
rem   - Figure/table numbers are re-numbered by postprocess-html.js, which runs as
rem     the project's post-render hook (do NOT call it again from here).
rem  NOTE: keep this file ASCII only. cmd.exe misparses multibyte (Japanese)
rem        text in .bat files, so comments/messages must stay in English.
rem ============================================================

set "TEMPLATE_ROOT=%~dp0"
if "%TEMPLATE_ROOT:~-1%"=="\" set "TEMPLATE_ROOT=%TEMPLATE_ROOT:~0,-1%"

set "CONTENT_DIR=%~1"
if "%CONTENT_DIR%"=="" set "CONTENT_DIR=docs"

if not exist "%CONTENT_DIR%\_quarto.yml" (
  echo ERROR: "%CONTENT_DIR%\_quarto.yml" not found. 1>&2
  echo        Pass the path of the writing folder as the 1st argument. 1>&2
  exit /b 1
)

rem Prepare the build environment (idempotent): mechanism files + PDF partials + mermaid browser config.
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

rem Figure/table numbering is done by the post-render hook (postprocess-html.js).

popd

echo OK: open %CONTENT_DIR%\_book\index.html in your browser.
endlocal
