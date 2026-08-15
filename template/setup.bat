@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
rem ============================================================
rem  Prepare the publisher's build environment (Windows / cmd). Idempotent. See setup.sh.
rem  Usage:  template\setup.bat <path-to-writing-folder>
rem   1) Place the mechanism files (via update-doc.bat)
rem   2) Place the PDF-side files: lib.typ, typst partials, _quarto-publish.yml
rem   3) Detect Chrome/Edge and record it in template\puppeteer.json (for mermaid)
rem  Authors do NOT run this: Quarto + the VSCode extension are enough for HTML.
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

rem 1) Mechanism files (HTML side; committed in a doc repository)
call "%TEMPLATE_ROOT%\update-doc.bat" "%CONTENT_DIR%"
if errorlevel 1 exit /b 1

rem 2) PDF side (always overwrite; all git-ignored in a doc repository)
copy /Y "%TEMPLATE_ROOT%\lib.typ"            "%CONTENT_DIR%\lib.typ" >nul
copy /Y "%TEMPLATE_ROOT%\typst-template.typ" "%CONTENT_DIR%\typst-template.typ" >nul
copy /Y "%TEMPLATE_ROOT%\typst-show.typ"     "%CONTENT_DIR%\typst-show.typ" >nul
copy /Y "%TEMPLATE_ROOT%\quarto-publish.yml" "%CONTENT_DIR%\_quarto-publish.yml" >nul
echo Placed: lib.typ, typst-template.typ, typst-show.typ, _quarto-publish.yml

rem 3) Browser for mermaid (detect Chrome, then Edge). EXECUTABLE_BROWSER takes priority.
set "BROWSER=%EXECUTABLE_BROWSER%"
if not defined BROWSER (
  for %%P in (
    "%ProgramFiles%\Google\Chrome\Application\chrome.exe"
    "%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe"
    "%ProgramFiles%\Microsoft\Edge\Application\msedge.exe"
    "%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe"
  ) do (
    if not defined BROWSER if exist "%%~P" set "BROWSER=%%~P"
  )
)

set "PP=%TEMPLATE_ROOT%\puppeteer.json"
rem NOTE: use goto labels instead of an if/else block here. A parenthesized
rem block that mixes a redirection (>"%PP%" echo ...) with a caret escape
rem (echo ... -^> ...) makes cmd.exe misparse the block (". was unexpected").
if not defined BROWSER goto :no_browser

set "WINP=%BROWSER:\=/%"
> "%PP%" echo {"executablePath": "%WINP%", "args": ["--no-sandbox"]}
echo mermaid browser: %WINP%
echo   recorded in %PP%
goto :after_browser

:no_browser
echo WARNING: Chrome / Edge not found. 1>&2
echo          The PDF / distribution HTML cannot vectorize mermaid diagrams. 1>&2
echo          Set EXECUTABLE_BROWSER to chrome.exe / msedge.exe and re-run. 1>&2

:after_browser
echo OK: build environment ready for "%CONTENT_DIR%".
endlocal
