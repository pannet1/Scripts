echo off
title Stream Android Screen – USB first, then WiFi fallback
setlocal enabledelayedexpansion

echo ==============================================
echo   Android Screen Streaming Launcher
echo ==============================================
echo.

:: === Check if adb is available ===
where adb >nul 2>&1
if errorlevel 1 (
    echo [ERROR] adb not found in PATH. Please install Android platform-tools.
    pause
    exit /b
)

:: === STEP 1: Check for USB-connected device ===
echo [INFO] Checking for USB-connected Android device...
adb devices > "%temp%\adb_devices.txt"
findstr /R "^\s*[0-9A-Za-z]\{4,\}\s*device$" "%temp%\adb_devices.txt" >nul
if %errorlevel%==0 (
    echo [OK] USB device detected.
    goto LAUNCH_USB
) else (
    echo [WARN] No USB device detected.
    echo [INFO] Will try wireless (TCP/IP) mode.
    goto TRY_TCPIP
)

:LAUNCH_USB
echo.
echo [ACTION] Launching scrcpy via USB...
scrcpy --display-orientation=landscape --lock-video-orientation=landscape ^
       --max-size=1920 --bit-rate=16M --stay-awake --turn-screen-off
goto END

:TRY_TCPIP
:: === STEP 2: Enable TCP/IP on port 5555 ===
echo [ACTION] Enabling ADB TCP/IP on port 5555...
adb tcpip 5555
echo Waiting 2 seconds...
timeout /t 2 >nul

:: === STEP 3: Determine device WiFi IP address ===
echo [INFO] Fetching device WiFi IPv4 address...
for /f "tokens=2 delims= " %%A in ('adb shell ip -4 addr show wlan0 ^| findstr " inet "') do (
    for /f "tokens=1 delims=/" %%B in ("%%A") do set PHONE_IP=%%B
)
if "%PHONE_IP%"=="" (
    echo [ERROR] Could not determine IPv4 address. Make sure your phone’s WiFi is ON and connected to same network.
    pause
    exit /b
)
echo [OK] Device IP: %PHONE_IP%

:: === STEP 4: Connect via WiFi ===
echo [ACTION] Connecting to %PHONE_IP%:5555 ...
adb connect %PHONE_IP%:5555
if errorlevel 1 (
    echo [ERROR] Failed to connect to %PHONE_IP%:5555.
    pause
    exit /b
)

:: === STEP 5: Launch scrcpy wirelessly ===
echo.
echo [ACTION] Launching scrcpy wirelessly...
scrcpy --display-orientation=landscape --lock-video-orientation=landscape ^
       --max-size=1920 --bit-rate=16M --stay-awake --turn-screen-off

:END
echo.
echo Done.
pause

