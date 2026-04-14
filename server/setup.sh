#!/bin/bash
# Server Setup Script
# Run as root or with sudo

set -e

echo "=========================================="
echo "   Server Setup - Interactive Mode"
echo "=========================================="
echo ""

# Prompt for mode
read -p "Run setup interactively? (y/n, default: n): " INTERACTIVE
INTERACTIVE=${INTERACTIVE:-n}

if [[ "$INTERACTIVE" != "y" && "$INTERACTIVE" != "Y" ]]; then
    echo ""
    echo "Running in unattended mode - skipping prompts."
    echo "All components will be installed."
    echo ""
    INTERACTIVE="n"
fi

install_component() {
    local name="$1"
    if [[ "$INTERACTIVE" == "y" ]]; then
        read -p "Install $name? (y/n, default: y): " choice
        choice=${choice:-y}
        [[ "$choice" != "y" && "$choice" != "Y" ]] && return 1
    fi
    return 0
}

echo "=== Server Setup Starting ==="

# 1. Basic Tools
if install_component "Basic Tools (vim-nox, ufw, fail2ban)"; then
    echo "[1/8] Installing basic tools..."
    apt update
    apt install -y vim-nox ufw fail2ban curl wget gnupg2 lsb-release
fi

# 2. Hostname Setup
if install_component "Hostname configuration"; then
    echo "[2/8] Setting hostname..."
    read -p "Enter hostname: " HOSTNAME
    echo "$HOSTNAME" > /etc/hostname
    sed -i "s/127.0.1.*/127.0.1\t$HOSTNAME/" /etc/hosts
    hostnamectl set-hostname "$HOSTNAME"
fi

# 3. Time Sync (chrony)
if install_component "Time sync (chrony)"; then
    echo "[3/8] Installing chrony for time sync..."
    apt install -y chrony
    systemctl enable chrony
    systemctl start chrony
fi

# 4. Mail Server - Postfix + Dovecot + MariaDB
if install_component "Mail Server (Postfix, Dovecot, MariaDB)"; then
    echo "[4/8] Installing mail server packages..."
    apt install -y postfix postfix-mysql postfix-doc mariadb-client mariadb-server \
        openssl getmail6 rkhunter binutils dovecot-imapd dovecot-pop3d \
        dovecot-mysql dovecot-sieve dovecot-lmtpd sudo curl rsyslog
fi

# 5. Spam Filter (Rspamd) + Antivirus (ClamAV) + Redis
if install_component "Spam Filter (Rspamd) + Antivirus (ClamAV)"; then
    echo "[5/8] Installing Rspamd, Redis and ClamAV..."

    # Rspamd repo
    CODENAME=$(lsb_release -c -s)
    wget -qO- https://rspamd.com/apt-stable/gpg.key | tee /etc/apt/trusted.gpg.d/rspamd.asc > /dev/null
    echo "deb [arch=amd64] http://rspamd.com/apt-stable/ $CODENAME main" > /etc/apt/sources.list.d/rspamd.list

    apt update
    apt install -y redis-server rspamd clamav clamav-daemon unzip bzip2 arj nomarch lzop \
        cabextract p7zip p7zip-full unrar-free lrzip apt-listchanges \
        libnet-ldap-perl libauthen-sasl-perl clamav-docs daemon \
        libio-string-perl libio-socket-ssl-perl libnet-ident-perl zip \
        libnet-dns-perl libdbd-mysql-perl postgrey

    # Configure Rspamd
    echo 'servers = "127.0.0.1";' > /etc/rspamd/local.d/redis.conf
    cat > /etc/rspamd/local.d/history_redis.conf << 'EOF'
nrows = 2500;
compress = true;
subject_privacy = true;
EOF

    systemctl enable rspamd redis-server clamav-daemon clamav-freshclam
    systemctl restart rspamd redis-server clamav-daemon clamav-freshclam
fi

# 6. SSL Certificates
if install_component "SSL Certificates (acme.sh)"; then
    echo "[6/8] Setting up SSL certificates (acme.sh)..."
    curl https://get.acme.sh | sh -s
    ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
fi

# 7. Web Server (Nginx)
if install_component "Web Server (Nginx)"; then
    echo "[7/8] Installing Nginx..."
    apt install -y nginx
fi

# 8. Swap Setup (2GB)
if install_component "Swap (2GB)"; then
    echo "[8/8] Setting up 2GB swap..."
    if [ ! -f /swapfile ]; then
        fallocate -l 2G /swapfile 2>/dev/null || dd if=/dev/zero of=/swapfile bs=1M count=2048
        chmod 600 /swapfile
        mkswap /swapfile
        swapon /swapfile
        echo '/swapfile none swap sw 0 0' >> /etc/fstab
    else
        echo "Swap file already exists, skipping..."
    fi
fi

echo ""
echo "=========================================="
echo "   Setup Complete!"
echo "=========================================="
echo "Next steps:"
echo "  1. Secure MariaDB: mysql_secure_installation"
echo "  2. Configure Postfix: /etc/postfix/main.cf"
echo "  3. Configure Dovecot: /etc/dovecot/dovecot.conf"
echo "  4. Enable Firewall: ufw enable"
echo "  5. Create mail users (see mail-config.sh)"
echo "  6. Create website configs in /etc/nginx/sites-available/"