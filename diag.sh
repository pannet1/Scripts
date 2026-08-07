#!/usr/bin/env bash
# System diagnostic — run as: sudo ./diag.sh 2>&1 | tee output.txt
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
dmesg -l err,warn 2>/dev/null | tail -80

echo ""
echo "=== KERNEL MESSAGES — full tail ==="
dmesg 2>/dev/null | tail -60

echo ""
echo "=== KERNEL: nvidia / drm / acpi / firmware ==="
dmesg 2>/dev/null | grep -iE 'nvidia|nouveau|drm|acpi|firmware|aic94xx|edac|mce|ras|thermal' | tail -60

echo ""
echo "=== PREVIOUS BOOT kernel errors (boot -1) ==="
journalctl -k -b -1 -p err --no-pager 2>/dev/null | tail -30

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
journalctl -k --no-pager 2>/dev/null | grep -iE 'panic|oops|bug:|kernel warning|segfault|call trace' | tail -20
grep -iE 'panic|oops|bug|call trace' /var/log/kern.log /var/log/syslog 2>/dev/null | tail -20

echo ""
echo "=== HARDWARE: memory / CPU ==="
lscpu | grep -E 'Model name|CPU\(s\)|MHz|Cache|Architecture'
free -h
dmidecode -t memory 2>/dev/null | grep -E 'Size:|Type:|Speed:|Maximum Capacity|Locator' | grep -v 'No Module' | head -20

echo ""
echo "=== HARDWARE: disks (SMART health) ==="
lsblk -o NAME,SIZE,ROTA,TYPE,MOUNTPOINT,MODEL 2>/dev/null
for disk in $(lsblk -dpno NAME 2>/dev/null | grep -E '^/dev/(sd|nvme)'); do
    echo "--- $disk ---"
    smartctl -H "$disk" 2>/dev/null | grep -E 'SMART overall|SMART Health|result'
    smartctl -A "$disk" 2>/dev/null | grep -iE 'Reallocated|Pending|Uncorrect|Current_Pending' || true
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
    echo "nvidia_drm.$p = $(cat /sys/module/nvidia_drm/parameters/$p 2>&1)"
done
cat /proc/driver/nvidia/params 2>/dev/null
cat /proc/driver/nvidia/gpus/*/information 2>/dev/null | head -20

echo ""
echo "=== HARDWARE: USB / storage errors ==="
dmesg 2>/dev/null | grep -iE 'usb.*(error|fail|reset|unable)|sd [a-z].*(error|fail)|ata[0-9].*(error|fail)' | tail -30

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
dmesg 2>/dev/null | grep -iE 's0ix|suspend|hibernate|acpi.*error|power' | tail -20

echo ""
echo "=== KERNEL MODULE ISSUES ==="
lsmod | grep -iE 'nvidia|nouveau' 
modprobe -n -v nouveau 2>&1
modprobe -n -v vgaarb 2>&1

echo ""
echo "=== SWAP / MEMORY PRESSURE ==="
swapon --show 2>/dev/null || echo "no swap"
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
echo "=== END ==="
} | tee "$OUT" >/dev/null

echo "Diagnostic written to $OUT"
