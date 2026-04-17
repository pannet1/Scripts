#!/bin/bash
# Health Check Script - Run daily via cron
# Emails hosting@ecomsense.in if issues detected

ALERT_EMAIL="hosting@ecomsense.in"
ERRORS=""

check_service() {
    local SERVICE=$1
    if systemctl is-active --quiet "$SERVICE" 2>/dev/null; then
        echo "✓ $SERVICE running"
    else
        echo "✗ $SERVICE FAILED"
        ERRORS="$ERRORS\n$SERVICE is not running"
    fi
}

check_port() {
    local PORT=$1
    local NAME=$2
    if ss -tlnp 2>/dev/null | grep -q ":$PORT "; then
        echo "✓ Port $PORT ($NAME) open"
    else
        echo "✗ Port $PORT ($NAME) closed"
        ERRORS="$ERRORS\nPort $PORT ($NAME) is not listening"
    fi
}

echo "=== Server Health Check - $(date) ==="
echo ""

# Check services
echo "--- Services ---"
check_service nginx
check_service postfix
check_service dovecot
check_service mariadb
check_service chrony
check_service rspamd
check_service redis-server
check_service fail2ban
check_service clamav-daemon
echo ""

# Check ports
echo "--- Ports ---"
check_port 80 "HTTP"
check_port 443 "HTTPS"
check_port 25 "SMTP"
check_port 587 "Submission"
check_port 143 "IMAP"
check_port 993 "IMAPS"
check_port 995 "POP3S"
echo ""

# Check disk space
echo "--- Disk Space ---"
DF_OUTPUT=$(df -h / | tail -1)
USAGE=$(echo "$DF_OUTPUT" | awk '{print $5}' | sed 's/%//')
if [ "$USAGE" -lt 90 ]; then
    echo "✓ Disk usage: ${USAGE}%"
else
    echo "✗ Disk usage: ${USAGE}% (high)"
    ERRORS="$ERRORS\nDisk usage is at ${USAGE}%"
fi
echo ""

# Check memory
echo "--- Memory ---"
FREE_MEM=$(free -m | grep Mem | awk '{print $3}')
TOTAL_MEM=$(free -m | grep Mem | awk '{print $2}')
PERCENT=$((FREE_MEM * 100 / TOTAL_MEM))
if [ "$PERCENT" -lt 70 ]; then
    echo "✓ Memory: ${PERCENT}% used"
else
    echo "✗ Memory: ${PERCENT}% used (high)"
    ERRORS="$ERRORS\nMemory usage is at ${PERCENT}%"
fi
echo ""

# Check SSL certs
echo "--- SSL Certificates ---"
CERT_FOUND=false

# Check domain cert
if [ -f "/etc/ssl/ecomsense.in/fullchain.pem" ]; then
    EXPIRY=$(openssl x509 -in "/etc/ssl/ecomsense.in/fullchain.pem" -noout -enddate 2>/dev/null | cut -d= -f2)
    EXPIRY_EPOCH=$(date -d "$EXPIRY" +%s 2>/dev/null)
    NOW_EPOCH=$(date +%s)
    DAYS_LEFT=$(( (EXPIRY_EPOCH - NOW_EPOCH) / 86400 ))
    echo "✓ SSL cert (ecomsense.in) valid (${DAYS_LEFT} days)"
    CERT_FOUND=true
fi

# Check self-signed cert
if [ -f "/etc/ssl/certs/nginx-selfsigned.crt" ]; then
    EXPIRY=$(openssl x509 -in "/etc/ssl/certs/nginx-selfsigned.crt" -noout -enddate 2>/dev/null | cut -d= -f2)
    EXPIRY_EPOCH=$(date -d "$EXPIRY" +%s 2>/dev/null)
    NOW_EPOCH=$(date +%s)
    DAYS_LEFT=$(( (EXPIRY_EPOCH - NOW_EPOCH) / 86400 ))
    echo "✓ SSL cert (self-signed) valid (${DAYS_LEFT} days)"
    CERT_FOUND=true
fi

if [ "$CERT_FOUND" = false ]; then
    echo "✗ No SSL cert found"
    ERRORS="$ERRORS\nNo SSL certificate found"
fi
echo ""

# Send email if errors
if [ -n "$ERRORS" ]; then
    echo "=== Sending alert email ==="
    echo -e "Server Health Check Failed\n\n$ERRORS\n\n$(date)" | mail -s "⚠️ Server Alert - $(hostname)" "$ALERT_EMAIL"
else
    echo "=== All checks passed ==="
fi