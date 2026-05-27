#!/bin/bash
# VPS Setup & Health Check — run from local machine to provision a remote VPS
# Usage: ./vps-setup.sh [--dry-run] <user> <ip> <password>

set -euo pipefail

DRY_RUN=false
if [ "${1:-}" = "--dry-run" ]; then
    DRY_RUN=true
    shift
fi

USER="${1:-}"
IP="${2:-}"
PASSWORD="${3:-}"

if [ -z "$USER" ] || [ -z "$IP" ] || [ -z "$PASSWORD" ]; then
    echo "Usage: $0 [--dry-run] <user> <ip> <password>"
    echo "  user     - SSH username (e.g. root, uma)"
    echo "  ip       - server IP address"
    echo "  password - SSH password"
    exit 1
fi

TARGET="$USER@$IP"

echo "=== VPS Setup & Health Check ==="
echo "Target: $TARGET"
echo ""

if [ "$DRY_RUN" = true ]; then
    echo "[DRY RUN] No changes will be made"

    cat << 'DRY'

  Step 1/7: System Updates
    - apt-get update
    - apt-get install unattended-upgrades apt-listchanges

  Step 2/7: Timezone & Time Sync
    - timedatectl set-timezone Asia/Kolkata
    - apt-get install chrony
    - systemctl enable && restart chrony

  Step 3/7: UFW Firewall
    - apt-get install ufw
    - ufw default deny incoming
    - ufw default allow outgoing
    - ufw allow ssh
    - ufw allow http
    - ufw allow https
    - ufw allow 8000/tcp
    - ufw allow 8001/tcp
    - ufw enable

  Step 4/7: SSH Hardening
    - Backup /etc/ssh/sshd_config
    - Write /etc/ssh/sshd_config.d/99-hardening.conf
      - PermitRootLogin no
      - PasswordAuthentication (unchanged, keep enabled)
      - ClientAliveInterval 120
      - MaxAuthTries 3
      - X11Forwarding no

  Step 5/7: Fail2Ban
    - apt-get install fail2ban
    - Write /etc/fail2ban/jail.local (SSH jail, 3 retries, 1h ban)
    - systemctl enable && start fail2ban

  Step 6/7: Log Security
    - Write /etc/logrotate.d/vps-hardening
    - chmod 640 /var/log/*.log

  Step 7/7: Health Check
    - Show service status, firewall, disk, memory, uptime
DRY
    echo ""
fi

if ! command -v sshpass &>/dev/null; then
    if [ "$DRY_RUN" = true ]; then
        echo "[DRY RUN] Would install: apt-get install sshpass"
    else
        echo "Installing sshpass..."
        sudo apt-get install -y sshpass >/dev/null 2>&1
    fi
fi

SSH_CMD=(sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10)

if [ "$DRY_RUN" = true ]; then
    echo "[DRY RUN] Would connect: ${SSH_CMD[*]} $TARGET"
    echo ""
    echo "--- Remote Health Check (dry run) ---"
    "${SSH_CMD[@]}" "$TARGET" "bash -s" << 'DRYCHECK'
echo "  Target: $(hostname) ($(uname -r))"
echo ""
echo "--- Services ---"
for svc in chrony fail2ban; do
    if systemctl is-active --quiet "$svc" 2>/dev/null; then
        echo "  ✓ $svc running"
    else
        echo "  ✗ $svc not running"
    fi
done
echo ""
echo "--- Disk ---"
df -h / | tail -1 | awk '{print "  Usage: " $5 " of " $2}'
echo ""
echo "--- Memory ---"
free -h | grep Mem | awk '{print "  Used: " $3 " / " $2}'
echo ""
echo "--- Uptime ---"
uptime -p | sed 's/^up/Uptime:/'
DRYCHECK
    exit 0
fi

# Check SSH access
if ! "${SSH_CMD[@]}" "$TARGET" "echo OK" &>/dev/null; then
    echo "Cannot connect to $TARGET"
    exit 1
fi

# Run remote setup + health check
"${SSH_CMD[@]}" "$TARGET" "bash -s" << 'REMOTESCRIPT'
set -euo pipefail

LOG_FILE="/tmp/vps-setup_$(date +%Y%m%d_%H%M%S).log"

log() { echo "[$(date "+%Y-%m-%d %H:%M:%S")] $1" | tee -a "$LOG_FILE"; }

backup_file() {
    if [ -f "$1" ]; then
        sudo cp "$1" "${1}.bak.$(date +%s)"
        log "Backed up: $1"
    fi
}

echo "=============================================="
echo "  VPS Setup & Health Check"
echo "=============================================="
echo ""

# --- Step 1: System Updates ---
echo "--- Step 1/7: System Updates ---"
log "Updating packages and installing unattended-upgrades..."
export DEBIAN_FRONTEND=noninteractive
sudo apt-get update -y >> "$LOG_FILE" 2>&1
sudo apt-get install -y unattended-upgrades apt-listchanges >> "$LOG_FILE" 2>&1
log "Done"

# --- Step 2: Timezone & Time Sync ---
echo ""
echo "--- Step 2/7: Timezone & Time Sync ---"
log "Setting timezone to Asia/Kolkata..."
sudo timedatectl set-timezone Asia/Kolkata
log "Installing chrony..."
if ! command -v chronyd &>/dev/null; then
    sudo apt-get install -y chrony >> "$LOG_FILE" 2>&1
fi
sudo systemctl enable chrony >> "$LOG_FILE" 2>&1
sudo systemctl restart chrony >> "$LOG_FILE" 2>&1
log "Done"

# --- Step 3: UFW Firewall ---
echo ""
echo "--- Step 3/7: UFW Firewall ---"
log "Installing and configuring UFW..."
sudo apt-get install -y ufw >> "$LOG_FILE" 2>&1
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow http
sudo ufw allow https
sudo ufw allow 8000/tcp
sudo ufw allow 8001/tcp
echo "y" | sudo ufw enable >> "$LOG_FILE" 2>&1
sudo systemctl enable ufw >> "$LOG_FILE" 2>&1
log "Done"

# --- Step 4: SSH Hardening ---
echo ""
echo "--- Step 4/7: SSH Hardening ---"
log "Hardening SSH (disable root, keep password auth)..."
backup_file "/etc/ssh/sshd_config"
sudo tee /etc/ssh/sshd_config.d/99-hardening.conf > /dev/null << 'ENDCONF'
ClientAliveInterval 120
ClientAliveCountMax 3
MaxAuthTries 3
PermitRootLogin no
X11Forwarding no
AllowTcpForwarding no
AllowStreamLocalForwarding no
PermitEmptyPasswords no
ENDCONF
log "Done"

# --- Step 5: Fail2Ban ---
echo ""
echo "--- Step 5/7: Fail2Ban ---"
log "Installing and configuring Fail2Ban..."
sudo apt-get install -y fail2ban >> "$LOG_FILE" 2>&1
sudo tee /etc/fail2ban/jail.local > /dev/null << 'ENDJAIL'
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
ENDJAIL
sudo systemctl enable fail2ban >> "$LOG_FILE" 2>&1
sudo systemctl start fail2ban >> "$LOG_FILE" 2>&1
log "Done"

# --- Step 6: Log Security ---
echo ""
echo "--- Step 6/7: Log Security ---"
log "Setting up log rotation and permissions..."
sudo tee /etc/logrotate.d/vps-hardening > /dev/null << 'ENDLOG'
/var/log/wtmp { weekly; rotate 4; create 0664 root utmp; minsize 1M; notifempty; }
/var/log/btmp { weekly; rotate 4; create 0660 root utmp; minsize 1M; notifempty; missingok; }
ENDLOG
sudo chmod 640 /var/log/*.log 2>/dev/null || true
log "Done"

# --- Step 7: Health Check ---
echo ""
echo "--- Step 7/7: Health Check ---"
echo "=============================================="
echo "  Server Health Check - $(date)"
echo "=============================================="
echo ""

check_service() {
    if systemctl is-active --quiet "$1" 2>/dev/null; then
        echo "  ✓ $1 running"
    else
        echo "  ✗ $1 FAILED"
    fi
}

echo "--- Services ---"
check_service chrony
check_service fail2ban
echo ""

echo "--- Firewall ---"
sudo ufw status verbose | head -10
echo ""

echo "--- Disk Space ---"
df -h / | tail -1 | awk '{print "  Usage: " $5 " of " $2}'
echo ""

echo "--- Memory ---"
free -h | grep Mem | awk '{print "  Used: " $3 " / " $2}'
echo ""

echo "--- Uptime ---"
uptime -p | sed 's/^up/Uptime:/'
echo ""

echo "=============================================="
echo "  Setup Complete!"
echo "=============================================="
echo "Log: $LOG_FILE"
echo ""
echo "Test SSH in a NEW window before closing this one!"
REMOTESCRIPT
