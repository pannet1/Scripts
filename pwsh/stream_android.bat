echo ==============================================
echo     Android Screen Streamer - scrcpy + adb
echo ==============================================
echo.

:: === STEP 1: Check for ADB and scrcpy availability ===
where adb >nul 2>&1
if errorlevel 1 (
    echo [ERROR] adb not found in PATH. Please install Android platform-tools.
    pause
    exit /b
)

where scrcpy >nul 2>&1
if errorlevel 1 (
    echo [ERROR] scrcpy not found in PATH. Please install scrcpy.
    pause
    exit /b
)

:: === STEP 2: Check for USB device ===
echo [INFO] Checking for connected Android devices...
adb kill-server >nul 2>&1
adb start-server >nul 2>&1
adb devices > "%temp%\adb_devices.txt"

set "usb_device="
for /f "skip=1 tokens=1,2" %%A in ('type "%temp%\adb_devices.txt"') do (
    if "%%B"=="device" set "usb_device=%%A"
)

if not defined usb_device (
    echo [WARN] No USB device detected.
    echo Please make sure:
    echo  1. USB cable is connected
    echo  2. Developer options and USB debugging are enabled
    echo.
    choice /m "Try again after plugging in device?"
    if errorlevel 2 (
        echo Exiting.
        exit /b
    ) else (
        echo Rechecking for device...
        adb devices > "%temp%\adb_devices.txt"
        for /f "skip=1 tokens=1,2" %%A in ('type "%temp%\adb_devices.txt"') do (
            if "%%B"=="device" set "usb_device=%%A"
        )
    )
)

if defined usb_device (
    echo [OK] USB device detected: %usb_device%
    goto USB_CONNECTED
) else (
    echo [WARN] Still no USB device detected.
    echo Proceeding to try WiFi (TCP/IP) connection...
    goto TRY_TCPIP
)

:USB_CONNECTED
echo.
echo [ACTION] Launching scrcpy via USB...
scrcpy --capture-orientation=270 --max-size=1920 --video-bit-rate=16M --stay-awake --turn-screen-off
goto END

:TRY_TCPIP
:: === STEP 3: Enable TCP/IP mode on port 5555 ===
echo [ACTION] Enabling ADB TCP/IP on port 5555...
adb tcpip 5555
timeout /t 2 /nobreak >nul

:: === STEP 4: Get device Wi-Fi IPv4 ===
echo [INFO] Trying to detect device IP address...
set "PHONE_IP="
for /f "tokens=2" %%A in ('adb shell ip -4 addr show wlan0 ^| findstr "inet "') do (
    for /f "tokens=1 delims=/" %%B in ("%%A") do set "PHONE_IP=%%B"
)

if not defined PHONE_IP (
    echo [ERROR] Could not detect IP address automatically.
    echo Please check phone WiFi connection or enter manually.
    set /p PHONE_IP="Enter device IP manually: "
)

if not defined PHONE_IP (
    echo [FATAL] No IP provided. Cannot continue.
    pause
    exit /b
)

echo [OK] Device IP: %PHONE_IP%

:: === STEP 5: Connect wirelessly ===
echo [ACTION] Connecting to %PHONE_IP%:5555 ...
adb connect %PHONE_IP%:5555
if errorlevel 1 (
    echo [ERROR] Failed to connect to %PHONE_IP%:5555
    pause
    exit /b
)

:: === STEP 6: Launch scrcpy wirelessly ===
echo.
echo [ACTION] Launching scrcpy wirelessly...
scrcpy --capture-orientation=270 --max-size=1920 --video-bit-rate=16M --stay-awake --turn-screen-off

:END
echo.
echo ==============================================
echo   Streaming session ended.
echo ==============================================
pause


