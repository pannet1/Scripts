#!/bin/bash
set -euo pipefail

# Ensure standard user paths are in PATH
export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"

ok()    { echo "  $1 ✓"; }
fail()  { echo "  $1 ✗"; }
fix()   { echo "  → $1"; }

is_wsl() {
  grep -qi microsoft /proc/version 2>/dev/null || [ -n "${WSL_DISTRO_NAME:-}" ]
}

show_help() {
  echo "Usage: $(basename "$0") [filename] [options] [scrcpy-options]"
  echo ""
  echo "Mirrors Android screen live in 16:9 (YouTube ratio) and records to MKV by default."
  echo "Filename is optional — defaults to a timestamped file."
  echo ""
  echo "Options:"
  echo "  [filename]          Custom output file (default: recording_<timestamp>.mkv)"
  echo "  -r, --record [file] Optional explicit recording flag (enabled by default)"
  echo "  --no-record, -nr    Disable recording (live streaming only)"
  echo "  --full              Use full screen without 16:9 crop"
  echo "  -b, --background    Run scrcpy in the background (native Linux mode)"
  echo "  --wsl               Force WSL2 mode (Windows ADB / scrcpy via PowerShell)"
  echo "  --native            Force native Linux mode (Debian ADB / scrcpy)"
  echo "  -h, --help          Show this help message"
  echo ""
  echo "Any additional options are forwarded directly to scrcpy."
  echo ""
  echo "Examples:"
  echo "  $(basename "$0")                          # Stream in 16:9 + record (auto-named timestamp)"
  echo "  $(basename "$0") my_video                 # Stream in 16:9 + record to my_video.mkv"
  echo "  $(basename "$0") my_video.mkv             # Stream in 16:9 + record to my_video.mkv"
  echo "  $(basename "$0") --no-record              # Stream only (no video saved)"
  echo "  $(basename "$0") --full                   # Record in full 20:9 phone ratio"
}

ARGS=()
HAS_ORIENTATION=false
HAS_CROP=false
FULL_RATIO=false
BG_MODE=false
FORCE_MODE=""
RECORD=true
RECORD_FILE=""

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help)
      show_help
      exit 0
      ;;
    -b|--background)
      BG_MODE=true
      shift
      ;;
    --full|--no-crop)
      FULL_RATIO=true
      shift
      ;;
    --wsl)
      FORCE_MODE="wsl"
      shift
      ;;
    --native)
      FORCE_MODE="native"
      shift
      ;;
    --no-record|--no-rec|-nr)
      RECORD=false
      RECORD_FILE=""
      shift
      ;;
    -r|--record)
      RECORD=true
      if [ $# -gt 1 ] && [[ "$2" != -* ]]; then
        RECORD_FILE="$2"
        shift 2
      else
        shift 1
      fi
      ;;
    --record=*)
      RECORD=true
      RECORD_FILE="${1#*=}"
      shift
      ;;
    --crop*)
      HAS_CROP=true
      ARGS+=("$1")
      shift
      ;;
    --capture-orientation*|--orientation*|--display-orientation*|--record-orientation*)
      HAS_ORIENTATION=true
      ARGS+=("$1")
      shift
      ;;
    -*)
      ARGS+=("$1")
      shift
      ;;
    *)
      # Positional argument without leading dash is treated as custom record filename
      if [ -z "$RECORD_FILE" ] && [ "$RECORD" = true ]; then
        RECORD_FILE="$1"
      else
        ARGS+=("$1")
      fi
      shift
      ;;
  esac
done

if [ "$RECORD" = true ]; then
  if [ -z "$RECORD_FILE" ]; then
    RECORD_FILE="recording_$(date +%Y%m%d_%H%M%S).mkv"
  elif [[ "$RECORD_FILE" != *.* ]]; then
    RECORD_FILE="${RECORD_FILE}.mkv"
  fi
fi

if [ "$HAS_ORIENTATION" = false ]; then
  ARGS+=("--capture-orientation=270")
fi

# Detect operating system mode
if [ "$FORCE_MODE" = "wsl" ]; then
  MODE="wsl"
elif [ "$FORCE_MODE" = "native" ]; then
  MODE="native"
elif is_wsl && command -v powershell.exe &>/dev/null; then
  MODE="wsl"
else
  MODE="native"
fi

get_16_9_crop() {
  local size_line
  size_line=$(adb shell wm size 2>/dev/null | grep -E "(Override size|Physical size)" | tail -1 | awk '{print $NF}' | tr -d '\r')
  if [[ "$size_line" =~ ^([0-9]+)x([0-9]+)$ ]]; then
    local w="${BASH_REMATCH[1]}"
    local h="${BASH_REMATCH[2]}"
    if [ "$w" -gt "$h" ]; then
      local tmp="$w"; w="$h"; h="$tmp"
    fi
    local target_h=$(( w * 16 / 9 ))
    if [ "$target_h" -le "$h" ]; then
      local offset_y=$(( (h - target_h) / 2 ))
      echo "${w}:${target_h}:0:${offset_y}"
      return
    fi
  fi
  echo "1080:1920:0:240"
}

get_wsl_16_9_crop() {
  local size_line
  size_line=$(powershell.exe -Command "& '$ADB_WIN_PATH' shell wm size" 2>/dev/null | grep -E "(Override size|Physical size)" | tail -1 | awk '{print $NF}' | tr -d '\r')
  if [[ "$size_line" =~ ^([0-9]+)x([0-9]+)$ ]]; then
    local w="${BASH_REMATCH[1]}"
    local h="${BASH_REMATCH[2]}"
    if [ "$w" -gt "$h" ]; then
      local tmp="$w"; w="$h"; h="$tmp"
    fi
    local target_h=$(( w * 16 / 9 ))
    if [ "$target_h" -le "$h" ]; then
      local offset_y=$(( (h - target_h) / 2 ))
      echo "${w}:${target_h}:0:${offset_y}"
      return
    fi
  fi
  echo "1080:1920:0:240"
}

run_wsl() {
  echo "=============================================="
  echo "  scrcpy — Android Screen Mirror (WSL2)"
  echo "=============================================="

  if ! command -v powershell.exe &>/dev/null; then
    fail "powershell.exe not found"
    echo "  Not running in WSL with interop enabled, or powershell.exe is missing."
    echo "  Run with --native for native Linux mode, or check /etc/wsl.conf."
    exit 1
  fi

  FIND_SCRCPY='$cmd = Get-Command scrcpy.exe -ErrorAction SilentlyContinue
if ($cmd) { Write-Output $cmd.Source; exit }
$base = "$env:LOCALAPPDATA\Microsoft\WinGet\Packages"
$pat = "Genymobile.scrcpy*"
$dir = Get-ChildItem -Path $base -Filter $pat -Name -ErrorAction SilentlyContinue | Select-Object -First 1
if ($dir) {
    $exe = Get-ChildItem -Path "$base\$dir" -Recurse -Filter "scrcpy.exe" -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
    Write-Output $exe
}'

  FIND_ADB='$cmd = Get-Command adb.exe -ErrorAction SilentlyContinue
if ($cmd) { Write-Output $cmd.Source; exit }
$base = "$env:LOCALAPPDATA\Microsoft\WinGet\Packages"
$pat = "Google.PlatformTools*"
$dir = Get-ChildItem -Path $base -Filter $pat -Name -ErrorAction SilentlyContinue | Select-Object -First 1
if ($dir) {
    $exe = Get-ChildItem -Path "$base\$dir" -Recurse -Filter "adb.exe" -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
    if ($exe) { Write-Output $exe; exit }
    Write-Output "$base\$dir\platform-tools\adb.exe"
} else { Write-Output "" }'

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
  DEVICES=$(powershell.exe -Command "& '$ADB_WIN_PATH' devices" 2>/dev/null | grep -v 'List of devices attached' | grep -v '^[[:space:]]*$' | wc -l) || true
  echo "  $DEVICES device(s) found"

  if [ "$DEVICES" -eq 0 ]; then
    fail "no device connected"
    echo ""
    echo "  Connect your phone via USB and enable USB debugging."
    echo "  Then run again, or verify with:"
    echo "    $ADB_WIN_PATH devices"
    exit 1
  fi

  # Apply 16:9 crop if not disabled
  if [ "$FULL_RATIO" = false ] && [ "$HAS_CROP" = false ]; then
    CROP_VAL=$(get_wsl_16_9_crop)
    ARGS+=("--crop=$CROP_VAL")
    echo "  16:9 crop enabled ($CROP_VAL)"
  fi

  if [ "$RECORD" = true ] && [ -n "$RECORD_FILE" ]; then
    ARGS+=("--record=$RECORD_FILE" "--record-format=mkv")
  fi

  # ── 4. Launch scrcpy ──
  echo ""
  if [ "$RECORD" = true ] && [ -n "$RECORD_FILE" ]; then
    fix "recording to $RECORD_FILE (MKV)..."
  fi
  fix "launching scrcpy live stream..."
  SCRCPY_ARGS="${ARGS[*]}"
  powershell.exe -Command "Start-Process -FilePath '$SCRCPY_PATH' -ArgumentList '$SCRCPY_ARGS' -WindowStyle Normal" 2>/dev/null
  ok "scrcpy launched"
  if [ "$RECORD" = true ] && [ -n "$RECORD_FILE" ]; then
    echo "  Recording will save to: $RECORD_FILE on Windows"
  fi
}

run_native() {
  echo "=============================================="
  echo "  scrcpy — Android Screen Mirror (Debian)"
  echo "=============================================="

  # ── 1. Check scrcpy ──
  if ! command -v scrcpy &>/dev/null; then
    fail "scrcpy not found"
    fix "attempting install via apt..."
    if sudo apt-get update && sudo apt-get install -y scrcpy 2>/dev/null; then
      ok "scrcpy installed"
    else
      fix "not in apt repos, installing from official GitHub release..."
      SCRCPY_VERSION="v5.0.1"
      SCRCPY_TARBALL="scrcpy-linux-x86_64-${SCRCPY_VERSION}.tar.gz"
      SCRCPY_URL="https://github.com/Genymobile/scrcpy/releases/download/${SCRCPY_VERSION}/${SCRCPY_TARBALL}"
      tmpdir="$(mktemp -d)"
      if sudo apt-get install -y ffmpeg libsdl3-0 libusb-1.0-0 va-driver-all 2>/dev/null && \
         curl -fsSL "$SCRCPY_URL" -o "$tmpdir/scrcpy.tar.gz" && \
         tar -xzf "$tmpdir/scrcpy.tar.gz" -C "$tmpdir"; then
        SCRCPY_BIN="$(find "$tmpdir" -name scrcpy -type f -executable | head -1)"
        SCRCPY_SERVER="$(find "$tmpdir" -name scrcpy-server -type f | head -1)"
        if [ -n "$SCRCPY_BIN" ] && [ -n "$SCRCPY_SERVER" ]; then
          mkdir -p "$HOME/.local/bin" "$HOME/.local/share/scrcpy"
          install -m 0755 "$SCRCPY_BIN" "$HOME/.local/bin/scrcpy"
          install -m 0644 "$SCRCPY_SERVER" "$HOME/.local/bin/scrcpy-server"
          install -m 0644 "$SCRCPY_SERVER" "$HOME/.local/share/scrcpy/scrcpy-server"
          ok "scrcpy installed to ~/.local/bin"
        else
          fail "scrcpy binaries not found in release archive"
          rm -rf "$tmpdir"
          exit 1
        fi
        rm -rf "$tmpdir"
      else
        rm -rf "$tmpdir"
        fail "scrcpy installation failed"
        fix "Install manually: download from https://github.com/Genymobile/scrcpy/releases"
        exit 1
      fi
    fi
  else
    ok "scrcpy found"
  fi

  # Locate scrcpy-server if needed
  if [ -z "${SCRCPY_SERVER_PATH:-}" ]; then
    if [ -f "$HOME/.local/share/scrcpy/scrcpy-server" ]; then
      export SCRCPY_SERVER_PATH="$HOME/.local/share/scrcpy/scrcpy-server"
    elif [ -f "$HOME/.local/bin/scrcpy-server" ]; then
      export SCRCPY_SERVER_PATH="$HOME/.local/bin/scrcpy-server"
    elif [ -f "/usr/local/share/scrcpy/scrcpy-server" ]; then
      export SCRCPY_SERVER_PATH="/usr/local/share/scrcpy/scrcpy-server"
    elif [ -f "/usr/share/scrcpy/scrcpy-server" ]; then
      export SCRCPY_SERVER_PATH="/usr/share/scrcpy/scrcpy-server"
    fi
  fi

  # ── 2. Check ADB ──
  if ! command -v adb &>/dev/null; then
    fail "ADB not found"
    fix "installing via apt..."
    if sudo apt-get update && sudo apt-get install -y adb; then
      ok "ADB installed"
    else
      fail "apt install failed"
      fix "Install manually: sudo apt install adb"
      exit 1
    fi
  else
    ok "ADB available"
  fi

  # ── 3. Check device (auto-starts ADB server) ──
  fix "checking for devices..."
  adb start-server &>/dev/null || true
  RAW_DEVICES=$(adb devices 2>/dev/null | grep -v 'List of devices attached' | grep -v '^[[:space:]]*$' || true)
  DEVICES=0
  if [ -n "$RAW_DEVICES" ]; then
    DEVICES=$(echo "$RAW_DEVICES" | wc -l)
  fi
  echo "  $DEVICES device(s) found"

  if [ "$DEVICES" -eq 0 ]; then
    fail "no device connected"
    echo ""
    echo "  Connect your phone via USB and enable USB debugging."
    echo "  Then run again, or verify with:"
    echo "    adb devices"
    exit 1
  fi

  if echo "$RAW_DEVICES" | grep -q "unauthorized"; then
    fail "device is unauthorized"
    echo ""
    echo "  Check your phone screen and tap 'Allow' for USB debugging."
    exit 1
  fi

  if echo "$RAW_DEVICES" | grep -q "offline"; then
    fail "device is offline"
    echo ""
    echo "  Try reconnecting the USB cable or run: adb reconnect"
    exit 1
  fi

  # Apply 16:9 crop if not disabled
  if [ "$FULL_RATIO" = false ] && [ "$HAS_CROP" = false ]; then
    CROP_VAL=$(get_16_9_crop)
    ARGS+=("--crop=$CROP_VAL")
    echo "  16:9 crop enabled ($CROP_VAL)"
  fi

  if [ "$RECORD" = true ] && [ -n "$RECORD_FILE" ]; then
    ARGS+=("--record=$RECORD_FILE" "--record-format=mkv")
  fi

  # ── 4. Launch scrcpy ──
  echo ""
  if [ "$RECORD" = true ] && [ -n "$RECORD_FILE" ]; then
    fix "recording to $RECORD_FILE (MKV)..."
  fi
  fix "launching scrcpy live stream..."
  if [ "$BG_MODE" = true ]; then
    nohup scrcpy "${ARGS[@]}" &>/dev/null &
    ok "scrcpy launched in background (PID $!)"
  else
    ok "scrcpy streaming live"
    if [ "$RECORD" = true ] && [ -n "$RECORD_FILE" ]; then
      echo "  (Close the scrcpy window or press Ctrl+C to stop and save the MKV recording)"
    fi
    scrcpy "${ARGS[@]}" || true
    if [ "$RECORD" = true ] && [ -n "$RECORD_FILE" ] && [ -f "$RECORD_FILE" ]; then
      echo ""
      ok "recording saved to $(pwd)/$RECORD_FILE"
    fi
  fi
}

if [ "$MODE" = "wsl" ]; then
  run_wsl
else
  run_native
fi
