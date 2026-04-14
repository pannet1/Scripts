#!/bin/bash
# Create a new website with SSL
# Usage: 
#   ./create_website.sh domain.com [www.domain.com]     - Full website with SSL
#   ./create_website.sh --parked domain.com              - Simple parked domain
#   ./create_website.sh --parked domain.com --message "Custom message"

set -e

PARKED=false
MESSAGE="Homepage coming soon"

while [[ $# -gt 0 ]]; do
    case $1 in
        --parked)
            PARKED=true
            shift
            ;;
        --message)
            MESSAGE="$2"
            shift 2
            ;;
        *)
            if [ -z "$DOMAIN" ]; then
                DOMAIN=$1
            elif [ -z "$WWW_DOMAIN" ]; then
                WWW_DOMAIN=$1
            fi
            shift
            ;;
    esac
done

if [ -z "$DOMAIN" ]; then
    echo "Usage: $0 domain.com [www.domain.com]"
    echo "       $0 --parked domain.com [--message 'Custom message']"
    exit 1
fi

WWW_DOMAIN=${WWW_DOMAIN:-www.$DOMAIN}

echo "=== Creating website: $DOMAIN ==="

# 1. Create directories
echo "[1/6] Creating directories..."
mkdir -p /var/www/$DOMAIN
chown -R carrierc:carrierc /var/www/$DOMAIN

# 2. Create default index.html
echo "[2/6] Creating default page..."

if [ "$PARKED" = true ]; then
    cat > /var/www/$DOMAIN/index.html << EOF
<!DOCTYPE html>
<html>
<head>
    <title>$DOMAIN</title>
</head>
<body>
    <h1>$DOMAIN</h1>
    <p>$MESSAGE</p>
</body>
</html>
EOF
else
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
fi

# 3. Issue SSL certificate (skip if parked)
if [ "$PARKED" = true ]; then
    echo "[3/6] Skipping SSL (parked domain)"
else
    echo "[3/6] Issuing SSL certificate..."
    ~/.acme.sh/acme.sh --issue -d $DOMAIN -d $WWW_DOMAIN --webroot /var/www/$DOMAIN --server letsencrypt

    # 4. Copy SSL certificates
    echo "[4/6] Installing SSL certificates..."
    mkdir -p /etc/ssl/$DOMAIN
    cp ~/.acme.sh/${DOMAIN}_ecc/fullchain.cer /etc/ssl/$DOMAIN/fullchain.pem
    cp ~/.acme.sh/${DOMAIN}_ecc/${DOMAIN}.key /etc/ssl/$DOMAIN/key.pem
    chmod 600 /etc/ssl/$DOMAIN/key.pem
fi

# 5. Create nginx config
echo "[5/6] Creating nginx configuration..."

if [ "$PARKED" = true ]; then
    # Simple HTTP-only config for parked domains
    cat > /etc/nginx/sites-available/$DOMAIN.conf << EOF
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN $WWW_DOMAIN;
    root /var/www/$DOMAIN;
    index index.html;
    location / { try_files \$uri \$uri/ =404; }
}
EOF
else
    # Full config with SSL
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
fi

# 6. Enable site and reload nginx
echo "[6/6] Enabling site..."
ln -sf /etc/nginx/sites-available/$DOMAIN.conf /etc/nginx/sites-enabled/
nginx -t && systemctl reload nginx

if [ "$PARKED" = true ]; then
    echo "=== Parked domain $DOMAIN created successfully! ==="
    echo "URL: http://$DOMAIN"
else
    echo "=== Website $DOMAIN created successfully! ==="
    echo "URL: https://$DOMAIN"
fi