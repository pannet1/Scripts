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

# 1. FIXED STORAGE SCAN
echo -e "\n[1/9] STORAGE HEALTH..."
# Scan for NVMe
if command -v nvme >/dev/null; then
    for dev in /dev/nvme[0-9]n1; do
        [ -e "$dev" ] && echo "--- NVMe: $dev ---" && nvme smart-log "$dev" | grep -E "critical_warning|percentage_used"
    done
fi
# Fixed SATA scan - Using -a to show all if -H fails
smartctl -H /dev/sda 2>/dev/null || smartctl -H -d sat /dev/sda 2>/dev/null || echo "No SATA drive found."
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

# 4. FIXED THERMAL LOOP (No more math errors)
echo -e "\n[4/9] THERMAL ZONES..."
for zone in /sys/class/thermal/thermal_zone*; do
    [ -d "$zone" ] || continue
    TYPE=$(cat "$zone/type")
    RAW_TEMP=$(cat "$zone/temp" 2>/dev/null)
    # Check if RAW_TEMP is a number
    if [ "$RAW_TEMP" -eq "$RAW_TEMP" ] 2>/dev/null; then
        echo "$TYPE: $(($RAW_TEMP / 1000))°C"
    else
        echo "$TYPE: $RAW_TEMP (Raw/Non-numeric)"
    fi
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

# 9. FIXED AUDIO TEST (Force Unmute)
echo -e "\n[9/9] AUDIO TEST..."
echo "Attempting to unmute and play tone..."
# Aspiring Tech Tip: Hardware is often muted by default in Linux
if command -v amixer >/dev/null; then
    aplay -l
    amixer sset Master unmute >/dev/null 2>&1
    amixer sset Master 80% >/dev/null 2>&1
fi
# Try playing the tone
speaker-test -t sine -f 440 -l 1 >/dev/null 2>&1 || printf "\a"
echo "If silent: Check Codec/Speaker connection."

# 10. WIFI QUALITY AUDIT
echo -e "\n[10/10] WIFI CAPABILITY & SIGNAL AUDIT..."
WLAN_DEV=$(nmcli device | grep wifi | awk '{print $1}' | head -n 1)

if [ -z "$WLAN_DEV" ]; then
    echo "No WiFi Device Found."
else
    echo "Device: $WLAN_DEV"
    # Show hardware capabilities
    iw dev "$WLAN_DEV" info
    echo "-------------------------------------------"
    echo "Nearby Networks & Signal Strength (dBm):"
    nmcli -f SSID,SIGNAL,BARS,RATE dev wifi | head -n 5

    # Check for "Soft Blocks" that might be limiting power
    rfkill list wifi
fi
echo "================================================="
echo "          DIAGNOSTICS COMPLETE                  "
echo "================================================="
