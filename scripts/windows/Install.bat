@echo off
setlocal
title MRX ScreenSaver Installer

echo.
echo  MRX ScreenSaver — Windows install
echo  =================================
echo.

set "SRC=%~dp0MRXScreenSaver.scr"
if not exist "%SRC%" (
  echo ERROR: MRXScreenSaver.scr not found next to this Install.bat
  echo Download MRXScreenSaver-Windows.zip from the GitHub release and unzip first.
  pause
  exit /b 1
)

set "DEST=%SystemRoot%\System32\MRXScreenSaver.scr"
echo Copying to %DEST% ...
copy /Y "%SRC%" "%DEST%" >nul
if errorlevel 1 (
  echo.
  echo Copy to System32 failed — trying user folder instead...
  set "DEST=%LOCALAPPDATA%\MRXScreenSaver.scr"
  copy /Y "%SRC%" "%DEST%" >nul
)

echo.
echo Installed: %DEST%
echo.
echo Opening Screen Saver Settings...
echo   1. Choose "MRXScreenSaver" in the list
echo   2. Click Preview / Apply / OK
echo.
start "" rundll32.exe shell32.dll,Control_RunDLL desk.cpl,,1

echo Done.
pause
