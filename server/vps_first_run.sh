#!/bin/bash
echo "=============================================="
echo "  VPS Security Hardening"
echo "=============================================="
echo ""

LOG_FILE="/tmp/vps_hardening_$(date +%Y%m%d_%H%M%S).log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

backup_file() {
    if [ -f "$1" ]; then
        cp "$1" "${1}.bak.$(date +%s)"
        log "Backed up: $1"
    fi
}

# Check key-based SSH access
log "Checking SSH key-based authentication..."
if [ -f "$HOME/.ssh/authorized_keys" ] && [ -s "$HOME/.ssh/authorized_keys" ]; then
    log "authorized_keys found"
else
    echo "ERROR: Key-based SSH not configured!"
    echo "Run: ssh-copy-id user@server-ip"
    exit 1
fi

# ============================================
# 1. System Updates
# ============================================
echo "--- Step 1/9: System Updates ---"
echo "  Update packages, install unattended-upgrades"
select yn in "Yes" "No"; do
    case $yn in
        Yes )
            log "[1/9] System Updates"
            export DEBIAN_FRONTEND=noninteractive
            apt-get update -y >> "$LOG_FILE" 2>&1
            apt-get install -y unattended-upgrades apt-listchanges >> "$LOG_FILE" 2>&1
            
            cat > /etc/apt/apt.conf.d/50unattended-upgrades << 'EOF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}";
    "${distro_id}:${distro_codename}-security";
    "${distro_id}:${distro_codename}-updates";
};
Unattended-Upgrade::Package-Blacklist {};
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";
EOF
            log "Done"
            break;;
        No ) break;;
    esac
done

# ============================================
# 2. SSH Hardening
# ============================================
echo ""
echo "--- Step 2/9: SSH Hardening ---"
echo "  Disable root login, password auth, set timeout"
select yn in "Yes" "No"; do
    case $yn in
        Yes )
            log "[2/9] SSH Hardening"
            backup_file "/etc/ssh/sshd_config"
            
            cat > /etc/ssh/sshd_config.d/99-hardening.conf << 'EOF'
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
            log "Done"
            break;;
        No ) break;;
    esac
done

# ============================================
# 3. Firewall
# ============================================
echo ""
echo "--- Step 3/9: Firewall ---"
echo "  UFW: deny incoming, allow SSH/HTTP/HTTPS/8000/8001"
select yn in "Yes" "No"; do
    case $yn in
        Yes )
            log "[3/9] Firewall Setup"
            apt-get install -y ufw >> "$LOG_FILE" 2>&1
            ufw default deny incoming
            ufw default allow outgoing
            ufw allow ssh
            ufw allow http
            ufw allow https
            ufw allow 8000/tcp
            ufw allow 8001/tcp
            echo "y" | ufw enable >> "$LOG_FILE" 2>&1
            systemctl enable ufw >> "$LOG_FILE" 2>&1
            log "Done"
            break;;
        No ) break;;
    esac
done

# ============================================
# 4. Fail2Ban
# ============================================
echo ""
echo "--- Step 4/9: Fail2Ban ---"
echo "  SSH and HTTP protection"
select yn in "Yes" "No"; do
    case $yn in
        Yes )
            log "[4/9] Fail2Ban"
            apt-get install -y fail2ban >> "$LOG_FILE" 2>&1
            
            cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true
port = ssh
logpath = /var/log/auth.log
bantime = 3600
findtime = 600
maxretry = 3
EOF
            systemctl enable fail2ban >> "$LOG_FILE" 2>&1
            systemctl start fail2ban >> "$LOG_FILE" 2>&1
            log "Done"
            break;;
        No ) break;;
    esac
done

# ============================================
# 5. Network Security
# ============================================
echo ""
echo "--- Step 5/9: Network Security ---"
echo "  SYN cookies, ICMP hardening"
select yn in "Yes" "No"; do
    case $yn in
        Yes )
            log "[5/9] Network Security"
            cat > /etc/sysctl.d/99-hardening.conf << 'EOF'
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_syn_retries = 2
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_max_syn_backlog = 4096
net.ipv4.tcp_keepalive_time = 300
net.ipv4.tcp_keepalive_probes = 5
net.ipv4.tcp_keepalive_intvl = 15
kernel.randomize_va_space = 2
EOF
            sysctl -p /etc/sysctl.d/99-hardening.conf >> "$LOG_FILE" 2>&1 || true
            log "Done"
            break;;
        No ) break;;
    esac
done

# ============================================
# 6. Time
# ============================================
echo ""
echo "--- Step 6/9: Time Setup ---"
echo "  chrony, Asia/Kolkata timezone"
select yn in "Yes" "No"; do
    case $yn in
        Yes )
            log "[6/9] Time Setup"
            apt-get install -y chrony >> "$LOG_FILE" 2>&1
            timedatectl set-timezone Asia/Kolkata
            systemctl enable chrony >> "$LOG_FILE" 2>&1
            systemctl restart chrony >> "$LOG_FILE" 2>&1
            log "Done"
            break;;
        No ) break;;
    esac
done

# ============================================
# 7. File System
# ============================================
echo ""
echo "--- Step 7/9: File System Security ---"
echo "  umask, disable core dumps"
select yn in "Yes" "No"; do
    case $yn in
        Yes )
            log "[7/9] File System"
            echo "umask 027" >> /etc/profile
            echo "umask 027" >> /etc/login.defs
            echo "* hard core 0" >> /etc/security/limits.conf
            echo "* soft core 0" >> /etc/security/limits.conf
            log "Done"
            break;;
        No ) break;;
    esac
done

# ============================================
# 8. Log Security
# ============================================
echo ""
echo "--- Step 8/9: Log Security ---"
echo "  logrotate, secure log permissions"
select yn in "Yes" "No"; do
    case $yn in
        Yes )
            log "[8/9] Log Security"
            cat > /etc/logrotate.d/vps-hardening << 'EOF'
/var/log/wtmp { weekly; rotate 4; create 0664 root utmp; minsize 1M; notifempty; }
/var/log/btmp { weekly; rotate 4; create 0660 root utmp; minsize 1M; notifempty; missingok; }
EOF
            chmod 640 /var/log/*.log 2>/dev/null || true
            log "Done"
            break;;
        No ) break;;
    esac
done

# ============================================
# 9. Kernel Hardening
# ============================================
echo ""
echo "--- Step 9/9: Kernel Hardening ---"
echo "  Disable unused modules"
select yn in "Yes" "No"; do
    case $yn in
        Yes )
            log "[9/9] Kernel Hardening"
            cat >> /etc/sysctl.d/99-hardening.conf << 'EOF'
install cramfs /bin/true
install freevxfs /bin/true
install jffs2 /bin/true
install hfs /bin/true
install hfsplus /bin/true
install squashfs /bin/true
install udf /bin/true
install vfat /bin/true
EOF
            sysctl -p /etc/sysctl.d/99-hardening.conf >> "$LOG_FILE" 2>&1 || true
            log "Done"
            break;;
        No ) break;;
    esac
done

# ============================================
# Restart SSH
# ============================================
echo ""
echo "--- Final: Restart SSH ---"
echo "  Apply SSH hardening"
select yn in "Yes" "No"; do
    case $yn in
        Yes )
            systemctl restart sshd
            log "SSH restarted"
            break;;
        No )
            echo "Run manually: sudo systemctl restart sshd"
            break;;
    esac
done

echo ""
echo "=============================================="
echo "  Hardening Complete!"
echo "=============================================="
echo "Log: $LOG_FILE"
echo ""
echo "Test SSH in a NEW window!"
