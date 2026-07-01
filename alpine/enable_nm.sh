#!/bin/sh

echo "--- INSTALLING NETWORK MANAGEMENT  ---"

# We ensure wpa_supplicant is NOT running standalone to avoid conflicts
rc-service wpa_supplicant stop 2>/dev/null || true

rc-update add networkmanager default 2>/dev/null || true
timeout 30 rc-service networkmanager start 2>/dev/null || true

