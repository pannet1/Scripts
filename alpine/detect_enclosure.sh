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

# ── 3. Detect enclosure block device ──
echo ""
echo "  [3/3] Scanning for enclosure block device..."
if [ ! -d /sys/block ]; then
    echo "  ✗ No block devices found"
    exit 1
fi

# Determine Alpine USB boot device so we can exclude it
ALPINE_USB=$(df /media/usb 2>/dev/null | awk 'NR==2 {print $1}' | sed 's/[0-9]*p\?[0-9]*$//')

ENCL_DEV=""
for dev in /sys/block/sd*; do
    [ -d "$dev" ] || continue
    DEVNAME=$(basename "$dev")
    DEVPATH="/dev/$DEVNAME"
    # Skip boot disk and Alpine USB
    [ "$DEVNAME" = "sda" ] && continue
    [ "$DEVPATH" = "$ALPINE_USB" ] && echo "  Skipping Alpine USB ($DEVPATH)" && continue
    # Check removable flag
    REMOVABLE=$(cat "$dev/removable" 2>/dev/null || echo 0)
    # Check if it's an external USB device via the driver
    DRV=$(readlink "$dev/device/driver" 2>/dev/null || echo "")
    case "$DRV" in
        *jmicron*|*usb*|*uas*)
            ENCL_DEV="$DEVPATH"
            ;;
    esac
done

if [ -z "$ENCL_DEV" ]; then
    # Fallback: find any removable non-boot block device
    for dev in /dev/sd?; do
        [ -b "$dev" ] || continue
        [ "$dev" = "/dev/sda" ] && continue
        [ "$dev" = "$ALPINE_USB" ] && continue
        ENCL_DEV="$dev"
        break
    done
fi

if [ -z "$ENCL_DEV" ]; then
    echo "  ✗ JD Micron enclosure not detected"
    echo ""
    echo "  Possible causes:"
    echo "    • Enclosure not plugged in"
    echo "    • USB cable faulty"
    echo "    • Power supply insufficient"
    echo "    • Driver mismatch"
    exit 1
fi

echo "  ✓ Enclosure detected: $ENCL_DEV"

MODEL=$(cat "/sys/block/$(basename "$ENCL_DEV")/device/model" 2>/dev/null | tr -d ' ')
[ -n "$MODEL" ] && echo "  Model: $MODEL"

echo ""
echo "═══════════════════════════════════════"
echo "$ENCL_DEV"
