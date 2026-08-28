@echo off
setlocal EnableExtensions
title MRX ScreenSaver — Windows Installer

:: Windows only lists .scr files in System32 (admin required).

net session >nul 2>&1
if %errorlevel% neq 0 (
  echo.
  echo  Administrator approval is required.
  echo  Windows only shows screen savers installed in System32.
  echo.
  powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "Start-Process -FilePath '%~f0' -Verb RunAs -WorkingDirectory '%~dp0'"
  exit /b 0
)

set "SRC=%~dp0MRXScreenSaver.scr"
if not exist "%SRC%" (
  echo.
  echo  ERROR: MRXScreenSaver.scr not found in this folder.
  echo  Unzip MRXScreenSaver-Windows.zip first.
  echo.
  pause
  exit /b 1
)

echo.
echo  Checking dependencies...
call :EnsureWebView2
if errorlevel 1 (
  echo  WebView2 Runtime is required. Install it, then run this again.
  pause
  exit /b 1
)

set "DEST=%SystemRoot%\System32\MRXScreenSaver.scr"
set "DEST_WIN=%SystemRoot%\MRXScreenSaver.scr"

echo.
echo  Installing MRX ScreenSaver...
echo.

copy /Y "%SRC%" "%DEST%" >nul
if errorlevel 1 (
  echo  FAILED: Could not copy to %DEST%
  pause
  exit /b 1
)

copy /Y "%SRC%" "%DEST_WIN%" >nul 2>&1

reg add "HKCU\Control Panel\Desktop" /v SCRNSAVE.EXE /t REG_SZ /d "%DEST%" /f >nul
reg add "HKCU\Control Panel\Desktop" /v ScreenSaveActive /t REG_SZ /d "1" /f >nul

echo  Installed: %DEST%
echo.
echo  Open the CLASSIC dialog: Win+R → control desk.cpl,,1
echo  Choose MRXScreenSaver → Apply / Preview
echo.

start "" "%SystemRoot%\System32\rundll32.exe" shell32.dll,Control_RunDLL desk.cpl,,1

echo  Done.
pause
exit /b 0

:EnsureWebView2
:: WebView2 Evergreen GUID
reg query "HKLM\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}" >nul 2>&1
if %errorlevel% equ 0 exit /b 0
reg query "HKLM\SOFTWARE\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}" >nul 2>&1
if %errorlevel% equ 0 exit /b 0
if exist "%ProgramFiles(x86)%\Microsoft\EdgeWebView\Application" exit /b 0
if exist "%ProgramFiles%\Microsoft\EdgeWebView\Application" exit /b 0

echo  WebView2 Runtime not found — installing...
where winget >nul 2>&1
if %errorlevel% equ 0 (
  winget install --id Microsoft.EdgeWebView2Runtime -e --accept-package-agreements --accept-source-agreements
  if %errorlevel% equ 0 exit /b 0
)

echo.
echo  Please install WebView2 Runtime manually:
echo  https://developer.microsoft.com/microsoft-edge/webview2/
start "" "https://go.microsoft.com/fwlink/p/?LinkId=2124703"
exit /b 1
