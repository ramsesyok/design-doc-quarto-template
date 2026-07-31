@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
rem ============================================================
rem  PDF build (Windows / cmd). See build-qmd.sh for details.
rem  Usage (from the repository root):  template\build-qmd.bat [content-dir]
rem   - qmd -> typst -> PDF. Quarto bundles typst, so Quarto alone is enough.
rem   - The deliverable PDF is written to <content-dir>\design-doc.pdf (_book\ is rebuilt).
rem   - mermaid is baked to vector SVG (typst path; needs node + Chrome/Edge).
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

call quarto render --to typst
if errorlevel 1 (
  echo ERROR: quarto render failed. 1>&2
  popd
  exit /b 1
)

rem Extract the deliverable PDF to the content dir root (_book\ is rebuilt next time).
copy /Y "_book\*.pdf" "design-doc.pdf" >nul
if errorlevel 1 (
  echo ERROR: could not extract the PDF; _book\*.pdf not found. 1>&2
  popd
  exit /b 1
)

popd

echo OK -^> %CONTENT_DIR%\design-doc.pdf
endlocal
