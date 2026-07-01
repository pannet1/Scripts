#!/bin/sh

# ─────────────────────────────────────────────────────────────
# Welcome menu — shown at root login on Alpine Live USB
# Auto-runs prerequisites before each option.
# ─────────────────────────────────────────────────────────────

SCRIPT_DIR=$(dirname "$0" 2>/dev/null)
[ -z "$SCRIPT_DIR" ] && SCRIPT_DIR="/root/Scripts/alpine"
export PATH=$SCRIPT_DIR:$PATH

# ── Self-install: persist this menu to auto-start on login ──
if [ ! -f /root/.profile ] || ! grep -q "welcome.sh" /root/.profile 2>/dev/null; then
    echo "╔══════════════════════════════════════════════╗"
    echo "║  First run — install menu to auto-start?     ║"
    echo "║  (copies .profile → /root/, persists overlay) ║"
    echo "╚══════════════════════════════════════════════╝"
    printf "Install? (Y/n): "; read ANS </dev/tty
    case "$ANS" in n|N|no|NO) echo "Skipped." ;; *)
        mount -o remount,rw /media/usb 2>/dev/null
        cp -f "$SCRIPT_DIR/.profile" /root/.profile 2>/dev/null
        lbu add /root/.profile 2>/dev/null
        lbu commit -d 2>/dev/null && echo "Installed! Reboot to auto-start menu." || echo "lbu failed — is USB writable? Use option 8 to remount."
    esac
    echo ""
fi

# ── Prerequisite helpers ──
need_pkg() {
    for cmd in "$@"; do
        command -v "$cmd" >/dev/null && return 0
    done
    echo "  Installing prerequisites..."
    "$SCRIPT_DIR/install_test.sh"
    command -v "$1" >/dev/null
}
need_git()    { command -v git >/dev/null || { "$SCRIPT_DIR/install_git.sh"; command -v git >/dev/null; }; }
need_wifi()   { command -v wpa_supplicant >/dev/null || { "$SCRIPT_DIR/install_nm.sh"; command -v wpa_supplicant >/dev/null; }; }
need_drivers(){ "$SCRIPT_DIR/install_drivers.sh"; }

# ── Network helpers ──
has_net() { ping -c 1 8.8.8.8 >/dev/null 2>&1; }

try_connect_usb() {
    echo "  Trying USB tethering..."
    "$SCRIPT_DIR/connect_usb.sh" 2>/dev/null
    sleep 3
    has_net
}

try_connect_wifi() {
    echo "  Trying WiFi..."
    "$SCRIPT_DIR/connect_wifi.sh"
    has_net
}

connect_network() {
    # 1. Try ethernet — detect interface name dynamically
    echo "  Trying ethernet..."
    for IFACE in $(ip -o link show | awk -F': ' '{print $2}' | grep -v lo); do
        [ -z "$(ip -o link show "$IFACE" | grep -i 'state UP')" ] && continue
        timeout 10 udhcpc -i "$IFACE" -n -t 3 >/dev/null 2>&1 && has_net && return 0
    done
    # Also try all ethernet-looking interfaces even if not UP
    for IFACE in $(ip -o link show | awk -F': ' '{print $2}' | grep -E '^e(n|th|np)' | head -3); do
        timeout 10 udhcpc -i "$IFACE" -n -t 3 >/dev/null 2>&1 && has_net && return 0
    done

    # 2. Start NetworkManager (handles ethernet/wifi auto-connect)
    if command -v nmcli >/dev/null; then
        echo "  Starting NetworkManager..."
        "$SCRIPT_DIR/enable_nm.sh"
        sleep 5
        has_net && return 0
    fi

    # 3. USB tethering
    try_connect_usb && return 0

    # 4. WiFi (interactive)
    need_wifi && try_connect_wifi && return 0

    echo "  No network available."
    return 1
}

# ── Detect network state ──
WLAN=$(iw dev 2>/dev/null | awk '/Interface/ {print $2}' | head -1)
has_net && HAS_NET=1 || HAS_NET=0

menu() {
    clear
    echo "═══════════════════════════════════════"
    echo "  ALPINE LIVE USB — TECH RESCUE KIT"
    echo "═══════════════════════════════════════"
    if [ "$HAS_NET" -eq 1 ]; then
        echo "  Network: CONNECTED"
    elif [ -n "$WLAN" ]; then
        echo "  Network: WiFi ($WLAN) — run option 4"
    else
        echo "  Network: no WiFi hardware detected"
    fi
    echo "───────────────────────────────────────"
    echo "  1) Test hardware (laptop diag)"
    echo "  2) Test drive enclosure (salvage)"
    echo "  3) Test USB speed"
    echo "  4) Connect to network (eth → usb → wifi)"
    echo "  5) Update tools + pull latest code"
    echo "  6) Install diagnostic tools"
    echo "  7) Commit changes to USB (persist scripts)"
     echo "  8) Remount USB writable (fix lbu)"
     echo "  9) Power off"
     echo "  q) Quit"
    echo "───────────────────────────────────────"
}

while true; do
    menu
    printf "Choice: "; read CH </dev/tty; echo ""

    case "$CH" in
        1) need_pkg smartctl && "$SCRIPT_DIR/test_new.sh"
           echo; printf "Press Enter..."; read _ </dev/tty ;;
        2) DEV=$("$SCRIPT_DIR/detect_enclosure.sh" 2>&1 | tee /dev/stderr | tail -1)
           STS=$?
           echo ""
           [ $STS -ne 0 ] && { printf "Press Enter..."; read _ </dev/tty; continue; }
           need_pkg smartctl badblocks
           echo "  Starting salvage triage on $DEV..."
           "$SCRIPT_DIR/salvage_disk.sh" "$DEV"
           echo; printf "Press Enter..."; read _ </dev/tty ;;
        3) "$SCRIPT_DIR/test_usb.sh"
           echo; printf "Press Enter..."; read _ </dev/tty ;;
        4) connect_network
           has_net && HAS_NET=1 || HAS_NET=0
           echo; printf "Press Enter..."; read _ </dev/tty ;;
        5) need_git
           apk update && apk upgrade
           cd /root/Scripts && git pull
           echo "Done."; printf "Press Enter..."; read _ </dev/tty ;;
        6) "$SCRIPT_DIR/install_test.sh"
           printf "Press Enter..."; read _ </dev/tty ;;
        7) "$SCRIPT_DIR/write_all.sh"
           printf "Press Enter..."; read _ </dev/tty ;;
        8) "$SCRIPT_DIR/enable_write.sh"
           echo "USB remounted rw."; printf "Press Enter..."; read _ </dev/tty ;;
         9) poweroff ;;
         q|Q) exit 0 ;;
        *) echo "Invalid"; sleep 1 ;;
    esac
done
