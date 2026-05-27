# VPS Setup & Health Check

| Step | What it does |
|------|-------------|
| 1 | System updates + unattended-upgrades |
| 2 | Timezone Asia/Kolkata + chrony time sync |
| 3 | UFW firewall (SSH, HTTP, HTTPS, 8000, 8001) |
| 4 | SSH hardening (disable root, keep password auth) |
| 5 | Fail2Ban (SSH protection, 3 retry ban) |
| 6 | Log rotation & permissions |
| 7 | Health check (services, disk, memory, uptime) |

## Usage

```bash
sudo ./vps-setup.sh
```

SSH hardening takes effect after restart. Test in a new window first.
