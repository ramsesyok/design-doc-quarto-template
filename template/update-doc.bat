@echo off
chcp 65001 >nul
setlocal
rem ============================================================
rem  Update the mechanism files of a writing folder from template/. See update-doc.sh.
rem  Usage:  template\update-doc.bat <path-to-writing-folder>
rem  Places (these ARE committed in a doc repository):
rem    design-doc.lua / design-doc.css / postprocess-html.js / mermaid-config.json
rem    .template-version
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

for %%F in (design-doc.lua design-doc.css postprocess-html.js mermaid-config.json) do (
  copy /Y "%TEMPLATE_ROOT%\%%F" "%CONTENT_DIR%\%%F" >nul
  if errorlevel 1 (
    echo ERROR: failed to copy %%F 1>&2
    exit /b 1
  )
)
copy /Y "%TEMPLATE_ROOT%\VERSION" "%CONTENT_DIR%\.template-version" >nul

set /p TPLVER=<"%TEMPLATE_ROOT%\VERSION"
echo Updated mechanism files in "%CONTENT_DIR%" (template %TPLVER%)
endlocal
