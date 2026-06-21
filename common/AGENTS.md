# Global Agent Rules

## Browser Automation (mare-browser-mcp)

A real Chromium browser MCP server is available globally. **Always use these tools** for any web-related task — never run `curl`, `wget`, `playwright`, `puppeteer`, or raw HTTP commands for browsing.

Available tools:
- **`browser_navigate(url, clear_logs?)`** — Navigate to a URL. Pass `clear_logs: true` when starting a new task.
- **`browser_act(commands[])`** — Run actions: `click`, `hover`, `drag`, `fill`, `select`, `keypress`, `wait`, `scrollto`, `clicklink`, `waitfor`, `clearconsole`.
- **`browser_debug(url_filter?, method_filter?, console_types?, last_n?)`** — **Start here on errors.** Returns URL, title, console logs, network requests, dialogs.
- **`browser_query(selector, all?, fields?, visible_only?, limit?, count_only?)`** — Read DOM via CSS selector. Prefer over `browser_screenshot`.
- **`browser_screenshot()`** — **Last resort.** Returns PNG. Only for visual layout issues.
- **`browser_eval(code)`** — Run arbitrary JS in page context (escape hatch).
- **`browser_scroll(direction?, pixels?, selector?, container?)`** — Scroll page or container.
- **`browser_wait_for_network(url_pattern?, method?, timeout?)`** — Wait for specific network response.
- **`browser_upload(selector, files[])`** — Upload files to a file input.
- **`browser_restart(url?)`** — Kill browser and start fresh.
- **`browser_emulate_device(device, orientation?, custom?)`** — Switch to device profile (mobile, tablet).

Workflow: `browser_navigate → browser_act → browser_debug/browser_query → browser_screenshot` (if needed).

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

## OpenBoardView WASM JS API

The WASM build exposes `Module._loadBoardFromMemory(ptr, length)` which takes a pointer/length pair. Use the convenience wrapper:

```javascript
Module.loadBoardFromMemory = function(arrayBuffer) {
  const data = new Uint8Array(arrayBuffer);
  const ptr = Module._malloc(data.length);
  Module.HEAPU8.set(data, ptr);
  const result = Module._loadBoardFromMemory(ptr, data.length);
  Module._free(ptr);
  return result; // 0=success, 1=fail, -1=error
};
```

Usage from SPA at ecomsense.in/schematics:

```javascript
fetch('/path/to/board.brd')
  .then(r => r.arrayBuffer())
  .then(buf => Module.loadBoardFromMemory(buf))
  .then(code => console.log('load result:', code));
```

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
