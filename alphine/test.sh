#!/bin/sh

# Function to pause between tests
pause() {
    echo -e "\n\e[33m--- Press [Enter] to run the next test ---\e[0m"
    read _
}

# Function for Screen Test
run_screen_test() {
    echo -e "\n[7/9] STARTING SCREEN TEST (Dead Pixel Check)..."
    for color in "41" "42" "44" "47" "40"; do
        printf "\e[${color}m\e[2J\e[H"
        read _
    done
    printf "\e[0m\e[2J\e[H"
}

# Function for Keyboard Test
run_keyboard_test() {
    echo -e "\n[8/9] STARTING KEYBOARD TEST..."
    echo "Type keys to see codes. Press 'Ctrl+C' to exit if it hangs."
    # showkey -a reads characters and shows their ASCII/Escape codes
    showkey -a
}

clear
echo "================================================="
echo "   ULTIMATE CHIP-LEVEL DIAGNOSTIC SUITE v4.0    "
echo "================================================="

# 1. STORAGE S.M.A.R.T.
echo -e "\n[1/9] STORAGE HEALTH..."
if command -v nvme >/dev/null; then
    for dev in /dev/nvme*; do
        [ -e "$dev" ] || continue
        echo "--- NVMe: $dev ---"
        nvme smart-log "$dev" | grep -E "critical_warning|percentage_used|data_units_written"
    done
fi
smartctl -H /dev/sda 2>/dev/null || echo "No SATA drive found."
pause

# 3. BATTERY & CHARGING
echo -e "\n[3/9] BATTERY REPORT..."
for bat in /sys/class/power_supply/BAT*; do
    [ -d "$bat" ] || continue
    NAME=$(basename "$bat")
    DESIGN=$(cat "$bat/energy_full_design" 2>/dev/null || cat "$bat/charge_full_design" 2>/dev/null)
    FULL=$(cat "$bat/energy_full" 2>/dev/null || cat "$bat/charge_full" 2>/dev/null)
    echo "--- $NAME ---"
    echo "Status: $(cat "$bat/status") | Health: $(($FULL * 100 / $DESIGN))%"
    echo "Cycles: $(cat "$bat/cycle_count" 2>/dev/null || echo "N/A")"
done
pause

# 4. THERMAL SENSORS
echo -e "\n[4/9] THERMAL ZONES..."
for zone in /sys/class/thermal/thermal_zone*; do
    [ -d "$zone" ] || continue
    echo "$(cat "$zone/type"): $(($(cat "$zone/temp") / 1000))°C"
done
pause

# 5. CPU STRESS
echo -e "\n[5/9] CPU STRESS (10 Seconds)..."
stress-ng --cpu 0 --timeout 10s --metrics-brief
pause

# 6. PCI BUS & RAM
echo -e "\n[6/9] BUS SCAN & RAM TEST..."
lspci | grep -iE "vga|network|audio|usb"
memtester 128M 1
pause

# 7. SCREEN TEST
run_screen_test

# 8. KEYBOARD TEST
run_keyboard_test

# 9. AUDIO TEST
echo -e "\n[9/9] AUDIO TEST..."
speaker-test -t sine -f 440 -l 1 >/dev/null 2>&1 || printf "\a"
echo "DONE."

echo "================================================="
echo "          DIAGNOSTICS COMPLETE                  "
echo "================================================="
