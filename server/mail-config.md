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

## Usage
```bash
~/mail-config.sh
```