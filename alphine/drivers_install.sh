#!/bin/sh
set -e

echo "--- INSTALLING SYSTEM & MOTHERBOARD DRIVERS ---"

# 1. Update Repo Index
apk update

# 2. Motherboard & Chipset Blobs
# intel/amd-ucode = CPU Stability/Security patches
# amdgpu = Integrated/Dedicated AMD Graphics
# sof-firmware = Sound Open Firmware (Fixes 'No Audio' on newer Intel)
# linux-firmware-intel = General Intel chipset/Bluetooth support
apk add linux-firmware-intel \
    intel-ucode \
    linux-firmware-amdgpu \
    amd-ucode \
    sof-firmware

# 3. Save to USB Persistence
apk cache sync
lbu commit -d

echo "SUCCESS: Hardware firmware installed. You may need to reload drivers or reboot."
