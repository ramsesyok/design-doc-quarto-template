@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
rem ============================================================
rem  執筆環境の初期化（Windows / cmd 版）。冪等。詳細は setup.sh を参照。
rem  使い方（リポジトリのルートから）:  template\setup.bat [執筆フォルダ名]
rem   1) template の lib.typ / design-doc.css を執筆フォルダへ配置
rem   2) Chrome/Edge を検出して template\puppeteer.json に記録（mermaid 用）
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

rem 1) 機構ファイルを配置（常に上書き）
copy /Y "%TEMPLATE_ROOT%\lib.typ" "%CONTENT_DIR%\lib.typ" >nul
copy /Y "%TEMPLATE_ROOT%\design-doc.css" "%CONTENT_DIR%\design-doc.css" >nul
echo 配置: %CONTENT_DIR%\lib.typ, %CONTENT_DIR%\design-doc.css

rem 2) mermaid 用ブラウザ（Chrome → Edge の順に検出）。EXECUTABLE_BROWSER があれば優先。
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
if defined BROWSER (
  set "WINP=!BROWSER:\=/!"
  >"%PP%" echo {"executablePath": "!WINP!", "args": ["--no-sandbox"]}
  echo mermaid 用ブラウザ: !WINP!
  echo   -^> %PP% に記録しました
) else (
  echo 警告: Chrome / Edge が見つかりませんでした。 1>&2
  echo       mermaid を使うなら EXECUTABLE_BROWSER を指定して再実行してください。 1>&2
)

echo OK: "%CONTENT_DIR%" の初期化が完了しました。
endlocal
