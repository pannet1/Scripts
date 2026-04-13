#!/bin/bash
# Create a new website with SSL
# Usage: ./create_website.sh domain.com [www.domain.com]

set -e

if [ -z "$1" ]; then
    echo "Usage: $0 domain.com [www.domain.com]"
    exit 1
fi

DOMAIN=$1
WWW_DOMAIN=${2:-www.$1}

echo "=== Creating website: $DOMAIN ==="

# 1. Create directories
echo "[1/6] Creating directories..."
mkdir -p /var/www/$DOMAIN
chown -R carrierc:carrierc /var/www/$DOMAIN

# 2. Create default index.html
echo "[2/6] Creating default page..."
cat > /var/www/$DOMAIN/index.html << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$DOMAIN</title>
    <style>
        body { font-family: Arial; display: flex; justify-content: center; align-items: center; min-height: 100vh; margin: 0; background: #f0f0f0; }
        .container { text-align: center; padding: 40px; background: white; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1 { color: #333; }
        p { color: #666; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Welcome to $DOMAIN</h1>
        <p>Site is under construction.</p>
    </div>
</body>
</html>
EOF

# 3. Issue SSL certificate
echo "[3/6] Issuing SSL certificate..."
~/.acme.sh/acme.sh --issue -d $DOMAIN -d $WWW_DOMAIN --webroot /var/www/$DOMAIN --server letsencrypt

# 4. Copy SSL certificates
echo "[4/6] Installing SSL certificates..."
mkdir -p /etc/ssl/$DOMAIN
cp ~/.acme.sh/${DOMAIN}_ecc/fullchain.cer /etc/ssl/$DOMAIN/fullchain.pem
cp ~/.acme.sh/${DOMAIN}_ecc/${DOMAIN}.key /etc/ssl/$DOMAIN/key.pem
chmod 600 /etc/ssl/$DOMAIN/key.pem

# 5. Create nginx config
echo "[5/6] Creating nginx configuration..."
cat > /etc/nginx/sites-available/$DOMAIN.conf << EOF
server {
    listen 80;
    server_name $DOMAIN $WWW_DOMAIN;
    root /var/www/$DOMAIN;
    index index.html;
    location / { try_files \$uri \$uri/ =404; }
}

server {
    listen 443 ssl;
    server_name $DOMAIN $WWW_DOMAIN;
    root /var/www/$DOMAIN;
    index index.html;
    ssl_certificate /etc/ssl/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/ssl/$DOMAIN/key.pem;
    location / { try_files \$uri \$uri/ =404; }
}
EOF

# 6. Enable site and reload nginx
echo "[6/6] Enabling site..."
ln -sf /etc/nginx/sites-available/$DOMAIN.conf /etc/nginx/sites-enabled/
nginx -t && systemctl reload nginx

echo "=== Website $DOMAIN created successfully! ==="
echo "URL: https://$DOMAIN"