#!/bin/sh
echo "Setting up USB Tethering..."
ip link set usb0 up 2>/dev/null
modprobe rndis_host 2>/dev/null || true
timeout 10 udhcpc -i usb0 -n -t 3 >/dev/null 2>&1
echo "Check connection: ping -c 3 google.com"
