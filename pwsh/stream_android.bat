@echo off
title SCRCPY Wireless Launcher
echo =====================================================
echo        Android Wireless Scrcpy Automation
echo =====================================================
echo.

REM === STEP 1: Check if device is connected via USB ===
:check_device
for /f "skip=1 tokens=1" %%a in ('adb devices') do (
    if "%%a"=="" goto no_device
    if NOT "%%a"=="List" (
        set DEVICE=%%a
        goto device_found
    )
)

:no_device
echo [!] No device detected.
echo Please connect your phone via USB with USB debugging enabled.
pause
goto check_device

:device_found
echo [+] Device detected: %DEVICE%
echo.

REM === STEP 2: Restart adb in TCP/IP mode ===
echo [+] Enabling TCP/IP mode on port 5555...
adb tcpip 5555
echo Waiting 2 seconds...
timeout /t 2 >nul

REM === STEP 3: Get phone's IPv4 address ===
echo [+] Fetching phone IP address...
for /f "tokens=2 delims= " %%i in ('adb shell ip -4 addr show wlan0 ^| findstr "inet "') do (
    for /f "tokens=1 delims=/" %%j in ("%%i") do set PHONE_IP=%%j
)
if "%PHONE_IP%"=="" (
    echo [!] Could not retrieve IP address. Make sure Wi-Fi is ON.
    pause
    exit /b
)
echo [+] Phone IP address detected: %PHONE_IP%
echo.

REM === STEP 4: Connect wirelessly ===
echo [+] Connecting to %PHONE_IP%:5555 ...
adb connect %PHONE_IP%:5555
echo Waiting 2 seconds...
timeout /t 2 >nul

REM === STEP 5: Launch scrcpy ===
echo [+] Launching scrcpy wirelessly...
scrcpy --capture-orientation=landscape

echo.
echo Done.
pause
exit /b
