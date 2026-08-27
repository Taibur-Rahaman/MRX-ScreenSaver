@echo off
setlocal EnableExtensions
title MRX ScreenSaver — Windows Installer

:: Windows only lists .scr files in System32 (admin required).
:: Do NOT install to LocalAppData — it will never appear in the list.

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

set "DEST=%SystemRoot%\System32\MRXScreenSaver.scr"
set "DEST_WIN=%SystemRoot%\MRXScreenSaver.scr"

echo.
echo  Installing MRX ScreenSaver...
echo.

copy /Y "%SRC%" "%DEST%" >nul
if errorlevel 1 (
  echo  FAILED: Could not copy to %DEST%
  echo  Try right-click Install.bat -^> Run as administrator
  pause
  exit /b 1
)

copy /Y "%SRC%" "%DEST_WIN%" >nul 2>&1

:: Select this screen saver for the current user
reg add "HKCU\Control Panel\Desktop" /v SCRNSAVE.EXE /t REG_SZ /d "%DEST%" /f >nul
reg add "HKCU\Control Panel\Desktop" /v ScreenSaveActive /t REG_SZ /d "1" /f >nul

echo  Installed: %DEST%
echo  Registry:  SCRNSAVE.EXE set to MRXScreenSaver
echo.
echo  IMPORTANT — use the CLASSIC dialog (not Windows 11 Settings):
echo    • Press Win+R, type:  control desk.cpl,,1
echo    • Or run:  Open-Screen-Saver-Settings.bat
echo.
echo  In the dropdown, choose "MRXScreenSaver" then Apply / OK.
echo  (Windows 11 Settings -^> Personalization does NOT list third-party savers.)
echo.

start "" "%SystemRoot%\System32\rundll32.exe" shell32.dll,Control_RunDLL desk.cpl,,1

echo  Done.
pause
exit /b 0
