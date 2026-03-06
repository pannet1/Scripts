#!/bin/sh
apk add networkmanager networkmanager-wifi wpa_supplicant
rc-update add networkmanager
rc-service networkmanager start
apk cache sync
touch /media/usb/.boot_repository
lbu commit -d
echo "NetworkManager is now active and persistent."
