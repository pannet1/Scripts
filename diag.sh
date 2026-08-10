#!/usr/bin/env bash
# System diagnostic — run as: ./diag.sh 2>&1 | tee output.txt
# Root-only commands (dmesg, smartctl, dmidecode, apt-get check, modprobe)
# run via individual `sudo` — you'll be prompted once, credentials cached ~15 min.
# See exactly what escalates: grep -n 'sudo ' diag.sh
set -uo pipefail

OUT="output.txt"
{
echo "=============================================="
echo "  System Diagnostic: $(date)"
echo "=============================================="
uname -a
cat /etc/os-release | head -2

echo ""
echo "=== BOOT PERFORMANCE ==="
systemd-analyze 2>/dev/null
systemd-analyze blame 2>/dev/null | head -12

echo ""
echo "=== KERNEL MESSAGES — errors/warnings (this boot) ==="
sudo dmesg -l err,warn 2>/dev/null | tail -80

echo ""
echo "=== KERNEL MESSAGES — full tail ==="
sudo dmesg 2>/dev/null | tail -60

echo ""
echo "=== KERNEL: nvidia / drm / acpi / firmware ==="
sudo dmesg 2>/dev/null | grep -iE 'nvidia|nouveau|drm|acpi|firmware|aic94xx|edac|mce|ras|thermal' | tail -60

echo ""
echo "=== PREVIOUS BOOT kernel errors (boot -1) ==="
sudo journalctl -k -b -1 -p err --no-pager 2>/dev/null | tail -30

echo ""
echo "=== SYSTEMD FAILED / DEGRADED UNITS ==="
systemctl --failed --no-pager 2>/dev/null

echo ""
echo "=== SYSTEMD: recent errors across boots ==="
journalctl -p err -b --no-pager 2>/dev/null | tail -40

echo ""
echo "=== SYSTEMD: errors in previous boots ==="
journalctl -p err -b -1 --no-pager 2>/dev/null | tail -30

echo ""
echo "=== SYSTEMD: boot timing breakdown ==="
systemd-analyze critical-chain 2>/dev/null | head -25

echo ""
echo "=== CRASHES / PANICS / OOPS ==="
sudo journalctl -k --no-pager 2>/dev/null | grep -iE 'panic|oops|bug:|kernel warning|segfault|call trace' | tail -20
grep -iE 'panic|oops|bug|call trace' /var/log/kern.log /var/log/syslog 2>/dev/null | tail -20

echo ""
echo "=== HARDWARE: memory / CPU ==="
lscpu | grep -E 'Model name|CPU\(s\)|MHz|Cache|Architecture'
free -h
sudo dmidecode -t memory 2>/dev/null | grep -E 'Size:|Type:|Speed:|Maximum Capacity|Locator' | grep -v 'No Module' | head -20

echo ""
echo "=== HARDWARE: disks (SMART health) ==="
lsblk -o NAME,SIZE,ROTA,TYPE,MOUNTPOINT,MODEL 2>/dev/null
if ! command -v smartctl >/dev/null 2>&1; then
    echo "smartctl NOT installed — install smartmontools for SMART checks"
fi
for disk in $(lsblk -dpno NAME 2>/dev/null | grep -E '^/dev/(sd|nvme)'); do
    echo "--- $disk ---"
    sudo smartctl -H "$disk" 2>/dev/null | grep -E 'SMART overall|SMART Health|result'
    sudo smartctl -A "$disk" 2>/dev/null | grep -iE 'Reallocated|Pending|Uncorrect|Current_Pending' || true
done

echo ""
echo "=== HARDWARE: thermal ==="
sensors 2>/dev/null | head -30 || true
for t in /sys/class/thermal/thermal_zone*/type; do
    [ -f "$t" ] || continue
    echo "$(cat "$t"): $(cat "${t%/type}/temp" 2>/dev/null)"
done 2>/dev/null

echo ""
echo "=== HARDWARE: GPU ==="
lspci | grep -iE 'vga|3d|display'
nvidia-smi 2>&1 | head -15
echo "-- nvidia module params --"
for p in modeset fbdev; do
    echo "nvidia_drm.$p = $(sudo cat /sys/module/nvidia_drm/parameters/$p 2>&1)"
done
cat /proc/driver/nvidia/params 2>/dev/null
cat /proc/driver/nvidia/gpus/*/information 2>/dev/null | head -20

echo ""
echo "=== HARDWARE: USB / storage errors ==="
sudo dmesg 2>/dev/null | grep -iE 'usb.*(error|fail|reset|unable)|sd [a-z].*(error|fail)|ata[0-9].*(error|fail)' | tail -30

echo ""
echo "=== NETWORK ==="
ip -br link 2>/dev/null
ip -br addr 2>/dev/null | grep -vE '127.0.0.1|::1'
nmcli -t -f NAME,DEVICE,TYPE,STATE device 2>/dev/null

echo ""
echo "=== POWER / ACPI / SUSPEND ==="
cat /sys/power/mem_sleep 2>/dev/null
cat /sys/power/state 2>/dev/null
systemctl is-enabled suspend.target hibernate.target hybrid-sleep.target 2>/dev/null
sudo dmesg 2>/dev/null | grep -iE 's0ix|suspend|hibernate|acpi.*error|power' | tail -20

echo ""
echo "=== KERNEL MODULE ISSUES ==="
lsmod | grep -iE 'nvidia|nouveau' 
sudo modprobe -n -v nouveau 2>&1

echo ""
echo "=== SWAP / MEMORY PRESSURE ==="
cat /proc/swaps 2>/dev/null || echo "no swap"
cat /proc/sys/vm/swappiness
cat /proc/sys/vm/vfs_cache_pressure

echo ""
echo "=== GRUB / KERNEL CMDLINE ==="
cat /proc/cmdline

echo ""
echo "=== DPKG: held/broken packages ==="
dpkg --audit 2>/dev/null | head
apt-mark showhold 2>/dev/null

echo ""
echo "=== SYSTEM STATE ==="
systemctl is-system-running 2>/dev/null

echo ""
echo "=== DISK SPACE / INODES ==="
df -h -x tmpfs -x devtmpfs 2>/dev/null
echo "-- inodes --"
df -i -x tmpfs -x devtmpfs 2>/dev/null

echo ""
echo "=== MOUNTS / FSTAB ==="
echo "-- fstab entries --"
grep -vE '^\s*(#|$)' /etc/fstab 2>/dev/null
echo "-- verify fstab --"
findmnt --verify --tab-file /etc/fstab 2>&1 | grep -v 'successfully verified' | head -10
echo "-- /mnt/windows --"
findmnt -rno TARGET,SOURCE,FSTYPE /mnt/windows 2>/dev/null || echo "/mnt/windows NOT mounted"

echo ""
echo "=== PACKAGE CONSISTENCY ==="
sudo apt-get check 2>&1 | tail -5
echo "upgradable: $(apt list --upgradable 2>/dev/null | grep -c upgradable) packages (run 'sudo apt update' first for fresh count)"

echo ""
echo "=== OOM KILLS (this boot) ==="
journalctl -b --no-pager 2>/dev/null | grep -iE 'out of memory|oom-kill|killed process' | tail -10 || echo "none"

echo ""
echo "=== ZOMBIE PROCESSES ==="
zombies=$(ps -eo stat= 2>/dev/null | grep -c '^Z' || true)
if [ "$zombies" -eq 0 ]; then
    echo "no zombies"
else
    echo "zombies: $zombies"
    ps -eo stat,pid,ppid,comm 2>/dev/null | awk '$1 ~ /^Z/'
fi

echo ""
echo "=== SYSTEMD TIMERS (maintenance, last/next run) ==="
systemctl list-timers --no-pager 2>/dev/null | grep -E 'apt|logrotate|man-db|e2scrub|dpkg|tmpfiles' || true
echo "-- failed/inactive timers --"
systemctl list-timers --all --no-pager 2>/dev/null | awk '$4 ~ /failed|inactive/ {print}' | head -10

echo ""
echo "=== TIME SYNC ==="
timedatectl 2>/dev/null | grep -E 'Local time|Universal|RTC|Time zone|NTP'

echo ""
echo "=== END ==="
} | tee "$OUT" >/dev/null

echo "Diagnostic written to $OUT"
