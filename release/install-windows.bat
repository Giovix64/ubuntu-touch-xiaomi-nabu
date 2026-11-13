@echo off
rem ===========================================================================
rem  Ubuntu Touch for Xiaomi Pad 5 (nabu) - installer for Windows 10 / 11
rem  Double-click this file. Everything needed is in this folder; "fastboot"
rem  is downloaded from Google automatically if it is missing.
rem  This script NEVER locks the bootloader.
rem ===========================================================================
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
title Ubuntu Touch installer - Xiaomi Pad 5
echo.
echo   +----------------------------------------------+
echo   ^|   Ubuntu Touch  -  Xiaomi Pad 5 (nabu)       ^|
echo   ^|   installer                                  ^|
echo   +----------------------------------------------+
echo   Note: this project was created in cooperation with an AI assistant.
echo   It is experimental: use it at your own risk.

echo.
echo [1/7] Getting ready
set "FASTBOOT="
if exist "platform-tools\fastboot.exe" set "FASTBOOT=%~dp0platform-tools\fastboot.exe"
if not defined FASTBOOT for %%X in (fastboot.exe) do if not "%%~$PATH:X"=="" set "FASTBOOT=%%~$PATH:X"
if not defined FASTBOOT (
    echo       fastboot not found: downloading the Android platform-tools from Google...
    curl.exe -fL -o platform-tools.zip "https://dl.google.com/android/repository/platform-tools-latest-windows.zip"
    if errorlevel 1 ( set "MSG=Download failed. Check your internet connection." & goto :fail )
    tar.exe -xf platform-tools.zip
    if errorlevel 1 ( set "MSG=Could not unpack platform-tools.zip" & goto :fail )
    del platform-tools.zip
    set "FASTBOOT=%~dp0platform-tools\fastboot.exe"
)
echo       OK  fastboot: %FASTBOOT%

echo       Checking the installer files (this can take a few minutes)...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$bad=0; Get-Content 'SHA256SUMS' | ForEach-Object { $h,$f = $_ -split '\s+',2; $f=$f.Trim(); if (-not (Test-Path $f)) { $bad=1 } elseif ((Get-FileHash -Algorithm SHA256 $f).Hash.ToLower() -ne $h.ToLower()) { $bad=1 } }; exit $bad"
if errorlevel 1 ( set "MSG=Some files are damaged or missing. Please download and unpack the installer again." & goto :fail )
echo       OK  all files are intact

echo.
echo [2/7] Connecting to the tablet
"%FASTBOOT%" devices 2>nul | find "fastboot" >nul
if errorlevel 1 (
    echo.
    echo       Put the tablet in FASTBOOT mode:
    echo         1. Turn the tablet off.
    echo         2. Hold Volume Down + Power until you see the FASTBOOT screen.
    echo         3. Connect it to this computer with the USB cable.
    echo.
    echo       Waiting for the tablet...
    echo       ^(If it is never found, Windows needs the fastboot USB driver: see GUIDE.txt^)
)
:waitdev
"%FASTBOOT%" devices 2>nul | find "fastboot" >nul
if errorlevel 1 ( timeout /t 1 /nobreak >nul & goto :waitdev )

"%FASTBOOT%" getvar product 2>&1 | findstr /b /c:"product: nabu" >nul
if errorlevel 1 ( set "MSG=This is not a Xiaomi Pad 5. Nothing was changed." & goto :fail )
echo       OK  Xiaomi Pad 5 found
"%FASTBOOT%" getvar is-userspace 2>&1 | findstr /b /c:"is-userspace: yes" >nul
if not errorlevel 1 (
    echo       The tablet is in fastbootd: going back to the bootloader...
    "%FASTBOOT%" reboot bootloader >nul 2>&1
    call :waitmode no
    if errorlevel 1 ( set "MSG=The tablet did not come back in fastboot mode." & goto :fail )
)
"%FASTBOOT%" getvar unlocked 2>&1 | findstr /b /c:"unlocked: yes" >nul
if errorlevel 1 ( set "MSG=The bootloader is locked. Unlock it first with Xiaomi's Mi Unlock tool. Nothing was changed." & goto :fail )
echo       OK  bootloader is unlocked
set "SLOT="
for /f "tokens=2" %%S in ('""%FASTBOOT%" getvar current-slot 2>&1 | findstr /b /c:"current-slot:""') do set "SLOT=%%S"
if /i not "%SLOT%"=="a" if /i not "%SLOT%"=="b" ( set "MSG=Could not read the active slot. Nothing was changed." & goto :fail )
echo       OK  active slot: %SLOT%

echo.
echo   WARNING: this ERASES EVERYTHING on the tablet (photos, apps, accounts).
echo   The tablet must currently run a STOCK HyperOS or MIUI 13/14 (see GUIDE.txt).
echo.
set "ANS="
set /p "ANS=      Type YES to continue: "
if not "%ANS%"=="YES" ( set "MSG=Cancelled. Nothing was changed." & goto :fail )

if /i "%~1"=="reinstall" ( echo. & echo [3/7] Skipping the hardware drivers ^(reinstall^) & goto :aftervendor )
echo.
echo [3/7] Installing the hardware drivers (vendor)
echo       Switching the tablet to fastbootd (the screen changes: this is normal)...
"%FASTBOOT%" reboot fastboot >nul 2>&1
call :waitmode yes
if errorlevel 1 ( set "MSG=The tablet did not enter fastbootd. If it started Ubuntu Touch instead, this port is already installed: put it back in FASTBOOT mode and run: install-windows.bat reinstall   Otherwise flash the stock HyperOS first. Nothing was changed." & goto :fail )
call :flashall vendor_%SLOT% vendor || goto :fail
call :flashall odm_%SLOT% odm || goto :fail
echo       OK  vendor and odm installed
echo       Going back to the bootloader...
"%FASTBOOT%" reboot bootloader >nul 2>&1
call :waitmode no
if errorlevel 1 ( set "MSG=The tablet did not come back to the bootloader. Put it in FASTBOOT mode and run the installer again." & goto :fail )

:aftervendor
echo.
echo [4/7] Installing the verification data (vbmeta)
call :flashone vbmeta_%SLOT% images\vbmeta.img || goto :fail
call :flashone vbmeta_system_%SLOT% images\vbmeta_system.img || goto :fail
echo       OK  vbmeta installed

echo.
echo [5/7] Installing the Ubuntu Touch kernel
call :flashone boot_%SLOT% images\boot.img || goto :fail
call :flashone vendor_boot_%SLOT% images\vendor_boot.img || goto :fail
call :flashone dtbo_%SLOT% images\dtbo.img || goto :fail
echo       OK  boot, vendor_boot and dtbo installed

echo.
echo [6/7] Installing the Ubuntu Touch system (the longest step: 5-10 minutes)
"%FASTBOOT%" erase userdata >nul 2>&1
if errorlevel 1 ( set "MSG=Erasing userdata failed." & goto :fail )
call :flashall userdata userdata || goto :fail
echo       OK  system installed

echo.
echo [7/7] Finishing
"%FASTBOOT%" getvar unlocked 2>&1 | findstr /b /c:"unlocked: yes" >nul && echo       OK  bootloader still unlocked
"%FASTBOOT%" reboot >nul 2>&1
echo.
echo   All done!
echo   The tablet is restarting. The first start takes 1-2 minutes: you will see
echo   the Mi logo and then the Ubuntu Touch welcome screen.
echo.
pause
exit /b 0

:flashone
"%FASTBOOT%" flash %1 "%~2" >.fastboot.log 2>&1
if errorlevel 1 ( type .fastboot.log & set "MSG=Flashing %1 failed." & exit /b 1 )
exit /b 0

:flashall
set /a N=0
for /f "delims=" %%F in ('dir /b /on "images\%2.??.img" 2^>nul') do (
    set /a N+=1
    echo       %1: part !N!
    "%FASTBOOT%" flash %1 "images\%%F" >.fastboot.log 2>&1
    if errorlevel 1 ( type .fastboot.log & set "MSG=Flashing %1 failed." & exit /b 1 )
)
if !N! equ 0 ( set "MSG=Missing files: images\%2.NN.img" & exit /b 1 )
exit /b 0

:waitmode
rem waitmode yes = wait for fastbootd, waitmode no = wait for the bootloader
set /a TRIES=0
:waitmode_loop
set /a TRIES+=1
if %TRIES% gtr 90 exit /b 1
timeout /t 2 /nobreak >nul
"%FASTBOOT%" devices 2>nul | find "fastboot" >nul
if errorlevel 1 goto :waitmode_loop
"%FASTBOOT%" getvar is-userspace 2>&1 | findstr /b /c:"is-userspace: yes" >nul
if "%1"=="yes" ( if errorlevel 1 goto :waitmode_loop ) else ( if not errorlevel 1 goto :waitmode_loop )
exit /b 0

:fail
echo.
echo   ERROR: %MSG%
echo.
pause
exit /b 1
