#!/bin/sh
echo "Scanning for WiFi..."
nmcli device wifi list
echo "--------------------------------------"
echo "To connect, type: nmcli dev wifi connect 'SSID_NAME' password 'PASSWORD'"
