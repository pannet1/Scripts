# health-check.sh

## Purpose
Daily health check script that verifies all critical services are running. Emails alert to `hosting@ecomsense.in` if any issues detected.

## What it checks

### Services
| Service | Purpose |
|---------|---------|
| nginx | Web server |
| postfix | SMTP mail server |
| dovecot | IMAP/POP3 server |
| mariadb | Database server |
| chrony | Time sync |
| rspamd | Spam filtering |
| redis-server | Cache for Rspamd |
| fail2ban | Intrusion prevention |
| clamav-daemon | Antivirus |

### Ports
| Port | Service |
|------|---------|
| 80 | HTTP |
| 443 | HTTPS |
| 25 | SMTP |
| 587 | Submission |
| 143 | IMAP |
| 993 | IMAPS |
| 995 | POP3S |

### Resources
- Disk usage (< 90%)
- Memory usage (< 90%)
- SSL certificate validity (> 7 days)

## Setup Cron Job

```bash
# Edit crontab
crontab -e

# Add daily check at 6 AM
0 6 * * * /home/carrierc/health-check.sh
```

## Manual Test

```bash
~/health-check.sh
```

## Alert Email
If any check fails, you'll receive an email at `hosting@ecomsense.in` with details of the failure.