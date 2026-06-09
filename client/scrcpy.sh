#!/bin/bash
set -euo pipefail

ok()    { echo "  $1 ✓"; }
fail()  { echo "  $1 ✗"; }
fix()   { echo "  → $1"; }

FIND_SCRCPY='$base = "$env:LOCALAPPDATA\Microsoft\WinGet\Packages"
$pat = "Genymobile.scrcpy*"
$dir = Get-ChildItem -Path $base -Filter $pat -Name | Select-Object -First 1
if ($dir) {
    $exe = Get-ChildItem -Path "$base\$dir" -Recurse -Filter "scrcpy.exe" | Select-Object -First 1 -ExpandProperty FullName
    Write-Output $exe
}'

FIND_ADB='$base = "$env:LOCALAPPDATA\Microsoft\WinGet\Packages"
$pat = "Google.PlatformTools*"
$dir = Get-ChildItem -Path $base -Filter $pat -Name | Select-Object -First 1
if ($dir) { Write-Output "$base\$dir\platform-tools\adb.exe" } else { Write-Output "" }'

echo "=============================================="
echo "  scrcpy — Android Screen Mirror (WSL2)"
echo "=============================================="

if ! command -v powershell.exe &>/dev/null; then
  echo "Not running in WSL (powershell.exe not found)."
  echo "scrcpy launches on Windows — run this from WSL2."
  exit 1
fi

# ── 1. Check scrcpy on Windows ──
SCRCPY_PATH=$(powershell.exe -Command "$FIND_SCRCPY" 2>/dev/null | tr -d '\r')
if [ -z "$SCRCPY_PATH" ]; then
  fail "scrcpy not found"
  fix "installing via winget..."
  if powershell.exe -Command "winget install Genymobile.scrcpy --accept-package-agreements --accept-source-agreements" 2>/dev/null; then
    SCRCPY_PATH=$(powershell.exe -Command "$FIND_SCRCPY" 2>/dev/null | tr -d '\r')
    ok "scrcpy installed"
  else
    fail "winget install failed"
    fix "Install manually: winget install Genymobile.scrcpy"
    exit 1
  fi
else
  ok "scrcpy found"
fi

# ── 2. Check ADB on Windows ──
ADB_WIN_PATH=$(powershell.exe -Command "$FIND_ADB" 2>/dev/null | tr -d '\r')
if [ -z "$ADB_WIN_PATH" ] || ! powershell.exe -Command "Test-Path '$ADB_WIN_PATH'" 2>/dev/null | grep -q True; then
  fail "ADB not found"
  fix "installing via winget..."
  if powershell.exe -Command "winget install Google.PlatformTools --accept-package-agreements --accept-source-agreements" 2>/dev/null; then
    ADB_WIN_PATH=$(powershell.exe -Command "$FIND_ADB" 2>/dev/null | tr -d '\r')
    ok "ADB installed"
  else
    fail "winget install failed"
    fix "Install manually: winget install Google.PlatformTools"
    exit 1
  fi
else
  ok "ADB available"
fi

# ── 3. Check device (auto-starts ADB server) ──
fix "checking for devices..."
DEVICES=$(powershell.exe -Command "& '$ADB_WIN_PATH' devices" 2>/dev/null | grep -v 'List of devices attached' | grep -v '^[[:space:]]*$' | wc -l)
echo "  $DEVICES device(s) found"

if [ "$DEVICES" -eq 0 ]; then
  fail "no device connected"
  echo ""
  echo "  Connect your phone via USB and enable USB debugging."
  echo "  Then run again, or verify with:"
  echo "    $ADB_WIN_PATH devices"
  exit 1
fi

# ── 4. Launch scrcpy ──
echo ""
fix "launching scrcpy..."
powershell.exe -Command "Start-Process -FilePath '$SCRCPY_PATH' -WindowStyle Normal" 2>/dev/null
ok "scrcpy launched"
