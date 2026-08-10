#!/usr/bin/env bash
# Disable unnecessary services on the Dell T5810 (Debian 13).
# Run as normal user — NOT with sudo (sudo makes `~` expand to /root and
# blocks 3/4 would write to root's home instead of yours).
# Each block is independent — comment out what you want to keep.

[ "$(id -u)" -ne 0 ] || { echo "Run as normal user (no sudo): $0"; exit 1; }

echo "=============================================="
echo "  Disable unnecessary services"
echo "=============================================="

# ── 1. ModemManager — no modem hardware (checked lsusb/lspci).
#     NM has no dependency on it (verified: systemctl show NetworkManager -p Wants)
#     Undo: sudo systemctl enable --now ModemManager
echo "--- 1/4 ModemManager ---"
sudo systemctl disable --now ModemManager

# ── 2. cron — no user crontabs; maintenance jobs (apt, logrotate, man-db,
#     e2scrub_all, dpkg-db-backup) all have enabled systemd timers.
#     Undo: sudo systemctl enable --now cron
echo "--- 2/4 cron ---"
sudo systemctl disable --now cron

# ── 3. xfce4-power-manager — desktop tower, no battery/lid; only loses DPMS
#     screen blanking. Killed by XDG autostart override (Hidden=true).
#     Undo: rm ~/.config/autostart/xfce4-power-manager.desktop
echo "--- 3/4 xfce4-power-manager (XDG autostart) ---"
mkdir -p ~/.config/autostart
printf '[Desktop Entry]\nHidden=true\n' >~/.config/autostart/xfce4-power-manager.desktop

# ── 4. ibus (6 procs) — started by qtile autostart line 4; system IM is ibus.
#     Comment the line in the LIVE file, then keep the repo copy in sync:
#     common/.config/qtile/autostart.sh  (stow source)
#     Undo: uncomment the line / git checkout the repo file
echo "--- 4/4 ibus (qtile autostart) ---"
sed -i 's|^/usr/bin/ibus-daemon -dr &$|# &|' ~/.config/qtile/autostart.sh
# optional: drop ibus as the X session input method
# im-config -n none

# upower needs no action: already disabled, pulled in on demand by
# xfce4-power-manager — it stops with it.

echo ""
echo "=============================================="
echo "  Verify: these should be empty/gone:"
echo "    systemctl list-units --type=service --state=running"
echo "      | grep -E 'ModemManager|cron|upower'"
echo "=============================================="
