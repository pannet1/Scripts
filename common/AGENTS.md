# Global Agent Rules

## Browser Automation (mare-browser-mcp)

A real Chromium browser MCP server is available globally. **Always use these tools** for any web-related task — never run `curl`, `wget`, `playwright`, `puppeteer`, or raw HTTP commands for browsing.

### Quickstart

```json
// Already configured in ~/.config/opencode/opencode.jsonc
// Server: mare_browser_mcp (global via bun)
```

### When to use each tool

| Step | Tool | When |
|------|------|------|
| 1 | `browser_navigate(url, clear_logs: true)` | Start a new task |
| 2 | `browser_act(commands[])` | Click, fill forms, press keys |
| 3 | `browser_debug(console_types: ["error"])` | **First on errors** — check console/network |
| 4 | `browser_query(selector, fields: ["text"])` | Read page content (prefer over screenshot) |
| 5 | `browser_screenshot()` | **Last resort** — only for visual layout bugs |

### Tool Reference

| Tool | Description |
|------|-------------|
| `browser_navigate(url, clear_logs?)` | Navigate to a URL |
| `browser_act(commands[])` | Run actions: `click`, `hover`, `drag`, `fill`, `select`, `keypress`, `wait`, `scrollto`, `clicklink`, `waitfor`, `clearconsole` |
| `browser_debug(...)` | **Start here on errors.** Returns URL, title, console logs, network requests, dialogs |
| `browser_query(selector, ...)` | Read DOM via CSS selector. Prefer over screenshot |
| `browser_screenshot()` | **Last resort.** Returns base64 PNG |
| `browser_eval(code)` | Run JS in page (escape hatch) |
| `browser_scroll(...)` | Scroll page or scrollable container |
| `browser_wait_for_network(...)` | Wait for specific API response |
| `browser_upload(selector, files[])` | Upload files to input |
| `browser_restart(url?)` | Kill browser and start fresh |
| `browser_emulate_device(...)` | Switch to mobile/tablet profile |

### Example Workflow

```
browser_navigate("https://example.com/login", clear_logs: true)
browser_act([{ action: "fill", selector: "#email", value: "user@test.com" },
             { action: "click", selector: "button[type=submit]" }])
browser_wait_for_network({ url_pattern: "/api/session" })
browser_debug({ console_types: ["error"] })
browser_query(".dashboard-title", { fields: ["text"] })
```

### Environment

| Variable | Default | Description |
|----------|---------|-------------|
| `HEADLESS` | `false` | Run headless (`true`) or visible (`false`) |
| `REAL_CHROME` | `false` | Use installed Chrome instead of Playwright's Chromium |

Set via: `HEADLESS=true mare-browser-mcp` for non-interactive use.

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
