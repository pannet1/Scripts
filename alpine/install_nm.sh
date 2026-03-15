#!/bin/sh
set -e

echo "--- INSTALLING NETWORK MANAGER & WIFI FIRMWARE ---"

# 1. Update repos
apk update

# 2. Wireless Radio Blobs
# iwlwifi = Intel WiFi
# rtlwifi = Realtek WiFi (Common in Acer)
# ath10k/11k = Qualcomm/Atheros (Common in Acer/HP)
echo "installing linux firmware .."
apk add linux-firmware-iwlwifi \
    linux-firmware-rtlwifi \
    linux-firmware-ath10k \
    linux-firmware-ath11k

# 3. Install NM, the CLI tool, and universal WiFi firmware
# Added networkmanager-cli so the command 'nmcli' exists
# Added linux-firmware-iwlwifi & rtlwifi for Intel/Realtek chips
echo "installing network manager "
apk add networkmanager \
    networkmanager-wifi \
    wpa_supplicant \
    wireless-tools

# 4. Save to USB Cache and Persist
apk cache sync
touch /media/usb/.boot_repository
lbu commit -d

echo "------------------------------------------------"
echo "If WiFi is still off, run: rfkill unblock all"
echo "------------------------------------------------"
