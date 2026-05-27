# VPS Setup & Health Check

Run locally to provision a remote Debian VPS via password SSH.

## Usage

```bash
./vps-setup.sh user ip password
```

| Step | What it does |
|------|-------------|
| 1 | System updates + unattended-upgrades |
| 2 | Timezone Asia/Kolkata + chrony time sync |
| 3 | UFW firewall (SSH, HTTP, HTTPS, 8000, 8001) |
| 4 | SSH hardening (disable root, keep password auth) |
| 5 | Fail2Ban (SSH protection) |
| 6 | Log rotation & permissions |
| 7 | Health check (services, disk, memory, uptime) |

Requires `sshpass` (auto-installed if missing).
