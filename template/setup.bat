@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
rem ============================================================
rem  Initialize the writing environment (Windows / cmd). Idempotent. See setup.sh.
rem  Usage (from the repository root):  template\setup.bat [content-dir]
rem   1) Copy template's lib.typ / design-doc.css into the content dir
rem   2) Detect Chrome/Edge and record it in template\puppeteer.json (for mermaid)
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

rem 1) Place mechanism files (always overwrite)
copy /Y "%TEMPLATE_ROOT%\lib.typ" "%CONTENT_DIR%\lib.typ" >nul
copy /Y "%TEMPLATE_ROOT%\design-doc.css" "%CONTENT_DIR%\design-doc.css" >nul
echo Placed: %CONTENT_DIR%\lib.typ, %CONTENT_DIR%\design-doc.css

rem 2) Browser for mermaid (detect Chrome, then Edge). EXECUTABLE_BROWSER takes priority.
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
echo          Writing and preview still work (mermaid renders in-browser, no node). 1>&2
echo          Only when building the deliverable PDF / distribution HTML, set EXECUTABLE_BROWSER and re-run. 1>&2

:after_browser
echo OK: initialized "%CONTENT_DIR%".
endlocal
