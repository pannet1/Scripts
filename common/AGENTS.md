# Global Agent Rules

## Cron Setup for Systemd Services

When setting up cron to start/stop systemd services:

1. **Use direct systemctl path**: `/usr/bin/systemctl` works from user cron without sudo (systemd socket is accessible)

2. **Python wrapper script** (`factory/cron.py`):
```python
import subprocess
import sys
import os

os.chdir("/path/to/your/project")
action = sys.argv[1] if len(sys.argv) > 1 else "start"

CMD = ["/usr/bin/systemctl", action, "your-service.service"]
result = subprocess.run(CMD, capture_output=True, text=True)

with open("data/cron.txt", "a") as f:
    f.write(f"[{action}] {result.returncode} stdout:{result.stdout} stderr:{result.stderr}\n")
```

3. **Cron entries**:
```
14 9 * * 1-5 /usr/bin/python3 /path/to/project/factory/cron.py start >> /path/to/project/data/cron.txt 2>&1
31 15 * * 1-5 /usr/bin/python3 /path/to/project/factory/cron.py stop >> /path/to/project/data/cron.txt 2>&1
```

## General Rules

- Always make code changes locally and push to Git, then pull on server
- Use full paths for commands
- Test any script execution manually before relying on cron
- Check `data/cron.txt` for cron output/logging

## SSH Connection Multiplexing

For faster SSH connections (no re-authentication on each connect), use connection multiplexing.

### Client Setup (Local Machine / WSL)

1. Create socket directory:
```bash
mkdir -p ~/.ssh/sockets
chmod 700 ~/.ssh/sockets
```

2. Add to `~/.ssh/config`:
```
Host *
    ControlMaster auto
    ControlPath ~/.ssh/sockets/%r@%h-%p
    ControlPersist 600
```

### Server Setup (VPS/Remote)

Add to `/etc/ssh/sshd_config`:
```
ClientAliveInterval 60
ClientAliveCountMax 10
```

Then restart SSH:
```bash
sudo systemctl restart sshd
```

### Notes
- `ControlPersist 600`: Keeps connection alive for 10 minutes (client side)
- `ClientAliveCountMax 10`: Server allows 10 x 60s = 10 min idle time
- SSH multiplexing reuses the same connection for multiple sessions

## Custom Commands

### sshd_increase_timeout

When you have SSH access to a VPS, run this to increase server-side SSH timeouts:

```bash
# Check current settings
grep -i clientalive /etc/ssh/sshd_config

# Apply new settings
echo -e "ClientAliveInterval 60\nClientAliveCountMax 10" | sudo tee -a /etc/ssh/sshd_config

# Restart SSH service
sudo systemctl restart sshd

# Verify
grep -i clientalive /etc/ssh/sshd_config
```
