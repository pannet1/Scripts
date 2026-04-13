# web-status.sh

## Purpose
Shows currently configured websites and their status (nginx, python/fastapi).

## What it displays

### Nginx Config Locations
- Main config: `/etc/nginx/nginx.conf`
- Site configs: `/etc/nginx/sites-available/`
- Enabled sites: `/etc/nginx/sites-enabled/`

### Nginx Sites
Shows all configured sites with:
- Server name
- Listen ports (80/443)
- SSL certificate paths
- Document root

### Python/FastAPI Apps
- Location: `/var/www/`
- Running processes (gunicorn, uvicorn, fastapi)
- systemd services

### Network Ports
- Shows what's listening on ports 80, 443, 8000

## Example Setup

| Site | Config | Root |
|------|--------|------|
| example.com | /etc/nginx/sites-available/example.com.conf | /var/www/example.com |

| Port | Service |
|------|---------|
| 80 | HTTP |
| 443 | HTTPS |
| 587 | SMTP |
| 993 | IMAPS |

## Key Files
| File | Purpose |
|------|---------|
| /etc/nginx/nginx.conf | Main nginx config |
| /etc/nginx/sites-available/ | Available site configs |
| /etc/nginx/sites-enabled/ | Enabled sites (symlinks) |
| /etc/ssl/ | SSL certificates |
| /var/www/ | Web root directory |

## Usage
```bash
~/web-status.sh
```