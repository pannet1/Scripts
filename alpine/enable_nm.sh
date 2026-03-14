#!/bin/sh
set -e

echo "--- INSTALLING NETWORK MANAGEMENT TOOLS ---"

# 3. Configure Services
# We ensure wpa_supplicant is NOT running standalone to avoid conflicts
rc-service wpa_supplicant stop 2>/dev/null || true
rc-update add networkmanager default
rc-service networkmanager start

echo "Management tools installed. nmcli command is now active."
