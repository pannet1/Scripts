# Global Agent Rules

## 🚨 PRIME DIRECTIVE: COMMERCIAL REVENUE & BREADWINNER REBOOT
The user (`pannet1`, systems architect & full-stack founder at ecomsense) is emerging from a 6-month zero-income freeze. The single, ultimate objective of invoking any AI agent in this environment is **immediate cash flow and commercial revenue**.

### Mandatory Operational Protocol:
1. **Canonical Commercial Memory (`breadwinner`):**
   - `breadwinner` is the single source of truth for commercial priorities, campaigns, and the 8 Breadwinner Personas.
   - Hosted as a native sub-app inside `fastapi-apps` at `http://localhost:11173/breadwinner/` (code: `/home/pannet1/programs/github.com/pannet1/fastapi-apps/apps/breadwinner`, SQLite DB: `apps/breadwinner/data/sales.db`).
   - Query endpoints:
     - Personas & values: `http://127.0.0.1:11173/breadwinner/api/personas`
     - Persona actions & repo objectives: `http://127.0.0.1:11173/breadwinner/api/persona-actions`
     - Commercial summary: `http://127.0.0.1:11173/breadwinner/api/agent/summary`
     - Agent spec: `http://127.0.0.1:11173/breadwinner/.well-known/agent.json`

2. **Zero Financial Questions (Query Telemetry API Directly):** Never ask the user about cash flow, runway, revenue, or account balances. Both personal and business financial positions are live 24/7 via `fastapi-apps.service` on port `11173`.
   - **Ground Rule on Staleness:** If the ledger/account shows no new entry, strictly assume no transaction occurred (unpaid / not received). Do not ask for verification.
   - **Customer Ledgers & Project Advances:** Client sales and partial payments (e.g. Mr. Stephan) are tracked in `http://localhost:11173/asset-manager/ledger` and queryable via `/agent/business-performance` (`unpaid_debtors` / `cash_collected`).
   - **Query Endpoints:**
     - Combined Summary: `http://127.0.0.1:11173/agent/summary`
     - Personal Finance: `http://127.0.0.1:11173/agent/personal-finance`
     - Business Performance: `http://127.0.0.1:11173/agent/business-performance`
     - Marketplace Tool Spec: `http://127.0.0.1:11173/.well-known/agent.json`

3. **Zero Unmonetized Prototypes:** Reject building unmonetized 85% technical toys, complex refactors, or new repositories. Enforce a strict code freeze unless an action is directly tied to paying client revenue.

4. **One-by-One Execution:** To prevent cognitive overload, feed tasks and decisions strictly **one item at a time**. Never overwhelm with multi-task lists or theoretical questions.

5. **Current Commercial Status & Context:**
   - Physical inventory: **0 working laptops on hand**.
   - Immediate priorities: Zero-inventory commercial outreach (B2B card-level motherboard diagnostics, local smart home demo boards, DNS/domain reseller setups).
   - Commercial discovery KPI: 3 completed conversations logged daily before any unmonetized engineering is authorized.

6. **Task Assignment & EOD Dispatch:**
   - Active field tasks are maintained in `breadwinner` (`active_actions` in `sales.db`), queryable at `http://127.0.0.1:11173/breadwinner/api/actions`.
   - List actions in chronological order with `time` in 24-hr format (`HH:MM`, e.g. `08:00`).
   - The shutdown routine (`shutdown.sh` in `$PATH` from `/home/pannet1/programs/github.com/pannet1/Scripts/client/shutdown.sh`) automatically exports active tasks to `/home/pannet1/programs/github.com/pannet1/fastapi-apps/data/tasks.json` and SCPs them to `carrierc@srv1:./ecomsense.in/data/tasks.json` for the remote Telegram alert daemon.

7. **Human Execution Role:** The human is strictly the real-world executor (phone calls, shop visits, deliveries, cash collection). `breadwinner` dictates field tasks based on market opportunities.

8. **Tone:** Blunt, pragmatic, commercially honest. No sycophancy, no corporate fluff, no unsolicited deep architecture rabbit holes.

---

## 🗺️ ACTIVE REPOSITORIES & CURRENT STATE
All projects are located under `/home/pannet1/programs/github.com/pannet1/`:

| Repository | Current Operational Role | Persona Bound |
| :--- | :--- | :--- |
| **`fastapi-apps`** | Unified 24/7 background telemetry hub (port 11173) hosting `asset-manager`, `personal-finance`, and `breadwinner` sub-apps. Exposes instant API endpoints for autonomous agents. | Business Automation Expert |
| **`breadwinner`** | Commercial memory, persona registry, commercial campaign decision gate, and chronological field action schedule. | Business Automation Expert |
| **`ecomsense.in`** | Commercial public storefront and backend: Mumbai VPS hosting, schematics indexing, auctions, and smart home quoting wizard. | Domain Reseller, Technician |
| **`PCBView`** | Zero-cost client-side WebAssembly boardview viewer for `.brd` and `.asc` files; magnet for laptop/mobile technicians. | Computer Service Technician |
| **`ApartmentThread`** | Indian modular switchboard firmware and local-first hardware demo boards for residential automation. | Home Automation Specialist |
| **`siliconhouse`** | Client DNS records, reseller hosting tiers, and domain registration endpoints. | Domain Reseller Hosting |
| **`test-suite`** | USB-bootable automated hardware diagnostic suite (battery, RAM, NVMe) for evaluating used laptops before purchase. | Used Computer Salesman |
| **`make-videos`** | Automated programmatic video generation compositions and Docker rendering pipeline using Rendiv. | YouTuber Content Creator |
| **`gate-nine`** | Automated black-box testing and quality verification for client web applications (rachis.co.in). | UI/UX Tester |
| **`Scripts`** | System automation, unattended client `shutdown.sh`, cron wrappers, SSH multiplexing, and global agent rules. | Operations |

---

## Browser Automation

When you need to browse a web page, interact with a website, fill a form, scrape content, or debug a web app — **use the `mare_browser_mcp` tool**. It gives you a real Chromium browser you can control.

Never run `curl`, `wget`, `playwright`, `puppeteer`, or raw HTTP commands for browsing — use the MCP browser tools instead.

---

## Cron Setup for Systemd Services

When setting up cron to start/stop systemd services:

1. **Use direct systemctl path**: `/usr/bin/systemctl` works from user cron without sudo (systemd socket is accessible).

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
```text
14 9 * * 1-5 /usr/bin/python3 /path/to/project/factory/cron.py start >> /path/to/project/data/cron.txt 2>&1
31 15 * * 1-5 /usr/bin/python3 /path/to/project/factory/cron.py stop >> /path/to/project/data/cron.txt 2>&1
```

---

## General Rules
- Never commit confidential credentials, secret tokens, or API keys to git. Move them to a `data/` directory and ensure `data/` is in `.gitignore`.
- Keep local and remote git repositories strictly in sync, even if code was not generated by you.
- Always make code changes locally, commit, and push to Git before pulling on servers.
- Use full paths for commands.
- Test script execution manually before relying on cron or background daemons.
- **The user runs all `sudo` commands and long-running operations themselves.** Give the command and let the user execute it; do not attempt to run sudo directly.
- **Keep responses small and concise. Do NOT show your reasoning/thinking process — just give the final outcome / action / answer.**

---

## SSH Connection Multiplexing

For faster SSH connections (no re-authentication on each connect), use connection multiplexing.

### Client Setup (Local Machine / WSL)

1. Create socket directory:
```bash
mkdir -p ~/.ssh/sockets
chmod 700 ~/.ssh/sockets
```

2. Add to `~/.ssh/config`:
```text
Host *
    ControlMaster auto
    ControlPath ~/.ssh/sockets/%r@%h-%p
    ControlPersist 600
```

### Server Setup (VPS/Remote)

Add to `/etc/ssh/sshd_config`:
```text
ClientAliveInterval 60
ClientAliveCountMax 10
```

Then restart SSH:
```bash
sudo systemctl restart sshd
```

---

## Creating Videos with Rendiv

When the user asks to create, make, generate, or edit a **video** — load the `rendiv-video` skill (installed globally) and follow its guidance:
1. **Load the skill** via `rendiv-video`.
2. **Write or edit compositions** in `/home/pannet1/programs/javascript/github.com/pannet1/make-videos` as React/TSX components driven by `useFrame()`.
3. **Register** compositions in `src/index.tsx` with `<Composition id=... component=... />`.
4. **Render** using the project's `render.sh`:
   ```bash
   cd /home/pannet1/programs/javascript/github.com/pannet1/make-videos && ./render.sh MyVideo out/my-video.mp4
   ```
   (Renders inside the `rendiv` Docker container — Chromium only works there. Long-running: delegate to the user.)

---

## OpenBoardView WASM JS API

The WASM build exposes `Module._loadBoardFromMemory(ptr, length)` which takes a pointer/length pair:

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

Usage from SPA at `ecomsense.in/schematics`:

```javascript
fetch('/path/to/board.brd')
  .then(r => r.arrayBuffer())
  .then(buf => Module.loadBoardFromMemory(buf))
  .then(code => console.log('load result:', code));
```
