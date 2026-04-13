#!/bin/bash
# Server Setup Script - Based on carrierc's history
# Run as root or with sudo

set -e

echo "=== Server Setup Starting ==="

# 1. Basic Tools
echo "[1/7] Installing basic tools..."
apt update
apt install -y vim-nox ufw fail2ban curl wget gnupg2 lsb-release

# 2. Hostname Setup
echo "[2/7] Setting hostname..."
read -p "Enter hostname: " HOSTNAME
echo "$HOSTNAME" > /etc/hostname
sed -i "s/127.0.1.*/127.0.1\t$HOSTNAME/" /etc/hosts
hostnamectl set-hostname "$HOSTNAME"

# 3. Time Sync (chrony)
echo "[3/7] Installing chrony for time sync..."
apt install -y chrony
systemctl enable chrony
systemctl start chrony

# 4. Mail Server - Postfix + Dovecot + MariaDB
echo "[4/7] Installing mail server packages..."
apt install -y postfix postfix-mysql postfix-doc mariadb-client mariadb-server \
    openssl getmail6 rkhunter binutils dovecot-imapd dovecot-pop3d \
    dovecot-mysql dovecot-sieve dovecot-lmtpd sudo curl rsyslog

# 5. Spam Filter (Rspamd) + Antivirus (ClamAV) + Redis
echo "[5/7] Installing Rspamd, Redis and ClamAV..."

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

# 6. SSL Certificates
echo "[6/7] Setting up SSL certificates (acme.sh)..."
curl https://get.acme.sh | sh -s
~/.acme.sh/acme.sh --set-default-ca --server letsencrypt

# 7. Web Server (Nginx)
echo "[7/7] Installing Nginx..."
apt install -y nginx

# 8. Swap Setup (2GB)
echo "[8/7] Setting up 2GB swap..."
fallocate -l 2G /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=2048
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo '/swapfile none swap sw 0 0' >> /etc/fstab

echo "=== Setup Complete ==="
echo "Next steps:"
echo "  1. Secure MariaDB: mysql_secure_installation"
echo "  2. Configure Postfix: /etc/postfix/main.cf"
echo "  3. Configure Dovecot: /etc/dovecot/dovecot.conf"
echo "  4. Enable Firewall: ufw enable"
echo "  5. Create mail users (see mail-config.sh)"
echo "  6. Create website configs in /etc/nginx/sites-available/"