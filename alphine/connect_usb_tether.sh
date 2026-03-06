#!/bin/sh
echo "Setting up USB Tethering..."
modprobe rndis_host
udhcpc -i eth0 || udhcpc -i usb0
echo "Check connection: ping -c 3 google.com"
