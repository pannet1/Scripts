# VPS First Run - Security Hardening

## Purpose
This script runs after initial VPS setup (minimal debian installation trixie) to harden security on a Debian server.

## Prerequisites
- Fresh Debian installation
- Root/sudo access
- Non-root user with sudo privileges created

## Security Measures

### 1. System Updates
- [ ] Update all packages to latest versions
- [ ] Enable automatic security updates

### 3. SSH Hardening
- [ ] Disable root login
- [ ] Set idle timeout

### 4. Firewall (UFW)
- [ ] Install UFW
- [ ] Default deny incoming
- [ ] Default allow outgoing
- [ ] Allow SSH (with custom port if changed)
- [ ] Allow HTTP/HTTPS
- [ ] Allow Ports 8000, 8001
- [ ] Enable UFW

### 5. Fail2Ban
- [ ] Install fail2ban
- [ ] Configure SSH protection
- [ ] Set ban/retry parameters
- [ ] Enable and start service

### 6. Network Security
- [ ] Disable ICMP broadcast
- [ ] Disable ICMP redirect
- [ ] Enable SYN cookies
- [ ] Configure sysctl network parameters

### 7. Service Hardening
- [ ] Install NTP/chrony
- [ ] Set Timezone to Asia/Kolkotta (+5:30)

### 8. File System Security
- [ ] Set sticky bit on /tmp
- [ ] Mount /tmp with noexec,nosuid,nodev options
- [ ] Restrict core dumps
- [ ] Secure /proc
- [ ] Set appropriate umask

### 9. Log Security
- [ ] Configure rsyslog
- [ ] Set up logrotate
- [ ] Protect log files

### 10. Package Security
- [ ] Configure unattended-upgrades

### 11. Kernel Hardening
- [ ] Configure sysctl parameters
- [ ] Enable ASLR

## Implementation Order
1. System updates
2. SSH hardening (keep connection open!)
3. Firewall setup
4. Fail2Ban
5. Network sysctl settings
6. User & permission hardening
7. Service cleanup
8. File system hardening
9. Security tools installation
10. Monitoring setup

## Safety Notes
- **Always keep an SSH session open** while making changes
- Test changes before disconnecting
- Have console/emergency access ready
- Backup configs before modifying

## Rollback Plan
- Keep original config files backed up
