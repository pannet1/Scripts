#!/bin/bash
# VPS Security Hardening Script
# Run after setup.sh for additional security hardening
# Usage: ./vps_first_run.sh [--skip-sshd-restart]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/tmp/vps_hardening_$(date +%Y%m%d_%H%M%S).log"
SKIP_SSHD_RESTART=false

# Parse arguments
for arg in "$@"; do
    case $arg in
        --skip-sshd-restart)
            SKIP_SSHD_RESTART=true
            ;;
        --help)
            echo "Usage: $0 [--skip-sshd-restart]"
            echo "  --skip-sshd-restart  Skip SSH daemon restart (for testing)"
            exit 0
            ;;
    esac
done

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

backup_file() {
    local file="$1"
    if [ -f "$file" ]; then
        cp "$file" "${file}.bak.$(date +%s)"
        log "Backed up: $file"
    fi
}

echo "=============================================="
echo "  VPS Security Hardening"
echo "=============================================="
echo ""
log "Starting VPS hardening. Log: $LOG_FILE"

# ============================================
# 1. System Updates
# ============================================
log "[1/9] System Updates"

export DEBIAN_FRONTEND=noninteractive
apt-get update -y >> "$LOG_FILE" 2>&1
apt-get upgrade -y >> "$LOG_FILE" 2>&1

# Install unattended-upgrades
apt-get install -y unattended-upgrades apt-listchanges >> "$LOG_FILE" 2>&1

# Enable automatic security updates
cat > /etc/apt/apt.conf.d/50unattended-upgrades << 'EOF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}";
    "${distro_id}:${distro_codename}-security";
    "${distro_id}:${distro_codename}-updates";
};
Unattended-Upgrade::Package-Blacklist {};
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::InstallOnShutdown "false";
Unattended-Upgrade::Mail "root";
Unattended-Upgrade::Automatic-Reboot "false";
EOF

cat > /etc/apt/apt.conf.d/10periodic << 'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOF

log "System updates complete"

# ============================================
# 2. SSH Hardening
# ============================================
log "[2/9] SSH Hardening"

SSHD_CONFIG="/etc/ssh/sshd_config"
SSHD_CONFIG_D="/etc/ssh/sshd_config.d"

backup_file "$SSHD_CONFIG"

# Create SSH hardening config
cat > "$SSHD_CONFIG_D/99-hardening.conf" << 'EOF'
# SSH Hardening Configuration
# ClientAliveInterval: Send keepalive every 120 seconds
# ClientAliveCountMax: Disconnect after 3 failed keepalives
# MaxAuthTries: Allow 3 authentication attempts
# PermitRootLogin: Disabled
# X11Forwarding: Disabled (unless needed)

ClientAliveInterval 120
ClientAliveCountMax 3
MaxAuthTries 3
PermitRootLogin no
X11Forwarding no
AllowTcpForwarding no
AllowStreamLocalForwarding no
PermitEmptyPasswords no
PasswordAuthentication no
EOF

# Validate SSHD config
if sshd -t 2>/dev/null; then
    log "SSH config validated"
else
    log "WARNING: SSH config validation failed"
fi

# Note: SSHD restart deferred until firewall is configured

# ============================================
# 3. Firewall (UFW)
# ============================================
log "[3/9] Firewall Setup"

apt-get install -y ufw >> "$LOG_FILE" 2>&1

# Set defaults
ufw default deny incoming
ufw default allow outgoing

# Allow SSH (default port 22 - will update if changed)
ufw allow ssh

# Allow web traffic
ufw allow http
ufw allow https

# Allow Python app ports
ufw allow 8000/tcp
ufw allow 8001/tcp

# Enable UFW
echo "y" | ufw enable >> "$LOG_FILE" 2>&1

# Enable on boot
systemctl enable ufw >> "$LOG_FILE" 2>&1

log "Firewall enabled with default deny incoming"

# ============================================
# 4. Fail2Ban
# ============================================
log "[4/9] Fail2Ban Setup"

apt-get install -y fail2ban >> "$LOG_FILE" 2>&1

# Create Fail2Ban config
cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
bantime = 3600
findtime = 600
maxretry = 3

[http-get-dos]
enabled = true
port = http,https
filter = http-get-dos
logpath = /var/log/nginx/access.log
maxretry = 300
findtime = 300
bantime = 600
action = iptables-allports
EOF

systemctl enable fail2ban >> "$LOG_FILE" 2>&1
systemctl start fail2ban >> "$LOG_FILE" 2>&1

log "Fail2Ban configured and started"

# ============================================
# 5. Network Security (sysctl)
# ============================================
log "[5/9] Network Security"

# Create sysctl hardening config
cat > /etc/sysctl.d/99-hardening.conf << 'EOF'
# IP Spoofing protection
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Do not accept ICMP redirects (prevent MITM attacks)
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0

# Do not send ICMP redirects
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0

# Ignore ICMP ping requests
net.ipv4.icmp_echo_ignore_all = 0
net.ipv4.icmp_echo_ignore_broadcasts = 1

# Ignore bogus ICMP errors
net.ipv4.icmp_ignore_bogus_error_responses = 1

# Enable SYN cookies (prevent SYN flood attacks)
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_syn_retries = 2
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_max_syn_backlog = 4096

# Increase TCP keepalive
net.ipv4.tcp_keepalive_time = 300
net.ipv4.tcp_keepalive_probes = 5
net.ipv4.tcp_keepalive_intvl = 15

# Kernel hardening
kernel.exec-shield = 1
kernel.randomize_va_space = 2
EOF

# Apply sysctl settings
sysctl -p /etc/sysctl.d/99-hardening.conf >> "$LOG_FILE" 2>&1

log "Network security settings applied"

# ============================================
# 6. Service Hardening (Time)
# ============================================
log "[6/9] Service Hardening"

# Install and configure chrony
apt-get install -y chrony >> "$LOG_FILE" 2>&1

# Set timezone
timedatectl set-timezone Asia/Kolkata

# Configure chrony
cat > /etc/chrony/chrony.conf << 'EOF'
pool time.google.com iburst
pool 0.debian.pool.ntp.org iburst
pool 1.debian.pool.ntp.org iburst
pool 2.debian.pool.ntp.org iburst

# Allow larger step adjustments
maxdistance 30.0

# Record the rate at which the system gains/losses time
driftfile /var/lib/chrony/chrony/drift

# Update hardware clock
rtcsync

# Step the system clock if offset is larger than 1 second
makestep 1.0 -1

# Serve time even if not synchronized
local stratum 10
EOF

systemctl enable chrony >> "$LOG_FILE" 2>&1
systemctl restart chrony >> "$LOG_FILE" 2>&1

log "Time synchronization configured (Asia/Kolkata)"

# ============================================
# 7. File System Security
# ============================================
log "[7/9] File System Security"

# Set umask for new files
echo "umask 027" >> /etc/profile
echo "umask 027" >> /etc/login.defs

# Configure /tmp with security options
if ! grep -q "/tmp" /etc/fstab 2>/dev/null; then
    cat >> /etc/fstab << 'EOF'

# Secure /tmp partition
tmpfs /tmp tmpfs defaults,rw,nosuid,nodev,noexec,mode=1777 0 0
EOF
    log "Added secure /tmp mount to fstab"
fi

# Disable core dumps
echo "* hard core 0" >> /etc/security/limits.conf
echo "* soft core 0" >> /etc/security/limits.conf
echo "ulimit -c 0" >> /etc/profile

# Secure /proc
if ! grep -q "hidepid=2" /etc/fstab 2>/dev/null; then
    cat >> /etc/fstab << 'EOF'

# Secure /proc
proc /proc proc defaults,hidepid=2 0 0
EOF
    log "Added secure /proc mount"
fi

log "File system security configured"

# ============================================
# 8. Log Security
# ============================================
log "[8/9] Log Security"

# Configure logrotate
cat > /etc/logrotate.d/vps-hardening << 'EOF'
/var/log/wtmp {
    weekly
    rotate 4
    create 0664 root utmp
    minsize 1M
    notifempty
}

/var/log/btmp {
    weekly
    rotate 4
    create 0660 root utmp
    minsize 1M
    notifempty
    missingok
}
EOF

# Protect log files
chmod 640 /var/log/*.log 2>/dev/null || true
chmod 640 /var/log/auth.log 2>/dev/null || true

log "Log security configured"

# ============================================
# 9. Kernel Hardening (additional)
# ============================================
log "[9/9] Kernel Hardening"

# Add additional kernel hardening
cat >> /etc/sysctl.d/99-hardening.conf << 'EOF'

# Disable compalient IPv6 (if not needed)
# net.ipv6.conf.all.disable_ipv6 = 1
# net.ipv6.conf.default.disable_ipv6 = 1

# Enable ASLR
kernel.randomize_va_space = 2

# Disable loading of unused kernel modules
install cramfs /bin/true
install freevxfs /bin/true
install jffs2 /bin/true
install hfs /bin/true
install hfsplus /bin/true
install squashfs /bin/true
install udf /bin/true
install vfat /bin/true
EOF

sysctl -p /etc/sysctl.d/99-hardening.conf >> "$LOG_FILE" 2>&1

log "Kernel hardening applied"

# ============================================
# Restart SSH and Final Steps
# ============================================
log "Finalizing configuration"

if [ "$SKIP_SSHD_RESTART" = false ]; then
    systemctl restart sshd
    log "SSH daemon restarted"
else
    log "SKIPPED: SSH daemon restart (--skip-sshd-restart)"
fi

# Apply new /tmp mount without reboot
if mount | grep -q "/tmp"; then
    mount -o remount /tmp 2>/dev/null || true
fi

# Final status
echo ""
echo "=============================================="
echo "  Hardening Complete!"
echo "=============================================="
echo ""
log "All hardening steps completed"
log "Log file: $LOG_FILE"
echo ""
echo "IMPORTANT:"
echo "1. Test SSH connection in a NEW window before closing this one"
echo "2. Your new SSH settings:"
echo "   - Root login: DISABLED"
echo "   - Password auth: DISABLED (key-only)"
echo "   - Idle timeout: 6 minutes"
echo ""
echo "If anything breaks, restore from backup:"
echo "  cp /etc/ssh/sshd_config.bak.* /etc/ssh/sshd_config"
echo ""
