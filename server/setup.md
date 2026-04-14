# setup.sh

## Purpose
Automated server setup script that replicates carrierc's original setup process.

## What it installs/configures

### 1. Basic Tools
- vim-nox (enhanced vim)
- ufw (firewall)
- fail2ban (intrusion prevention)
- curl, wget, gnupg2, lsb-release

### 2. Hostname
- Sets `/etc/hostname` and `/etc/hosts`

### 3. Time Sync
- chrony (replaces ntp/openntp)

### 4. Mail Server (Postfix + Dovecot + MariaDB)
- postfix with MySQL support
- dovecot (IMAP/POP3)
- mariadb server and client

### 5. Spam & Antivirus
- **Rspamd**: Advanced spam filtering
  - Installs from official repo
  - Configures Redis backend
  - Enables history compression
- **ClamAV**: Antivirus scanner
  - Includes freshclam for auto-updates

### 6. SSL Certificates
- **acme.sh**: Let's Encrypt automation

### 7. Web Server
- **Nginx**: Web server and reverse proxy

### 8. Swap Setup
- **2GB swap file**: For memory management

## Usage

```bash
# Run as root
chmod +x setup.sh
./setup.sh

# Or with sudo
sudo ./setup.sh
```

## Manual Steps After Run

1. **Secure MariaDB**: `mariadb-secure_installation`
2. **Configure Postfix**: Edit `/etc/postfix/main.cf`
3. **Configure Dovecot**: Edit `/etc/dovecot/dovecot.conf`
4. **Configure Rspamd**: Optimize memory settings in `/etc/rspamd/local.d/`
5. **Enable Firewall**: `ufw enable`
6. **Create Mail Users**: See mail-config.sh
7. **Create Website**: Add configs in `/etc/nginx/sites-available/`

## Post-Setup Configuration

### Rspamd Memory Optimization
After first run, restart Rspamd to apply settings:
```bash
systemctl restart rspamd
```

### Mail Configuration
See `mail-config.sh` for creating mailboxes and aliases.

## Key Config Locations

| Service | Config File |
|---------|-------------|
| Postfix | /etc/postfix/main.cf, master.cf |
| Dovecot | /etc/dovecot/dovecot.conf |
| MariaDB | /etc/mysql/mariadb.conf.d/ |
| Rspamd | /etc/rspamd/local.d/ |
| ClamAV | /etc/clamav/ |
| Fail2ban | /etc/fail2ban/jail.local |
| UFW | /etc/ufw/ |

## Notes

- Script uses `set -e` to stop on first error
- Review each step before running
- Some steps require interaction (MariaDB setup)
- UFW is configured but not enabled by default

## Important Lessons Learned

### Dovecot Configuration
- **mail_location** setting must be in `10-mail.conf` or at the very top of `dovecot.conf` **before** `!include` statements
- Parsing issues occur if placed in `conf.d/*.conf` files
- Use `local.conf` or add directly to main config
- After changes: `systemctl restart dovecot`

### Nginx Configuration
- When creating site configs, ensure `try_files` uses proper syntax: `try_files $uri $uri/ =404`
- Missing `$uri/` causes redirect loops (301)
- Disable default site if it conflicts: `rm /etc/nginx/sites-enabled/default`
- After changes: `nginx -t && systemctl reload nginx`