#!/bin/sh
set -e

echo "--- STARTING TOOL INSTALLATION ---"

# 0. Clean stale cache indexes and prep repos
rm -f /media/usb/cache/APKINDEX.*.tar.gz
rm -f /media/usb/cache/.boot_repository
cp /etc/apk/repositories /etc/apk/repositories.bak 2>/dev/null
true > /etc/apk/repositories

# 1. Enable Community Repos
setup-apkrepos -c
apk update

# 2. Setup USB Cache (Alpine Way)
# Ensures tools stay on the USB for offline use
setup-apkcache /media/usb/cache

# 3. Install the "Technician's Heavy Duty" Package List
# kbd = keyboard test, alsa-utils = audio, pciutils = lspci
apk add smartmontools memtester stress-ng acpi pciutils nvme-cli kbd alsa-utils dmidecode e2fsprogs e2fsprogs-utils util-linux
apk add alsa-utils alsa-ucm-conf
rc-service alsa start

# 4. Sync and Persist
apk cache -v sync
lbu commit -d

echo "--- ALL TOOLS INSTALLED & PERSISTED ---"
