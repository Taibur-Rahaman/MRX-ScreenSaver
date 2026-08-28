@echo off
setlocal EnableExtensions
title MRX ScreenSaver — Universal Installer

:: Delegate to the Windows installer in this package.
set "HERE=%~dp0"
if exist "%HERE%windows\Install.bat" (
  call "%HERE%windows\Install.bat"
  exit /b %errorlevel%
)
if exist "%HERE%Install.bat" (
  call "%HERE%Install.bat"
  exit /b %errorlevel%
)

echo.
echo  ERROR: Windows installer not found in this folder.
echo  Unzip MRXScreenSaver-Windows.zip completely.
echo.
pause
exit /b 1
