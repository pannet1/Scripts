#!/bin/sh
# Persist Scripts and config to USB
lbu add /root/Scripts
lbu add /root/.gitconfig 2>/dev/null || true
lbu commit -d
echo "Committed. Reboot to verify persistence."
