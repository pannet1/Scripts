@echo off
setlocal enabledelayedexpansion

echo ==============================================
echo       Android Screen Streamer - scrcpy + adb
echo ==============================================
echo.

:: --- CHECK DEPENDENCIES ---
where adb 1>nul 2>&1
if errorlevel 1 (
    echo [ERROR] adb not found in PATH. Please install Android platform-tools.
    pause
    exit /b 1
)

where scrcpy 1>nul 2>&1
if errorlevel 1 (
    echo [ERROR] scrcpy not found in PATH. Please install scrcpy.
    pause
    exit /b 1
)

:: --- USB DEVICE CHECK ---
echo [INFO] Checking for connected Android devices...

:: Restart adb server to ensure fresh device list
adb kill-server 1>nul 2>&1
adb start-server 1>nul 2>&1

set "adb_devices_temp=%TEMP%\adb_devices.txt"
adb devices 1>"%adb_devices_temp%"

set "usb_device="
for /F "skip=1 tokens=1,2" %%A in ('type "%adb_devices_temp%"') do (
    if "%%B"=="device" set "usb_device=%%A"
)

del "%adb_devices_temp%" 1>nul 2>&1

if not defined usb_device (
    echo [WARN] No USB device detected.
    echo Please make sure:
    echo  1. USB cable is connected
    2. Developer options and USB debugging are enabled
    echo.
    choice /m "Try again after plugging in device?"
    if errorlevel 2 (
        echo Exiting.
        exit /b 1
    ) else (
        echo Rechecking for device...
        adb devices 1>"%adb_devices_temp%"
        for /F "skip=1 tokens=1,2" %%A in ('type "%adb_devices_temp%"') do (
            if "%%B"=="device" set "usb_device=%%A"
        )
        del "%adb_devices_temp%" 1>nul 2>&1
    )
)

:: --- USB CONNECTION ---
if defined usb_device (
    echo [INFO] USB device detected: %usb_device%
    echo [INFO] Starting scrcpy for USB device...
    scrcpy
    exit /b 0
)

:: --- WIFI CONNECTION (If USB failed) ---
echo Proceeding to try WiFi (TCP/IP) connection...

set /p "ip_address=Enter Android Device IP Address (e.g., 192.168.1.100): "

if "%ip_address%"=="" (
    echo [ERROR] IP address cannot be empty.
    pause
    exit /b 1
)

echo [INFO] Attempting to connect to %ip_address%:5555...

:: Enable adb over network on the device (requires initial USB connection or a rooted device)
adb tcpip 5555 1>nul 2>&1

:: Connect to the device over WiFi
adb connect %ip_address%:5555
if errorlevel 1 (
    echo [ERROR] Failed to connect to %ip_address%:5555.
    echo Make sure TCP/IP is enabled on the device and it is on the same network.
    pause
    exit /b 1
)

echo [INFO] Successfully connected to %ip_address%:5555.
echo [INFO] Starting scrcpy for WiFi connection...

:: Start scrcpy using the connected device
scrcpy -s %ip_address%:5555 --capture-orientation=270 --max-size=1920 --video-bit-rate=64M --stay-awake --turn-screen-off

pause

