@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
rem ============================================================
rem  Build the release asset for publishers (Windows / cmd). See make-release.sh.
rem  Usage (from the repository root):
rem    template\make-release.bat [out-dir] [--with-node-modules] [--with-sample] [--no-build]
rem  Produces:
rem    <out-dir>\quarto-template-<version>\      (extracted tree)
rem    <out-dir>\quarto-template-<version>.zip   (zipped, via PowerShell)
rem  Publishers use the extracted folder AS IS (they do not move its contents out).
rem  The version is part of the folder name, so old and new releases can coexist.
rem  NOTE: keep this file ASCII only. cmd.exe misparses multibyte (Japanese)
rem        text in .bat files, so comments/messages must stay in English.
rem ============================================================

set "TEMPLATE_ROOT=%~dp0"
if "%TEMPLATE_ROOT:~-1%"=="\" set "TEMPLATE_ROOT=%TEMPLATE_ROOT:~0,-1%"
for %%I in ("%TEMPLATE_ROOT%\..") do set "REPO_ROOT=%%~fI"

set "OUT_DIR="
set "WITH_NM=0"
set "WITH_SAMPLE=0"
set "DO_BUILD=1"
for %%A in (%*) do (
  if "%%~A"=="--with-node-modules" (
    set "WITH_NM=1"
  ) else if "%%~A"=="--with-sample" (
    set "WITH_SAMPLE=1"
  ) else if "%%~A"=="--no-build" (
    set "DO_BUILD=0"
  ) else (
    if not defined OUT_DIR set "OUT_DIR=%%~A"
  )
)
if not defined OUT_DIR set "OUT_DIR=%REPO_ROOT%\release"

set /p VERSION=<"%TEMPLATE_ROOT%\VERSION"
set "VERSION=%VERSION: =%"
set "NAME=quarto-template-%VERSION%"

if not exist "%OUT_DIR%" mkdir "%OUT_DIR%"
pushd "%OUT_DIR%" || exit /b 1
set "OUT_ROOT=%CD%"
popd
set "STAGE=%OUT_ROOT%\%NAME%"

echo Building release: %NAME%

rem 1) Build the manual. PDF first, then HTML (both use _book\, later one wins).
if "%DO_BUILD%"=="1" (
  echo   building manual ^(PDF then HTML^)...
  call "%TEMPLATE_ROOT%\build-qmd.bat" "%REPO_ROOT%\manual" >nul
  if errorlevel 1 ( echo ERROR: manual PDF build failed. 1>&2 & exit /b 1 )
  call "%TEMPLATE_ROOT%\build-html.bat" "%REPO_ROOT%\manual" >nul
  if errorlevel 1 ( echo ERROR: manual HTML build failed. 1>&2 & exit /b 1 )
)
if not exist "%REPO_ROOT%\manual\design-doc.pdf" (
  echo ERROR: manual\design-doc.pdf not found ^(drop --no-build^). 1>&2
  exit /b 1
)
if not exist "%REPO_ROOT%\manual\_book\index.html" (
  echo ERROR: manual\_book\index.html not found ^(drop --no-build^). 1>&2
  exit /b 1
)

rem 2) Collect (always rebuilt from scratch)
if exist "%STAGE%" rmdir /S /Q "%STAGE%"
mkdir "%STAGE%\manual"
mkdir "%STAGE%\template"

copy /Y "%TEMPLATE_ROOT%\release-README.md" "%STAGE%\README-release.md" >nul
copy /Y "%REPO_ROOT%\README.md"             "%STAGE%\README.md" >nul
rem ADVANCED.md is maintainer-only, so it is NOT shipped in the release.

copy /Y "%REPO_ROOT%\manual\design-doc.pdf" "%STAGE%\manual\利用マニュアル.pdf" >nul
rem NOTE: robocopy, not xcopy. xcopy fails with "Insufficient memory" on long
rem       destination paths and **silently skips files** (measured: 10 of 41 lost).
robocopy "%REPO_ROOT%\manual\_book" "%STAGE%\manual\html" /E /NFL /NDL /NJH /NJS /NP >nul
if errorlevel 8 (
  echo ERROR: copying the manual HTML failed. 1>&2
  exit /b 1
)

rem template: everything except node_modules and the machine-local puppeteer.json.
rem NOTE: robocopy, not xcopy. xcopy's /EXCLUDE takes an unquoted path and reports
rem       "Insufficient memory" when it cannot parse the list; robocopy /XD /XF is
rem       reliable. robocopy returns 0-7 on success, so only 8+ is an error.
robocopy "%TEMPLATE_ROOT%" "%STAGE%\template" /E /NFL /NDL /NJH /NJS /NP /XD node_modules /XF puppeteer.json >nul
if errorlevel 8 (
  echo ERROR: copying template failed. 1>&2
  exit /b 1
)

if "%WITH_NM%"=="1" (
  if exist "%TEMPLATE_ROOT%\node_modules" (
    echo   copying node_modules ^(this takes a while^)...
    robocopy "%TEMPLATE_ROOT%\node_modules" "%STAGE%\template\node_modules" /E /NFL /NDL /NJH /NJS /NP >nul
  ) else (
    echo WARNING: node_modules not found ^(run npm ci in template first^). 1>&2
  )
)

if "%WITH_SAMPLE%"=="1" (
  robocopy "%REPO_ROOT%\docs" "%STAGE%\docs" /E /NFL /NDL /NJH /NJS /NP /XD _book .quarto /XF design-doc.pdf lib.typ typst-template.typ typst-show.typ cover.typ _quarto-publish.yml mmd-* >nul
  if errorlevel 8 (
    echo ERROR: copying the sample failed. 1>&2
    exit /b 1
  )
)

rem 3) Zip it.
rem **The zipper must set the UTF-8 name flag (general purpose bit 11).**
rem manual\ holds a Japanese file name. bsdtar (tar.exe -a) writes names in the
rem local ANSI code page WITHOUT that flag, so every UTF-8 based extractor
rem (Expand-Archive, 7-Zip, macOS, Linux unzip) shows mojibake (measured).
rem .NET's ZipFile sets the flag, so try it first. But it throws
rem DirectoryNotFoundException once a member path exceeds MAX_PATH (260) and
rem **leaves a truncated zip behind**, so check the exit code (never "if exist")
rem and delete the partial file before falling back to bsdtar.
set "ZIP=%OUT_ROOT%\%NAME%.zip"
if exist "%ZIP%" del /Q "%ZIP%"
pushd "%OUT_ROOT%" || exit /b 1

powershell -NoProfile -Command "Add-Type -AssemblyName System.IO.Compression.FileSystem; [System.IO.Compression.ZipFile]::CreateFromDirectory('%STAGE%', '%ZIP%', 'Optimal', $true)"
if not errorlevel 1 goto :zip_verify
if exist "%ZIP%" del /Q "%ZIP%"

echo WARNING: .NET zip failed (a member path over MAX_PATH?); using bsdtar. 1>&2
echo          bsdtar does not set the UTF-8 name flag, so the Japanese manual 1>&2
echo          file name WILL be mojibake for anyone extracting the zip. 1>&2
echo          Shorten the output path ^(1st argument^) and re-run to avoid this. 1>&2
where tar >nul 2>&1
if errorlevel 1 goto :zip_done
tar -a -c -f "%NAME%.zip" "%NAME%"
if errorlevel 1 if exist "%ZIP%" del /Q "%ZIP%"

:zip_verify
rem The .NET writer truncates silently when it throws, so always confirm that
rem every staged file made it into the archive before handing the zip over.
rem NOTE: inside cmd's double quotes a bare "|" is literal and must NOT be
rem       caret-escaped (a "^|" would reach PowerShell and fail to parse).
if not exist "%ZIP%" goto :zip_done
powershell -NoProfile -Command "Add-Type -AssemblyName System.IO.Compression.FileSystem; $z=[System.IO.Compression.ZipFile]::OpenRead('%ZIP%'); $n=($z.Entries | Where-Object { $_.Name -ne '' }).Count; $z.Dispose(); $disk=(Get-ChildItem -LiteralPath '%STAGE%' -Recurse -File).Count; if ($n -ne $disk) { Write-Host ('  files in zip: ' + $n + ' / on disk: ' + $disk); exit 2 }"
if errorlevel 2 (
  echo ERROR: the zip is missing files. Do not distribute it. 1>&2
  del /Q "%ZIP%"
)

:zip_done
popd
if not exist "%ZIP%" (
  echo WARNING: could not create the zip; the extracted folder is still there. 1>&2
  set "ZIP="
)

echo.
echo Done (template %VERSION%)
echo   folder: %STAGE%
if defined ZIP echo   zip   : %ZIP%
echo.
echo Contains: README / manual (PDF + HTML) / template
if "%WITH_NM%"=="1"     echo           + template\node_modules
if "%WITH_SAMPLE%"=="1" echo           + docs (sample document)
endlocal
exit /b 0
