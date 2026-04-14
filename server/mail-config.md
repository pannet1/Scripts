# mail-config.sh

## Purpose
Shows how mailboxes and aliases are configured on the server.

## What it displays
- **Mailboxes**: `/etc/postfix/vmailboxes` - defines where emails are stored
- **Aliases**: `/etc/postfix/virtual` - maps incoming addresses to mailboxes
- **Postfix Config**: Virtual mail settings (uid, gid, mail path)
- **Dovecot Users**: Authentication credentials for IMAP/SMTP

## Mailboxes (example)
- `user1@yourdomain.com` → stored in `/var/vmail/yourdomain.com/user1/`
- `user2@yourdomain.com` → stored in `/var/vmail/yourdomain.com/user2/`

## Aliases (example)
All forward to `user2@yourdomain.com`:
alias1, alias2, alias3, ... (configurable)

## Key Files
| File | Purpose |
|------|---------|
| /etc/postfix/vmailboxes | Mailbox mapping |
| /etc/postfix/virtual | Alias mapping |
| /etc/dovecot/vmail.passwd | Dovecot auth |
| /var/vmail/ | Mail storage directory |

## Important Lessons

### Creating Mailboxes
After adding entries to `vmailboxes` and `virtual`, run:
```bash
sudo postmap /etc/postfix/vmailboxes
sudo postmap /etc/postfix/virtual
sudo systemctl reload postfix
```

### Dovecot Password File
Format per line: `username@domain:password` (plaintext, dovecot handles hashing)
After changes: `sudo systemctl restart dovecot`

### Testing Mail
```bash
# Check mail log
sudo tail -f /var/log/mail.log

# Test SMTP
telnet localhost 25

# Test IMAP
telnet localhost 143
```

## Troubleshooting

### "User doesn't exist" errors
- Ensure `postmap` was run after updating vmailboxes/virtual
- Check postfix logs: `tail /var/log/mail.log`

### IMAP login failures
- Verify dovecot can read the password file
- Check `/etc/dovecot/conf.d/` includes are correct order

## Usage
```bash
~/mail-config.sh
```