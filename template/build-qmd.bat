@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
rem ============================================================
rem  PDF build (Windows / cmd). See build-qmd.sh for details.
rem  Usage:  template\build-qmd.bat <path-to-writing-folder>
rem   - qmd -> typst -> PDF. Quarto bundles typst, so Quarto alone is enough.
rem   - The deliverable PDF is written to <content-dir>\design-doc.pdf (_book\ is rebuilt).
rem   - mermaid is baked to vector SVG (typst path; needs Chrome/Edge. mermaid-cli
rem     runs on Quarto's bundled Deno, so Node.js is not required).
rem   - typst settings live in _quarto-publish.yml, hence --profile publish.
rem   - TEMPLATE_ROOT is exported so template/ may sit outside the doc repository.
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

call quarto render --to typst --profile publish
if errorlevel 1 (
  echo ERROR: quarto render failed. 1>&2
  popd
  exit /b 1
)

rem Extract the PDF to the content dir root (_book\ is rebuilt next time).
rem In a doc repository this PDF is committed and shared as the interim version.
rem NOTE: resolve the name first and copy /B. `copy "_book\*.pdf" out.pdf` takes the
rem       wildcard-to-single-file path, which cmd runs in ASCII concat mode: it stops
rem       at the first 0x1A (Ctrl-Z) byte and silently writes a truncated, unreadable
rem       PDF. Compressed PDF streams contain 0x1A regularly.
set "PDF_SRC="
for %%F in ("_book\*.pdf") do if not defined PDF_SRC set "PDF_SRC=%%~fF"
if not defined PDF_SRC (
  echo ERROR: could not extract the PDF; _book\*.pdf not found. 1>&2
  popd
  exit /b 1
)
copy /B /Y "%PDF_SRC%" "design-doc.pdf" >nul
if errorlevel 1 (
  echo ERROR: could not extract the PDF. 1>&2
  popd
  exit /b 1
)

popd

echo OK -^> %CONTENT_DIR%\design-doc.pdf
endlocal
