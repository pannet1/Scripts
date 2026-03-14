#!/bin/sh

# Path to store known credentials on your USB
CONF_DIR="/etc/wpa_supplicant"
CONF_FILE="$CONF_DIR/wpa_supplicant.conf"

provision_network() {
    echo "--- WIFI PROVISIONING & HARDWARE VALIDATION ---"

    # 1. SCAN FOR DEVICE
    IFACE=$(iw dev | awk '/Interface/ {print $2}' | head -n 1)
    if [ -z "$IFACE" ]; then
        echo -e "\e[31m[!] ERROR: No Wi-Fi hardware detected.\e[0m"
        return 1
    fi
    echo "Using Device: $IFACE"

    # 2. CHECK BLOCKS (RFKILL)
    rfkill unblock wifi
    if rfkill list wifi | grep -q "Hard blocked: yes"; then
        echo -e "\e[31m[!] HARD BLOCK: Physical switch is OFF. Flip it and press Enter.\e[0m"
        read _
    fi

    # 3. ATTEMPT EXISTING CONNECTION (If config exists)
    if [ -s "$CONF_FILE" ]; then
        echo "Found saved credentials. Attempting connection..."
        killall wpa_supplicant 2>/dev/null
        wpa_supplicant -B -i "$IFACE" -c "$CONF_FILE"
        sleep 5
        udhcpc -n -i "$IFACE" -t 5 # -n exits if no lease found quickly

        if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
            echo -e "\e[32m[+] Successfully connected using saved profile.\e[0m"
            return 0
        fi
        echo "Saved credentials failed or timed out."
        killall wpa_supplicant 2>/dev/null
    fi

    # 4. SHOW LIST OF SSID
    echo -e "\nScanning for networks..."
    ip link set "$IFACE" up
    # Create a numbered list for selection
    SCAN_RESULTS=$(iw dev "$IFACE" scan | grep "SSID" | awk '{print $2}' | sort -u)

    if [ -z "$SCAN_RESULTS" ]; then
        echo "No networks found. Check antennas."
        return 1
    fi

    echo "Available Networks:"
    i=1
    for ssid in $SCAN_RESULTS; do
        echo "$i) $ssid"
        eval "SSID_$i=\$ssid"
        i=$((i + 1))
    done

    # 5. SELECT AND ENTER PASSWORD
    echo -ne "\nSelect a number or type SSID manually: "
    read selection

    # Check if input is a number from our list
    eval chosen_ssid=\$SSID_$selection
    if [ -z "$chosen_ssid" ]; then
        chosen_ssid=$selection
    fi

    echo -ne "Enter Password for [$chosen_ssid]: "
    read -s wifi_pass
    echo "" # New line after hidden password

    # 6. GENERATE NEW CONFIG AND TEST
    mkdir -p "$CONF_DIR"
    wpa_passphrase "$chosen_ssid" "$wifi_pass" >"$CONF_FILE"

    killall wpa_supplicant 2>/dev/null
    wpa_supplicant -B -i "$IFACE" -c "$CONF_FILE"

    echo "Authenticating..."
    sleep 5
    udhcpc -i "$IFACE"

    if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        echo -e "\e[32m[+] Connection Successful!\e[0m"
        # Since it worked, let's make it persist for the next laptop
        lbu add "$CONF_FILE"
        echo "Profile saved to LBU. Remember to 'lbu commit -d' before shutdown."
        return 0
    else
        echo -e "\e[31m[-] Connection Failed. Incorrect password or poor signal.\e[0m"
        rm "$CONF_FILE" # Clear failed config
        return 1
    fi
}

provision_network
