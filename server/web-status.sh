#!/bin/bash
echo "=== Nginx Config Location ==="
ls -la /etc/nginx/nginx.conf
ls -la /etc/nginx/sites-available/
ls -la /etc/nginx/sites-enabled/
echo ""
echo "=== Nginx Main Config ==="
grep -E "include|server" /etc/nginx/nginx.conf | head -10
echo ""
echo "=== Nginx Sites Enabled ==="
ls -la /etc/nginx/sites-enabled/
echo ""
echo "=== Nginx Site Configs ==="
for f in /etc/nginx/sites-available/*; do
    if [ -f "$f" ]; then
        echo "--- $(basename $f) ---"
        grep -E "server_name|listen|ssl_certificate|root" "$f" | head -10
    fi
done
echo ""
echo "=== Python/FastAPI App Locations ==="
ls -la /var/www/ 2>/dev/null
echo ""
echo "=== Python/FastAPI Apps Running ==="
ps aux | grep -E "gunicorn|uvicorn|fastapi|python.*app" | grep -v grep
echo ""
echo "=== systemd Services ==="
sudo systemctl list-units --type=service --state=running | grep -E "nginx|gunicorn|uvicorn"
echo ""
echo "=== Port 80/443 Listening ==="
sudo ss -tlnp | grep -E ':(80|443|8000)'