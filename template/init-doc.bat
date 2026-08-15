@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
rem ============================================================
rem  Create a new design-document repository (Windows / cmd). See init-doc.sh.
rem  Usage:  template\init-doc.bat <repo-path> [writing-folder-name] [--no-render]
rem    e.g.  template\init-doc.bat C:\work\order-design
rem  - Pass the repo path as an ABSOLUTE path. A relative path resolves against the
rem    current directory (not this script's location). init-doc creates what does not
rem    exist, so a wrong path is not detected and the repo lands somewhere unintended.
rem  - Existing files are never overwritten (safe to re-run).
rem  - Mechanism files come from update-doc.bat.
rem  - Renders HTML once at the end to verify the authoring path works.
rem  NOTE: keep this file ASCII only. cmd.exe misparses multibyte (Japanese)
rem        text in .bat files, so comments/messages must stay in English.
rem ============================================================

set "TEMPLATE_ROOT=%~dp0"
if "%TEMPLATE_ROOT:~-1%"=="\" set "TEMPLATE_ROOT=%TEMPLATE_ROOT:~0,-1%"
set "SCAFFOLD=%TEMPLATE_ROOT%\scaffold"

set "REPO_DIR="
set "CONTENT_NAME=docs"
set "DO_RENDER=1"
for %%A in (%*) do (
  if "%%~A"=="--no-render" (
    set "DO_RENDER=0"
  ) else (
    if not defined REPO_DIR ( set "REPO_DIR=%%~A" ) else ( set "CONTENT_NAME=%%~A" )
  )
)

if not defined REPO_DIR (
  echo ERROR: pass the repository path as the 1st argument. 1>&2
  echo Usage: template\init-doc.bat ^<repo-path^> [writing-folder-name] [--no-render] 1>&2
  exit /b 1
)

if not exist "%REPO_DIR%" mkdir "%REPO_DIR%"
pushd "%REPO_DIR%" || exit /b 1
set "REPO_ROOT=%CD%"
popd
set "CONTENT_ROOT=%REPO_ROOT%\%CONTENT_NAME%"

rem Non-ASCII paths break the mermaid SVG step on Windows: Quarto hands the Lua
rem filter a path whose non-ASCII characters are already replaced by U+FFFD, so
rem the PDF / distribution HTML build fails. Stop here instead.
powershell -NoProfile -Command "if ('%CONTENT_ROOT%' -match '[^\x20-\x7e]') { exit 1 } else { exit 0 }"
if errorlevel 1 (
  echo ERROR: the path contains non-ASCII characters: 1>&2
  echo   %CONTENT_ROOT% 1>&2
  echo   mermaid cannot be vectorized on Windows with such a path. 1>&2
  echo   Use ASCII names for the repository and the writing folder ^(e.g. docs^). 1>&2
  exit /b 1
)

if not exist "%CONTENT_ROOT%" mkdir "%CONTENT_ROOT%"

echo Creating doc repository: %REPO_ROOT%  (writing folder: %CONTENT_NAME%)

rem 1) Repository root (dot-prefixed names cannot live in scaffold/, so rename here)
call :copy_new "%SCAFFOLD%\repo\gitignore"            "%REPO_ROOT%\.gitignore"
call :copy_new "%SCAFFOLD%\repo\gitattributes"        "%REPO_ROOT%\.gitattributes"
call :copy_new "%SCAFFOLD%\repo\vscode\settings.json" "%REPO_ROOT%\.vscode\settings.json"

if exist "%REPO_ROOT%\README.md" (
  echo   skip ^(exists^): README.md
) else (
  rem Substitute the writing-folder name. PowerShell writes UTF-8 without BOM.
  powershell -NoProfile -Command "$t = [IO.File]::ReadAllText('%SCAFFOLD%\repo\README.md'); $t = $t.Replace('{{CONTENT_DIR}}', '%CONTENT_NAME%'); [IO.File]::WriteAllText('%REPO_ROOT%\README.md', $t, (New-Object Text.UTF8Encoding $false))"
  echo   created: README.md
)

rem 2) Writing folder (content skeleton)
set "SRCDIR=%SCAFFOLD%\content"
for /r "%SRCDIR%" %%F in (*) do (
  set "ABS=%%F"
  set "REL=!ABS:%SRCDIR%\=!"
  call :copy_new "%%F" "%CONTENT_ROOT%\!REL!"
)

rem 3) Mechanism files (always overwritten; single source is template\)
call "%TEMPLATE_ROOT%\update-doc.bat" "%CONTENT_ROOT%"
if errorlevel 1 exit /b 1

rem 4) Verify the authoring path (same route as the author; no node involved)
if "%DO_RENDER%"=="1" (
  echo Rendering HTML once to verify...
  pushd "%CONTENT_ROOT%" || exit /b 1
  call quarto render --to html
  if errorlevel 1 (
    echo ERROR: quarto render failed. 1>&2
    popd
    exit /b 1
  )
  popd
  echo OK -^> %CONTENT_NAME%\_book\index.html
)

echo.
echo Done. Next:
echo   1) edit %CONTENT_NAME%\_quarto.yml (title, doc-number, company, chapters)
echo   2) write %CONTENT_NAME%\index.qmd and %CONTENT_NAME%\chapters\
echo   3) cd "%REPO_ROOT%" ^&^& git init ^&^& git add -A ^&^& git commit -m "init"
echo   4) share with the authors (hand out the manual PDF/HTML as well)
endlocal
exit /b 0

:copy_new
if exist "%~2" (
  echo   skip ^(exists^): %~2
  goto :eof
)
if not exist "%~dp2" mkdir "%~dp2"
copy /Y "%~1" "%~2" >nul
echo   created: %~2
goto :eof
