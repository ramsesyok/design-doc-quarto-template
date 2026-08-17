@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
rem ============================================================
rem  Convert <writing-folder>\diagrams\*.mmd to SVG (Windows / cmd).
rem  See render-diagrams.sh for details.
rem  Usage:  template\render-diagrams.bat <path-to-writing-folder>
rem    e.g.  template\render-diagrams.bat C:\work\order-design\docs
rem  - Only for static diagrams referenced from qmd as images. The ```mermaid
rem    fences inside chapters are converted at build time by design-doc.lua.
rem  - Needs mermaid-cli (bundled node_modules, or run npm ci in template\) and
rem    Chrome/Edge. mermaid-cli runs on Quarto's bundled Deno (`quarto run`), so
rem    Node.js is NOT required; node is used only as a fallback.
rem  - Pass the writing folder as an ABSOLUTE path; a relative one resolves
rem    against the current directory, not this script's location.
rem  NOTE: keep this file ASCII only. cmd.exe misparses multibyte (Japanese)
rem        text in .bat files, so comments/messages must stay in English.
rem ============================================================

set "TEMPLATE_ROOT=%~dp0"
if "%TEMPLATE_ROOT:~-1%"=="\" set "TEMPLATE_ROOT=%TEMPLATE_ROOT:~0,-1%"

set "CONTENT_DIR=%~1"
if "%CONTENT_DIR%"=="" set "CONTENT_DIR=docs"

if not exist "%CONTENT_DIR%\" (
  echo ERROR: "%CONTENT_DIR%" not found. 1>&2
  echo        Pass the path of the writing folder as the 1st argument. 1>&2
  exit /b 1
)
pushd "%CONTENT_DIR%" || exit /b 1
set "CONTENT_ROOT=%CD%"

if not exist "diagrams\" (
  echo ERROR: "%CONTENT_ROOT%\diagrams" not found. 1>&2
  popd
  exit /b 1
)

rem Runner for mermaid-cli: Quarto's bundled Deno first, node only as a fallback.
rem Use goto labels rather than if/else blocks (see the note on setup.bat below).
set "RUNNER="
where quarto >nul 2>&1
if not errorlevel 1 set "RUNNER=quarto run"
if defined RUNNER goto :runner_done
where node >nul 2>&1
if not errorlevel 1 set "RUNNER=node"
if defined RUNNER goto :runner_done
echo ERROR: neither quarto nor node found. Install Quarto ^(publisher only^). 1>&2
popd
exit /b 1
:runner_done

set "MMDC=%TEMPLATE_ROOT%\node_modules\@mermaid-js\mermaid-cli\src\cli.js"
if not exist "%MMDC%" (
  echo ERROR: mermaid-cli not found: 1>&2
  echo   %MMDC% 1>&2
  echo   Run "npm ci" in "%TEMPLATE_ROOT%" first. 1>&2
  popd
  exit /b 1
)

rem Config: prefer the copy in the writing folder (same rule as design-doc.lua;
rem a doc repository receives it as a distributed mechanism file).
set "MMDC_CONF=%TEMPLATE_ROOT%\mermaid-config.json"
if exist "%CONTENT_ROOT%\mermaid-config.json" set "MMDC_CONF=%CONTENT_ROOT%\mermaid-config.json"

rem Browser config: EXECUTABLE_BROWSER wins, then the puppeteer.json written by
rem setup, otherwise an empty object. Use goto labels instead of if/else blocks:
rem a parenthesized block that mixes a redirection with a caret escape makes
rem cmd.exe misparse the block (see setup.bat).
set "PP="
set "PP_TMP="
if defined EXECUTABLE_BROWSER goto :pp_env
if exist "%TEMPLATE_ROOT%\puppeteer.json" goto :pp_template
goto :pp_empty

:pp_env
set "PP_TMP=%TEMP%\render-diagrams-%RANDOM%.json"
rem Backslashes must not reach JSON unescaped; use forward slashes (as setup does).
set "WINP=%EXECUTABLE_BROWSER:\=/%"
> "%PP_TMP%" echo {"executablePath": "%WINP%"}
set "PP=%PP_TMP%"
goto :pp_done

:pp_template
set "PP=%TEMPLATE_ROOT%\puppeteer.json"
goto :pp_done

:pp_empty
set "PP_TMP=%TEMP%\render-diagrams-%RANDOM%.json"
> "%PP_TMP%" echo {}
set "PP=%PP_TMP%"

:pp_done

set "COUNT=0"
set "FAILED=0"
for %%F in (diagrams\*.mmd) do (
  echo mermaid: diagrams\%%~nxF to diagrams\%%~nF.svg
  rem Theme etc. live in mermaid-config.json (-t would disable -c).
  %RUNNER% "%MMDC%" -i "%%F" -o "diagrams\%%~nF.svg" -b transparent -p "%PP%" -c "%MMDC_CONF%"
  if errorlevel 1 set "FAILED=1"
  set /a COUNT+=1
)

if defined PP_TMP del /F /Q "%PP_TMP%" >nul 2>&1
popd

if "%COUNT%"=="0" (
  echo WARNING: no .mmd files found in "%CONTENT_ROOT%\diagrams". 1>&2
  exit /b 0
)
if "%FAILED%"=="1" (
  echo ERROR: some diagrams failed to convert. 1>&2
  echo        Check that Chrome/Edge is available ^(see setup^). 1>&2
  exit /b 1
)
echo OK: %COUNT% diagram^(s^) converted.
endlocal
exit /b 0
