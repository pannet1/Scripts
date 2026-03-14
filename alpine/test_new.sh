#!/bin/sh

# test_new.sh

# Standard log file
LOG_FILE="diag_report.txt"

# Initialize log file with a header
echo "--- DIAGNOSTIC REPORT: $(date) ---" >"$LOG_FILE"

# 1. TRAP FOR GRACEFUL EXIT
EXIT_PENDING=0
trap 'echo -e "\n\e[31m[!] Exit requested. Finishing current test...\e[0m" | tee -a "$LOG_FILE"; EXIT_PENDING=1' INT

# 2. CONDITIONAL STALL & LOGGING
# Usage: run_test "Test Name" "command"
run_test() {
    TEST_NAME=$1
    CMD=$2

    echo -e "\n[$TEST_NAME]..." | tee -a "$LOG_FILE"

    # Execute command and capture exit status
    eval "$CMD" 2>&1 | tee -a "$LOG_FILE"
    STATUS=$?

    # Stall only if the command failed (oddity detected)
    if [ $STATUS -ne 0 ]; then
        echo -e "\e[31m[!] ODDITY DETECTED in $TEST_NAME\e[0m" | tee -a "$LOG_FILE"
        echo -e "\e[33m--- Press [Enter] to continue ---\e[0m"
        # Reading from /dev/tty ensures 'read' works even inside piped logic
        read _ </dev/tty
    fi

    # Check for Ctrl+C exit request
    if [ "$EXIT_PENDING" -eq 1 ]; then
        echo "Exiting suite." | tee -a "$LOG_FILE"
        exit 0
    fi
}

clear
{
    echo "================================================="
    echo "    ULTIMATE CHIP-LEVEL DIAGNOSTIC SUITE v4.2    "
    echo "================================================="
} | tee -a "$LOG_FILE"

# --- TEST SECTION ---

# 1. STORAGE (Fails if smartctl returns non-zero)
run_test "STORAGE HEALTH" "smartctl -H /dev/sda || smartctl -H /dev/nvme0n1"

# 3. BATTERY (Fails if health is critically low)
check_battery() {
    for bat in /sys/class/power_supply/BAT*; do
        [ -d "$bat" ] || return 1
        DESIGN=$(cat "$bat/energy_full_design" 2>/dev/null || cat "$bat/charge_full_design" 2>/dev/null)
        FULL=$(cat "$bat/energy_full" 2>/dev/null || cat "$bat/charge_full" 2>/dev/null)
        HEALTH=$((FULL * 100 / DESIGN))
        echo "Battery Health: $HEALTH%"
        [ "$HEALTH" -lt 40 ] && return 1 # Trigger stall if < 40%
    done
    return 0
}
run_test "BATTERY REPORT" "check_battery"

# 4. THERMAL (Fails if temp > 85C)
check_thermal() {
    OVERHEAT=0
    for zone in /sys/class/thermal/thermal_zone*; do
        TEMP=$(($(cat "$zone/temp") / 1000))
        echo "$(cat "$zone/type"): ${TEMP}°C"
        [ "$TEMP" -gt 85 ] && OVERHEAT=1
    done
    [ "$OVERHEAT" -eq 1 ] && return 1
    return 0
}
run_test "THERMAL ZONES" "check_thermal"

# 10. WIFI (Fails if hardware is blocked or missing)
check_wifi() {
    WLAN_DEV=$(nmcli -t -f DEVICE,TYPE device | grep wifi | cut -d: -f1 | head -n 1)
    if [ -z "$WLAN_DEV" ]; then
        echo "Hardware missing." && return 1
    fi
    rfkill list wifi | grep -q "yes" && {
        echo "Radio is Soft/Hard Blocked!"
        return 1
    }
    nmcli -f SSID,SIGNAL,BARS dev wifi | head -n 5
}
run_test "WIFI AUDIT" "check_wifi"

echo -e "\nReport saved to: $LOG_FILE"
echo "=================================================" | tee -a "$LOG_FILE"
