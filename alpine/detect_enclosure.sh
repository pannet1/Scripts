#!/bin/sh

# detect_enclosure.sh — Detect and prepare JD Micron USB drive enclosure
# Called by welcome.sh option 2 before salvage_disk.sh
# Returns 0 and prints detected device path on success

echo "═══════════════════════════════════════"
echo "  JD MICRON ENCLOSURE — DETECTION"
echo "═══════════════════════════════════════"

# ── 1. Check / load kernel driver ──
echo ""
echo "  [1/3] Checking kernel driver..."
if modinfo jmicron >/dev/null 2>&1; then
    echo "  ✓ jmicron module available"
    DRIVER="jmicron"
elif modinfo jd_micron >/dev/null 2>&1; then
    echo "  ✓ jd_micron module available"
    DRIVER="jd_micron"
else
    echo "  ! Driver not found — installing..."
    SCRIPT_DIR=$(dirname "$0" 2>/dev/null)
    [ -z "$SCRIPT_DIR" ] && SCRIPT_DIR="/root/Scripts/alpine"
    "$SCRIPT_DIR/install_drivers.sh"
    if modinfo jmicron >/dev/null 2>&1; then
        DRIVER="jmicron"
    elif modinfo jd_micron >/dev/null 2>&1; then
        DRIVER="jd_micron"
    else
        echo "  ✗ Failed to install JD Micron driver"
        exit 1
    fi
fi

# ── 2. Load driver (if not already loaded) ──
echo ""
echo "  [2/3] Loading $DRIVER driver..."
if lsmod | grep -q "$DRIVER"; then
    echo "  ✓ $DRIVER already loaded"
else
    modprobe "$DRIVER" 2>/dev/null && sleep 1
    if lsmod | grep -q "$DRIVER"; then
        echo "  ✓ $DRIVER loaded"
    else
        echo "  ! Could not load $DRIVER (may be built-in kernel driver)"
        echo "  ! Device scan will still proceed"
    fi
fi

# ── 3. List candidate devices ──
echo ""
echo "  [3/3] Scanning for candidate devices..."

ALPINE_USB=$(df /media/usb 2>/dev/null | awk 'NR==2 {print $1}' | sed 's/[0-9]*p\?[0-9]*$//')

devices=""
for dev in /sys/block/sd*; do
    [ -d "$dev" ] || continue
    DEVNAME=$(basename "$dev")
    DEVPATH="/dev/$DEVNAME"
    [ "$DEVNAME" = "sda" ] && continue
    [ "$DEVPATH" = "$ALPINE_USB" ] && continue
    REMOVABLE=$(cat "$dev/removable" 2>/dev/null || echo 0)
    MODEL=$(cat "$dev/device/model" 2>/dev/null | tr -d ' ')
    [ -z "$MODEL" ] && MODEL="(unknown)"
    devices="$devices $DEVPATH|$MODEL"
done

if [ -z "$devices" ]; then
    echo "  ✗ No candidate devices found"
    echo "  Plug in the enclosure and try again."
    exit 1
fi

echo ""
echo "  Available devices:"
idx=1
for entry in $devices; do
    dev=$(echo "$entry" | cut -d'|' -f1)
    model=$(echo "$entry" | cut -d'|' -f2)
    size=$(blockdev --getsize64 "$dev" 2>/dev/null | awk '{printf "%.0f GB", $1/1073741824}')
    [ -z "$size" ] && size="? GB"
    echo "    $idx) $dev  —  $model  ($size)"
    idx=$((idx + 1))
done

echo ""
printf "  Select device number: "; read SEL </dev/tty

if ! echo "$SEL" | grep -q '^[0-9][0-9]*$'; then
    echo "  Invalid selection."
    exit 1
fi

idx=1
ENCL_DEV=""
for entry in $devices; do
    if [ "$idx" = "$SEL" ]; then
        ENCL_DEV=$(echo "$entry" | cut -d'|' -f1)
        break
    fi
    idx=$((idx + 1))
done

if [ -z "$ENCL_DEV" ]; then
    echo "  Invalid selection."
    exit 1
fi

echo ""
echo "  Selected: $ENCL_DEV"
echo ""
echo "═══════════════════════════════════════"
echo "$ENCL_DEV"
