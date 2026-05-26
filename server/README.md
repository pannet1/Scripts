# Server Scripts - Index

## Run Once (Initial Setup)

| Script | Description |
|--------|-------------|
| [setup.sh](./setup.md) | Main server setup - installs all packages (nginx, postfix, dovecot, rspamd, clamav, etc.) |

Run after fresh server deployment.

---

## Run On Situation (Manual)

| Script | Description |
|--------|-------------|
| [mail-config.sh](./mail-config.md) | View mailboxes and aliases |
| [web-status.sh](./web-status.md) | Check nginx and web server status |

Run when needed (new website, mail config, troubleshooting).

---

## Run Periodically (Cron)

| Script | Description |
|--------|-------------|
| [health-check.sh](./health-check.md) | Daily health check - emails alert to hosting@ecomsense.in |

Runs daily at **6:00 AM** via cron.

---

## Quick Reference

```bash
# Setup new server
./setup.sh

# View mail config
./mail-config.sh

# View web status
./web-status.sh

# Run health check manually
./health-check.sh

# Check cron
crontab -l
```

## File Locations

| Item | Location |
|------|----------|
| Websites | `/var/www/` |
| SSL Certs | `/etc/ssl/` |
| Nginx Configs | `/etc/nginx/sites-available/` |
| Mail Config | `/etc/postfix/`, `/etc/dovecot/` |
| Scripts | `~/` (home directory) |