#!/bin/sh

# test_new.sh — full hardware diagnostic suite

LOG_FILE="diag_report.txt"
echo "--- DIAGNOSTIC REPORT: $(date) ---" >"$LOG_FILE"

EXIT_PENDING=0
trap 'echo -e "\n\e[31m[!] Exit requested.\e[0m" | tee -a "$LOG_FILE"; EXIT_PENDING=1' INT

run_test() {
    TEST_NAME=$1; CMD=$2
    echo -e "\n[$TEST_NAME]..." | tee -a "$LOG_FILE"
    eval "$CMD" 2>&1 | tee -a "$LOG_FILE"
    STS=$?
    if [ $STS -ne 0 ]; then
        echo -e "\e[31m[!] ODDITY in $TEST_NAME\e[0m" | tee -a "$LOG_FILE"
        echo -e "\e[33m--- Press [Enter] to continue ---\e[0m"
        read _ </dev/tty
    fi
    [ "$EXIT_PENDING" -eq 1 ] && { echo "Exiting." | tee -a "$LOG_FILE"; exit 0; }
}

clear
echo "=================================================" | tee -a "$LOG_FILE"
echo "    ULTIMATE CHIP-LEVEL DIAGNOSTIC SUITE v5.0    " | tee -a "$LOG_FILE"
echo "=================================================" | tee -a "$LOG_FILE"

# ── 1. STORAGE HEALTH ──
run_test "STORAGE HEALTH" "
    for dev in /dev/nvme[0-9]n1; do
        [ -e \"\$dev\" ] && nvme smart-log \"\$dev\" 2>/dev/null | grep -E 'critical|percentage|temperature'
    done
    smartctl -H /dev/sda 2>/dev/null || smartctl -H -d sat /dev/sda 2>/dev/null || echo 'No SATA drive'
"

# ── 2. NVME/SATA DETAIL ──
run_test "DISK INFO" "
    for dev in /dev/nvme[0-9]n1 /dev/sda; do
        [ -e \"\$dev\" ] && smartctl -i \"\$dev\" 2>/dev/null | grep -E 'Model|Serial|Capacity|SMART'
    done
"

# ── 3. BATTERY ──
check_battery() {
    found=0
    for bat in /sys/class/power_supply/BAT*; do
        [ -d "$bat" ] || continue; found=1
        DESIGN=$(cat "$bat/energy_full_design" 2>/dev/null || cat "$bat/charge_full_design" 2>/dev/null)
        FULL=$(cat "$bat/energy_full" 2>/dev/null || cat "$bat/charge_full" 2>/dev/null)
        echo "Status: $(cat "$bat/status") | Health: $((FULL * 100 / DESIGN))%"
        echo "Cycles: $(cat "$bat/cycle_count" 2>/dev/null || echo 'N/A')"
    done
    [ "$found" -eq 0 ] && echo "No battery found" && return 1
    return 0
}
run_test "BATTERY REPORT" "check_battery"

# ── 4. THERMAL ──
check_thermal() {
    OVERHEAT=0
    for zone in /sys/class/thermal/thermal_zone*; do
        TEMP=$(($(cat "$zone/temp") / 1000 2>/dev/null))
        echo "$(cat "$zone/type"): ${TEMP}°C"
        [ "$TEMP" -gt 85 ] && OVERHEAT=1
    done
    [ "$OVERHEAT" -eq 1 ] && return 1
    return 0
}
run_test "THERMAL ZONES" "check_thermal"

# ── 5. CPU STRESS ──
run_test "CPU STRESS (10s)" "stress-ng --cpu 0 --timeout 10s --metrics-brief 2>&1"

# ── 6. RAM TEST ──
run_test "RAM HEALTH" "memtester 128M 1 2>&1"

# ── 7. BUS SCAN ──
run_test "BUS SCAN" "lspci | grep -iE 'vga|network|audio|usb|memory'"

# ── 8. SCREEN TEST (dead pixels) ──
echo -e "\n[SCREEN TEST]..." | tee -a "$LOG_FILE"
echo "Displaying solid colors. Check for dead/stuck pixels." | tee -a "$LOG_FILE"
echo -e "\e[33mPress Enter after each color. Ctrl+C to skip.\e[0m"
for color in "41" "42" "44" "47" "40"; do
    printf "\e[${color}m\e[2J\e[H                    COLOR TEST\e[0m\e[2J\e[H"
    read _ </dev/tty 2>/dev/null || break
done
printf "\e[0m\e[2J\e[H"
echo "  SCREEN TEST: done" | tee -a "$LOG_FILE"

# ── 9. KEYBOARD TEST ──
echo -e "\n[KEYBOARD TEST]..." | tee -a "$LOG_FILE"
echo "Type keys to test. Press Ctrl+C to finish." | tee -a "$LOG_FILE"
showkey -a 2>/dev/null
echo "  KEYBOARD TEST: done" | tee -a "$LOG_FILE"

# ── 10. AUDIO TEST ──
run_test "AUDIO TEST" "
    if command -v amixer >/dev/null; then
        amixer sset Master unmute >/dev/null 2>&1
        amixer sset Master 80% >/dev/null 2>&1
    fi
    speaker-test -t sine -f 440 -l 1 2>&1 || printf '\\a'
    echo 'If silent: check speakers/headphone jack'
"

# ── 11. WIFI ──
check_wifi() {
    IFACE=$(iw dev | awk '/Interface/ {print $2}' | head -1)
    [ -z "$IFACE" ] && echo "No WiFi hardware" && return 1
    rfkill unblock wifi
    ip link set "$IFACE" up 2>/dev/null
    echo "Interface: $IFACE"
    iw dev "$IFACE" scan | grep -E "SSID|signal" | head -6
}
run_test "WIFI AUDIT" "check_wifi"

# ── 12. BIOS / MOTHERBOARD ──
run_test "BIOS INFO" "
    echo 'Model:      ' \$(dmidecode -s system-product-name 2>/dev/null)
    echo 'Serial:     ' \$(dmidecode -s system-serial-number 2>/dev/null)
    echo 'BIOS:       ' \$(dmidecode -s bios-version 2>/dev/null) \$(dmidecode -s bios-release-date 2>/dev/null)
    echo 'Manufacturer:' \$(dmidecode -s system-manufacturer 2>/dev/null)
"

echo -e "\nReport saved to: $LOG_FILE" | tee -a "$LOG_FILE"
echo "=================================================" | tee -a "$LOG_FILE"
