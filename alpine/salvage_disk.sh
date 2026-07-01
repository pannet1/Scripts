#!/bin/sh

# Hard Disk Salvage Triage — reuses run_test pattern from test_new.sh
# Usage:  ./salvage_disk.sh /dev/sdX
# Requires: smartmontools e2fsprogs util-linux (install_test.sh installs these)

LOGFILE="/media/usb/salvage_$(basename "$1")_$(date +%Y%m%d_%H%M).log"
DEVICE="$1"

# ── Tool check ──
MISSING=""
for cmd in smartctl badblocks blockdev; do
    command -v "$cmd" >/dev/null 2>&1 || MISSING="$MISSING $cmd"
done
[ -n "$MISSING" ] && { echo "Missing:$MISSING — run install_test.sh first"; exit 1; }
: "${DEVICE:?Usage: salvage_disk.sh /dev/sdX}"
[ -b "$DEVICE" ] || { echo "Not a block device: $DEVICE"; exit 1; }

# ── Safety: identify and exclude boot/system disks ──
BOOT_DEV=$(df / | awk 'NR==2 {print $1}' | sed 's/[0-9]*p\?[0-9]*$//')
USB_DEV=$(df /media/usb 2>/dev/null | awk 'NR==2 {print $1}' | sed 's/[0-9]*p\?[0-9]*$//')
TGT_SHORT=$(basename "$DEVICE")
REMOVABLE=$(cat "/sys/block/$TGT_SHORT/removable" 2>/dev/null || echo 0)

echo "DEVICE: $DEVICE"
echo "  Removable: $([ "$REMOVABLE" = "1" ] && echo 'YES (USB/eSATA)' || echo 'NO (internal bay)')"
echo "  Boot disk: $BOOT_DEV"
[ -n "$USB_DEV" ] && echo "  Alpine USB: $USB_DEV"

# Refuse to touch the running system
if echo "$DEVICE" | grep -q "^$BOOT_DEV" || [ "$DEVICE" = "$BOOT_DEV" ]; then
    echo "FATAL: $DEVICE is the system boot disk. Refusing." | tee -a "$LOGFILE"; exit 1
fi
if [ -n "$USB_DEV" ] && ( echo "$DEVICE" | grep -q "^$USB_DEV" || [ "$DEVICE" = "$USB_DEV" ] ); then
    echo "FATAL: $DEVICE is the Alpine Live USB. Refusing." | tee -a "$LOGFILE"; exit 1
fi

# Extra confirmation for internal/non-removable drives
if [ "$REMOVABLE" = "0" ]; then
    echo ""
    echo "╔══════════════════════════════════════════════╗"
    echo "║  WARNING: This looks like an INTERNAL drive  ║"
    echo "║  Make sure this is the target salvage disk,  ║"
    echo "║  not your main machine's storage.            ║"
    echo "╚══════════════════════════════════════════════╝"
    printf "Type YES to proceed with internal drive: "
    read CONFIRM </dev/tty
    [ "$CONFIRM" != "YES" ] && { echo "Aborted."; exit 1; }
fi

# ── Shared run_test (same pattern as test_new.sh) ──
EXIT_PENDING=0
trap 'EXIT_PENDING=1' INT
run_test() {
    TEST_NAME=$1; CMD=$2
    echo "[$TEST_NAME]..." | tee -a "$LOGFILE"
    eval "$CMD" 2>&1 | tee -a "$LOGFILE"
    STS=$?
    if [ $STS -ne 0 ]; then
        echo "ODDITY in $TEST_NAME — press Enter to continue" | tee -a "$LOGFILE"
        read _ </dev/tty
    fi
    [ "$EXIT_PENDING" -eq 1 ] && { echo "Aborted." | tee -a "$LOGFILE"; exit 0; }
}

# ── Detect USB bridge (trial-and-error) ──
detect_flags() {
    for flags in "" "-d sat" "-d usbjmicron"; do
        smartctl $flags -i "$1" 2>&1 | grep -qi "device identity" && { echo "$flags"; return 0; }
    done
    echo ""
}
SMRTFLAGS=$(detect_flags "$DEVICE")
echo "smartctl flags: ${SMRTFLAGS:-(none)}" | tee "$LOGFILE"
[ -z "$SMRTFLAGS" ] && echo "WARNING: USB bridge not recognised" | tee -a "$LOGFILE"

SCORE_PASS=0; SCORE_WARN=0; SCORE_FAIL=0

echo "═══ DISK SALVAGE: $(basename "$DEVICE") ═══" | tee -a "$LOGFILE"

# ── 1. Spin-up (human) ──
printf "Q: Did spindle start smoothly within 10s? (yes/no): "
read SPIN_OK </dev/tty
case "$SPIN_OK" in yes|YES|y|Y)
    echo "  SPIN-UP: PASS" | tee -a "$LOGFILE"; SCORE_PASS=$((SCORE_PASS + 1)) ;;
*)
    echo "  SPIN-UP: FAIL" | tee -a "$LOGFILE"; SCORE_FAIL=$((SCORE_FAIL + 1)) ;;
esac

# ── 2. SMART health ──
run_test "SMART HEALTH" "smartctl $SMRTFLAGS -H $DEVICE"
if grep -qi "PASSED" "$LOGFILE"; then
    SCORE_PASS=$((SCORE_PASS + 1))
elif grep -qi "FAILED" "$LOGFILE"; then
    SCORE_FAIL=$((SCORE_FAIL + 1))
else
    SCORE_WARN=$((SCORE_WARN + 1))
fi

# ── 3. SMART attributes ──
run_test "SMART ATTRIBUTES" "smartctl $SMRTFLAGS -A $DEVICE"
REALLOC=$(smartctl $SMRTFLAGS -A "$DEVICE" 2>/dev/null | awk '/Reallocated_Sector_Ct/ {print $10}')
PENDING=$(smartctl $SMRTFLAGS -A "$DEVICE" 2>/dev/null | awk '/Current_Pending_Sector/ {print $10}')
UNCORRECT=$(smartctl $SMRTFLAGS -A "$DEVICE" 2>/dev/null | awk '/Offline_Uncorrectable/ {print $10}')
REALLOC=${REALLOC:-0}; PENDING=${PENDING:-0}; UNCORRECT=${UNCORRECT:-0}
echo "  R=$REALLOC P=$PENDING U=$UNCORRECT" | tee -a "$LOGFILE"
if [ "$REALLOC" -le 10 ] && [ "$PENDING" -eq 0 ] && [ "$UNCORRECT" -eq 0 ]; then
    SCORE_PASS=$((SCORE_PASS + 1))
elif [ "$REALLOC" -le 100 ] && [ "$PENDING" -le 5 ] && [ "$UNCORRECT" -le 5 ]; then
    SCORE_WARN=$((SCORE_WARN + 1))
else
    SCORE_FAIL=$((SCORE_FAIL + 1))
fi

# ── 4. Bad blocks (read-only, first 1%) ──
DISK_SIZE=$(blockdev --getsize64 "$DEVICE" 2>/dev/null)
SAMPLE_END=$((DISK_SIZE / 100))
run_test "BAD BLOCKS (1% sample)" "badblocks -sv -o /tmp/bb_$$.txt $DEVICE 0 $SAMPLE_END"
BB_COUNT=0
[ -f /tmp/bb_$$.txt ] && BB_COUNT=$(wc -l < /tmp/bb_$$.txt)
rm -f /tmp/bb_$$.txt
[ "$BB_COUNT" -eq 0 ] && SCORE_PASS=$((SCORE_PASS + 1))
[ "$BB_COUNT" -gt 0 ] && [ "$BB_COUNT" -le 10 ] && SCORE_WARN=$((SCORE_WARN + 1))
[ "$BB_COUNT" -gt 10 ] && SCORE_FAIL=$((SCORE_FAIL + 1))

# ── 5. Destructive zero-fill (skippable) ──
printf "Destructive zero-fill 1GB? (yes/no): "
read DESTROY_OK </dev/tty
case "$DESTROY_OK" in yes|YES|y|Y)
    run_test "ZERO-FILL 1GB" "dd if=/dev/zero of=$DEVICE bs=1M count=1024 conv=fdatasync"
    VERIFY=$(dd if="$DEVICE" bs=1M count=1024 2>/dev/null | od -An -tx1 | grep -v "00 00 00 00" | head -1)
    [ -z "$VERIFY" ] && SCORE_PASS=$((SCORE_PASS + 1)) || SCORE_WARN=$((SCORE_WARN + 1))
    ;;
esac

# ── Verdict ──
echo "PASS=$SCORE_PASS  WARN=$SCORE_WARN  FAIL=$SCORE_FAIL" | tee -a "$LOGFILE"
if   [ "$SCORE_FAIL" -ge 3 ]; then VERDICT="FAIL — Recycle"
elif [ "$SCORE_FAIL" -ge 1 ] || [ "$SCORE_WARN" -ge 2 ]; then VERDICT="WARN — Sell for parts"
elif [ "$SCORE_WARN" -eq 1 ] && [ "$SCORE_PASS" -ge 3 ]; then VERDICT="WARN — Sell used (disclose)"
else  VERDICT="PASS — Sell functional"
fi
echo "VERDICT: $VERDICT" | tee -a "$LOGFILE"
