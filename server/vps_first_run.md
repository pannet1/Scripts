# VPS First Run - Security Hardening

## Purpose
This script runs after initial VPS setup (minimal debian installation trixie) to harden security on a Debian server.

## Prerequisites
- Fresh Debian installation
- Non-root user with sudo privileges
- SSH key-based authentication configured

## Security Measures

### 1. System Updates
- [x] Update all packages
- [x] Enable automatic security updates (unattended-upgrades)

### 2. SSH Hardening
- [x] Disable root login
- [x] Disable password authentication (key-only)
- [x] Set idle timeout (120s)
- [x] Limit auth attempts (3)
- [x] Disable TCP forwarding

### 3. Firewall (UFW)
- [x] Install UFW
- [x] Default deny incoming, allow outgoing
- [x] Allow SSH (22), HTTP (80), HTTPS (443)
- [x] Allow custom ports (8000, 8001)
- [x] Enable on boot

### 4. HTTPS Setup (Optional)
- [x] Install nginx
- [x] Self-signed SSL certificate
- [x] Configure HTTPS on port 443

### 5. Fail2Ban
- [x] Install fail2ban
- [x] Configure SSH protection (3 attempts, 1hr ban)
- [x] Enable and start service

### 6. Network Security
- [x] Enable SYN cookies
- [x] Disable ICMP redirects
- [x] IP spoofing protection
- [x] TCP keepalive tuning

### 7. Time Setup
- [x] Install chrony (NTP)
- [x] Set timezone to Asia/Kolkata

### 8. File System Security
- [x] Set umask 027
- [x] Restrict core dumps
- [x] Disable unused filesystem modules

### 9. Log Security
- [x] Configure logrotate
- [x] Secure log file permissions

### 10. Kernel Hardening
- [x] Enable ASLR
- [x] Disable unused kernel modules

## Usage

```bash
# Run locally on server (recommended)
bash ~/Scripts/server/vps_first_run.sh

# Run via SSH with -t for terminal
ssh -t user@server "bash ~/Scripts/server/vps_first_run.sh"
```

## Interactive Prompts
- Uses `select` for Yes/No choices
- Press 1 for Yes, 2 for No
- Each step can be skipped individually

## Key Locations

| Item | Location |
|------|----------|
| SSH hardening | /etc/ssh/sshd_config.d/99-hardening.conf |
| Firewall | /etc/ufw/ |
| Fail2Ban | /etc/fail2ban/jail.local |
| Network sysctl | /etc/sysctl.d/99-hardening.conf |
| SSL cert | /etc/ssl/certs/nginx-selfsigned.crt |
| SSL key | /etc/ssl/private/nginx-selfsigned.key |
| Log | /tmp/vps_hardening_*.log |

## Safety Notes
- Keep an SSH session open while testing
- Test SSH in a NEW window after restart
- Backup files created with .bak.{timestamp}
- Rollback: `cp /etc/ssh/sshd_config.bak.* /etc/ssh/sshd_config`

## Troubleshooting

### Script exits on error
- Some commands may need sudo (already added)
- Check log file for details

### SSH connection closes during script
- Run with `-t` flag
- Or run directly on server terminal

### Permission denied errors
- Ensure user is in sudo group
- All system commands use sudo in script
