#!/bin/bash
# Mailbox and Alias Configuration Script
# Shows how 2 mailboxes and 18 aliases are configured

echo "=== Mailboxes (/etc/postfix/vmailboxes) ==="
cat /etc/postfix/vmailboxes

echo ""
echo "=== Virtual Aliases (/etc/postfix/virtual) ==="
cat /etc/postfix/virtual

echo ""
echo "=== Postfix Virtual Mailbox Config ==="
postconf | grep -E '^virtual_'

echo ""
echo "=== Dovecot User Database ==="
cat /etc/dovecot/vmail.passwd