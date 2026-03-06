#!/bin/sh
set -e

echo "--- STARTING TOOL INSTALLATION ---"

# 1. Enable Community Repos
setup-apkrepos -c
apk update

# 2. Setup USB Cache (Alpine Way)
# Ensures tools stay on the USB for offline use
setup-apkcache /media/usb/cache

# 3. Install the "Technician's Heavy Duty" Package List
# kbd = keyboard test, alsa-utils = audio, pciutils = lspci
apk add smartmontools memtester stress-ng acpi pciutils nvme-cli kbd alsa-utils

# 4. Sync and Persist
apk cache -v sync
touch /media/usb/cache/.boot_repository
lbu commit -d

echo "--- ALL TOOLS INSTALLED & PERSISTED ---"
