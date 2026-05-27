param(
    [switch]$Force
)

$ScriptDir = Split-Path -Parent $PSCommandPath
$ToolsDir  = Join-Path $ScriptDir "tools"

$IsWin = [Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT

function Test-Command($Name) {
    Get-Command $Name -ErrorAction SilentlyContinue
}

function Get-AdbDir {
    $dir = Join-Path $ToolsDir "platform-tools"
    if (Test-Path $dir) { return $dir }
    return $null
}

function Get-ScrcpyDir {
    $dir = Join-Path $ToolsDir "scrcpy"
    if (Test-Path $dir) { return $dir }
    return $null
}

function Add-ToPath {
    param($Dir)
    if ($Dir -and (Test-Path $Dir) -and $env:Path -notlike "*$Dir*") {
        $env:Path = "$Dir;$env:Path"
    }
}

# --- adb ---------------------------------------------------------------
if (-not (Test-Command adb) -or $Force) {
    $adDir = Get-AdbDir
    if ($adDir -and -not $Force) {
        Add-ToPath $adDir
    } else {
        Write-Host "[adb] not found. Downloading Android platform-tools..." -ForegroundColor Yellow
        $adUrl = if ($IsWin) {
            "https://dl.google.com/android/repository/platform-tools-latest-windows.zip"
        } elseif ($IsLinux) {
            "https://dl.google.com/android/repository/platform-tools-latest-linux.tar.gz"
        } else {
            "https://dl.google.com/android/repository/platform-tools-latest-darwin.zip"
        }
        $adDest = Join-Path $ToolsDir "platform-tools-dl.zip"
        $null = New-Item -ItemType Directory -Path $ToolsDir -Force
        Write-Host "  Downloading platform-tools ..." -NoNewline
        try {
            Invoke-WebRequest -Uri $adUrl -OutFile $adDest -UseBasicParsing -ErrorAction Stop
            Write-Host " OK" -ForegroundColor Green
        } catch {
            Write-Host " FAILED" -ForegroundColor Red
            Write-Host "  $_" -ForegroundColor Red
            exit 1
        }
        Write-Host "  Extracting ..." -NoNewline
        try {
            if ($adUrl.EndsWith('.tar.gz')) {
                tar -xzf $adDest -C $ToolsDir 2>&1 | Out-Null
            } else {
                Expand-Archive -Path $adDest -DestinationPath $ToolsDir -Force
            }
            Remove-Item $adDest -Force
            Write-Host " OK" -ForegroundColor Green
        } catch {
            Write-Host " FAILED" -ForegroundColor Red
            Write-Host "  $_" -ForegroundColor Red
            exit 1
        }
        $adDir = Get-AdbDir
        Add-ToPath $adDir
    }
}

# --- scrcpy ------------------------------------------------------------
if (-not (Test-Command scrcpy) -or $Force) {
    $scDir = Get-ScrcpyDir
    if ($scDir -and -not $Force) {
        Add-ToPath $scDir
    } else {
        Write-Host "[scrcpy] not found. Downloading..." -ForegroundColor Yellow
        Write-Host "  Fetching latest release info ..." -NoNewline
        try {
            $rel = Invoke-RestMethod -Uri "https://api.github.com/repos/Genymobile/scrcpy/releases/latest" -UseBasicParsing -ErrorAction Stop
            $ver = $rel.tag_name -replace '^v'
            Write-Host " v$ver" -ForegroundColor Green
        } catch {
            Write-Host " FAILED" -ForegroundColor Red
            Write-Host "  $_" -ForegroundColor Red
            exit 1
        }
        $scUrl = if ($IsWin) {
            "https://github.com/Genymobile/scrcpy/releases/download/v$ver/scrcpy-win64-v$ver.zip"
        } elseif ($IsLinux) {
            "https://github.com/Genymobile/scrcpy/releases/download/v$ver/scrcpy-v$ver.tar.gz"
        } else {
            "https://github.com/Genymobile/scrcpy/releases/download/v$ver/scrcpy-macos-v$ver.tar.gz"
        }
        $scDest = Join-Path $ToolsDir "scrcpy-dl.zip"
        Write-Host "  Downloading scrcpy ..." -NoNewline
        try {
            Invoke-WebRequest -Uri $scUrl -OutFile $scDest -UseBasicParsing -ErrorAction Stop
            Write-Host " OK" -ForegroundColor Green
        } catch {
            Write-Host " FAILED" -ForegroundColor Red
            Write-Host "  $_" -ForegroundColor Red
            exit 1
        }
        Write-Host "  Extracting ..." -NoNewline
        try {
            if ($scUrl.EndsWith('.tar.gz')) {
                $scDir = Join-Path $ToolsDir "scrcpy-tmp"
                $null = New-Item -ItemType Directory -Path $scDir -Force
                tar -xzf $scDest -C $scDir 2>&1 | Out-Null
                $inner = Get-ChildItem $scDir -Directory | Select-Object -First 1
                if ($inner) {
                    $scDirFinal = Join-Path $ToolsDir "scrcpy"
                    Remove-Item $scDirFinal -Recurse -Force -ErrorAction SilentlyContinue
                    Move-Item $inner.FullName $scDirFinal
                    Remove-Item $scDir -Recurse -Force -ErrorAction SilentlyContinue
                }
            } else {
                Expand-Archive -Path $scDest -DestinationPath $ToolsDir -Force
                $scDirRel = Join-Path $ToolsDir "scrcpy-win64-v$ver"
                $scDirFinal = Join-Path $ToolsDir "scrcpy"
                if (Test-Path $scDirRel) {
                    Remove-Item $scDirFinal -Recurse -Force -ErrorAction SilentlyContinue
                    Rename-Item $scDirRel $scDirFinal
                } else {
                    $scDirFinal = $ToolsDir
                }
            }
            Remove-Item $scDest -Force
            Write-Host " OK" -ForegroundColor Green
        } catch {
            Write-Host " FAILED" -ForegroundColor Red
            Write-Host "  $_" -ForegroundColor Red
            exit 1
        }
        $scDir = Get-ScrcpyDir
        Add-ToPath $scDir
    }
}

# --- Verify tools are now available ---
if (-not (Test-Command adb)) {
    Write-Host "[ERROR] adb still not available after install attempt." -ForegroundColor Red
    exit 1
}
if (-not (Test-Command scrcpy)) {
    Write-Host "[ERROR] scrcpy still not available after install attempt." -ForegroundColor Red
    exit 1
}

Write-Host "==============================================" -ForegroundColor Cyan
Write-Host "      Android Screen Streamer - scrcpy + adb" -ForegroundColor Cyan
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host ""

# --- USB device check ---
Write-Host "[INFO] Checking for connected Android devices..." -ForegroundColor Cyan

adb kill-server 2>&1 | Out-Null
adb start-server 2>&1 | Out-Null

$usbDevice = $null
foreach ($line in (adb devices | Select-Object -Skip 1)) {
    if ($line -match '(\S+)\s+device$') {
        $usbDevice = $matches[1]
    }
}

if (-not $usbDevice) {
    Write-Host "[WARN] No USB device detected." -ForegroundColor Yellow
    Write-Host "  Please ensure:" -ForegroundColor Yellow
    Write-Host "  1. USB cable is connected" -ForegroundColor Yellow
    Write-Host "  2. Developer options and USB debugging are enabled" -ForegroundColor Yellow
    Write-Host ""
    $retry = $host.UI.PromptForChoice("Retry?", "Try again after plugging in device?", @("&Yes", "&No"), 1)
    if ($retry -eq 0) {
        Write-Host "[INFO] Rechecking..." -ForegroundColor Cyan
        $usbDevice = $null
        foreach ($line in (adb devices | Select-Object -Skip 1)) {
            if ($line -match '(\S+)\s+device$') {
                $usbDevice = $matches[1]
            }
        }
        if (-not $usbDevice) {
            Write-Host "[ERROR] No device found. Exiting." -ForegroundColor Red
            exit 1
        }
    } else {
        exit 1
    }
}

# --- USB path ---
if ($usbDevice) {
    Write-Host "[INFO] USB device detected: $usbDevice" -ForegroundColor Green
    Write-Host "[INFO] Starting scrcpy for USB device..." -ForegroundColor Cyan
    scrcpy
    exit 0
}

# --- WiFi fallback ---
Write-Host "Proceeding to try WiFi (TCP/IP) connection..." -ForegroundColor Cyan
$ipAddress = Read-Host "Enter Android device IP address (e.g., 192.168.1.100)"

if ([string]::IsNullOrWhiteSpace($ipAddress)) {
    Write-Host "[ERROR] IP address cannot be empty." -ForegroundColor Red
    exit 1
}

Write-Host "[INFO] Attempting to connect to ${ipAddress}:5555..." -ForegroundColor Cyan

adb tcpip 5555 2>&1 | Out-Null
$conn = adb connect "${ipAddress}:5555" 2>&1
if ($LASTEXITCODE -ne 0 -or $conn -match 'failed') {
    Write-Host "[ERROR] Failed to connect to ${ipAddress}:5555." -ForegroundColor Red
    Write-Host "  Make sure TCP/IP is enabled on the device and it is on the same network." -ForegroundColor Red
    exit 1
}

Write-Host "[INFO] Successfully connected to ${ipAddress}:5555." -ForegroundColor Green
Write-Host "[INFO] Starting scrcpy for WiFi connection..." -ForegroundColor Cyan
scrcpy -s "${ipAddress}:5555" --capture-orientation=270 --max-size=1920 --video-bit-rate=64M --stay-awake --turn-screen-off
