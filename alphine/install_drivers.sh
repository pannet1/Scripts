#!/bin/sh
# Add the Big Three for Acer, HP, Dell, etc.
apk add linux-firmware-intel linux-firmware-rtlwifi linux-firmware-ath10k
# Ensure they stay on the USB
apk cache sync
touch /media/usb/.boot_repository
lbu commit -d
echo "Firmware installed and cached to USB."
