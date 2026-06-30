#!/bin/sh
# Persist Scripts and config to USB

# Find .profile source — try /root/Scripts, /media/*/Scripts, flat on USB root
PROFILE_SRC=""
for d in /root/Scripts/alpine/.profile /media/*/Scripts/alpine/.profile /media/*/.profile; do
    [ -f "$d" ] && PROFILE_SRC="$d" && break
done

if [ -n "$PROFILE_SRC" ]; then
    cp -f "$PROFILE_SRC" /root/.profile
    lbu add /root/.profile
fi

mkdir -p /root/Scripts/alpine
lbu add /root/Scripts
lbu add /root/.gitconfig 2>/dev/null || true
lbu commit -d
echo "Committed. Reboot to verify persistence."
