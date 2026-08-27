@echo off
setlocal EnableExtensions
title MRX ScreenSaver — Uninstall

net session >nul 2>&1
if %errorlevel% neq 0 (
  powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b 0
)

set "DEST=%SystemRoot%\System32\MRXScreenSaver.scr"
set "DEST_WIN=%SystemRoot%\MRXScreenSaver.scr"

if exist "%DEST%" del /F /Q "%DEST%"
if exist "%DEST_WIN%" del /F /Q "%DEST_WIN%"

for /f "tokens=2,*" %%A in ('reg query "HKCU\Control Panel\Desktop" /v SCRNSAVE.EXE 2^>nul ^| find /i "SCRNSAVE.EXE"') do (
  echo %%B | find /i "MRXScreenSaver" >nul && (
    reg delete "HKCU\Control Panel\Desktop" /v SCRNSAVE.EXE /f >nul 2>&1
    reg add "HKCU\Control Panel\Desktop" /v ScreenSaveActive /t REG_SZ /d "0" /f >nul
  )
)

echo Removed MRXScreenSaver from System32.
pause
