#!/bin/bash
# Mailbox and Alias Configuration Viewer
# Run: ~/mail-config.sh

echo "=== Mailboxes ==="
cat /etc/postfix/vmailboxes
echo ""
echo "=== Aliases ==="
cat /etc/postfix/virtual
echo ""
echo "=== Postfix Config ==="
sudo postconf | grep -E '^virtual_'
echo ""
echo "=== Dovecot Users ==="
sudo cat /etc/dovecot/vmail.passwd