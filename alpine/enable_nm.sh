#!/bin/sh
set -e

echo "--- INSTALLING NETWORK MANAGEMENT  ---"


# We ensure wpa_supplicant is NOT running standalone to avoid conflicts
rc-service wpa_supplicant stop 2>/dev/null || true

rc-update add networkmanager default
rc-service networkmanager start

