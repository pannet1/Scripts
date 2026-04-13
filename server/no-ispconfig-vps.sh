#!/bin/bash
set -e

HOSTNAME="staticip.ecomsense.in"
EMAIL="admin@ecomsense.in"
DOMAIN="ecomsense.in"
FASTAPI_PORT=8000

echo "=== Updating system ==="
apt update && apt upgrade -y

echo "=== Installing core packages ==="
apt install -y curl wget git certbot python3-certbot-nginx software-properties-common ufw

echo "=== Setting hostname ==="
hostnamectl set-hostname "$HOSTNAME"
echo "$HOSTNAME" > /etc/hostname
sed -i "s/^127.0.1.1.*/127.0.1.1 $HOSTNAME/" /etc/hosts

echo "=== Creating system user ==="
read -p "Enter username (leave blank to skip): " -r
if [[ -n "$REPLY" ]]; then
    adduser "$REPLY"
    usermod -aG sudo "$REPLY"
fi

echo "=== Configuring firewall ==="
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow "$FASTAPI_PORT"/tcp
ufw --force enable
ufw status

# PostgreSQL removed (use if needed later with: apt install -y postgresql postgresql-contrib)

echo "=== Installing Postfix (Mail Server) ==="
debconf-set-selections <<< "postfix postfix/main_mailer_type select Internet Site"
debconf-set-selections <<< "postfix postfix/mail_name string $DOMAIN"
apt install -y postfix postfix-mysql postfix-ldap postfix-cdb postfix-pcre
systemctl enable postfix

echo "=== Installing Dovecot ==="
apt install -y dovecot-core dovecot-imapd dovecot-pop3d dovecot-lmtp dovecot-mysql
sed -i 's/#listen = .*/listen = */' /etc/dovecot/dovecot.conf
systemctl enable dovecot

echo "=== Installing Fail2Ban ==="
apt install -y fail2ban
systemctl enable fail2ban

echo "=== Installing Nginx with Reverse Proxy ==="
apt install -y nginx
systemctl enable nginx

echo "=== Creating Nginx config for FastAPI ==="
cat > /etc/nginx/sites-available/fastapi <<EOF
server {
    listen 80;
    server_name $HOSTNAME;

    location / {
        proxy_pass http://127.0.0.1:$FASTAPI_PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF
ln -sf /etc/nginx/sites-available/fastapi /etc/nginx/sites-enabled/
nginx -t

echo "=== Setup complete! ==="
echo ""
echo "Services installed:"
echo "  - SSH (port 22) - for SFTP file transfers & server access"
echo "  - Nginx (port 80/443) - web server & reverse proxy"
echo "  - Postfix - SMTP mail server"
echo "  - Dovecot (ports 993/995) - IMAP/POP3"
echo "  - Fail2Ban - brute-force protection"
echo "  - UFW firewall"
echo ""
echo "=== Next steps ==="
echo "1. Point your domain DNS A records to this server's IP"
echo "2. Run: certbot --nginx -d $DOMAIN -d www.$DOMAIN"
echo "3. Configure mail users in Postfix/Dovecot"
echo "4. Start services: systemctl start postfix dovecot nginx"
echo "5. Enable mail ports in UFW if needed: ufw allow 25,465,587,993,995/tcp"
echo ""
echo "=== File access ==="
echo "Use SFTP (port 22) with any SFTP client - no pure-ftpd needed!"