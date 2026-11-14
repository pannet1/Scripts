#!/usr/bin/env bash
set -euo pipefail

NO_POWEROFF="${NO_POWEROFF:-0}"
if [ "${1:-}" = "--no-poweroff" ] || [ "${1:-}" = "--dry-run" ]; then
    NO_POWEROFF=1
fi

# System upgrade (unattended)
if [ "$NO_POWEROFF" -eq 0 ]; then
    topgrade -y --no-ask-retry --no-tmux || true
fi

# Sync tasks.json from sales.db (deprecated REBOOT_PLAN.yaml retired into sales.db)
python3 -c "
import sqlite3, json, sys, os

db_candidates = [
    os.path.expanduser('~/programs/github.com/pannet1/fastapi-apps/apps/sales-marketing/data/sales.db'),
    os.path.expanduser('~/programs/github.com/pannet1/sales-marketing/data/sales.db'),
    os.path.expanduser('~/firstmate/data/sales.db')
]
db_path = next((p for p in db_candidates if os.path.isfile(p)), None)

actions = []
if db_path:
    try:
        conn = sqlite3.connect(db_path)
        conn.row_factory = sqlite3.Row
        c = conn.cursor()
        c.execute('SELECT task, action, time, status FROM active_actions WHERE status != \"done\" ORDER BY time, id')
        rows = c.fetchall()
        if not rows:
            c.execute('SELECT task, action, time, status FROM active_actions ORDER BY time, id')
            rows = c.fetchall()
        conn.close()
        for r in rows:
            t = str(r['task'] or '').strip()
            if t:
                actions.append({
                    'task': t,
                    'action': str(r['action'] or '').strip(),
                    'time': str(r['time'] or '').strip()
                })
    except Exception as e:
        sys.stderr.write(f'Notice: db query failed ({e}), falling back\n')

# Fallback to legacy REBOOT_PLAN.yaml if db produced nothing
if not actions:
    for plan_p in [os.path.expanduser('~/firstmate/data/REBOOT_PLAN.yaml'), os.path.expanduser('~/REBOOT_PLAN.yaml')]:
        if os.path.isfile(plan_p):
            try:
                import yaml
                with open(plan_p) as f:
                    data = yaml.safe_load(f) or {}
                actions = data.get('active_actions', [])
                if actions:
                    break
            except Exception:
                pass

# Export tasks.json to both ~/firstmate/data/ and ~/
out_dirs = [os.path.expanduser('~/firstmate/data'), os.path.expanduser('~')]
for d in out_dirs:
    os.makedirs(d, exist_ok=True)
    json_path = os.path.join(d, 'tasks.json')
    with open(json_path, 'w', encoding='utf-8') as f:
        json.dump(actions, f, indent=2, ensure_ascii=False)
        f.write('\n')

print(f'Successfully synced {len(actions)} tasks to tasks.json')
"

# Push tasks to remote server
if [ -f "$HOME/firstmate/data/tasks.json" ]; then
    echo "Pushing tasks to remote server (srv1)..."
    scp "$HOME/firstmate/data/tasks.json" carrierc@srv1:./ecomsense.in/data/.
    echo "Tasks successfully pushed to srv1:./ecomsense.in/data/."
else
    echo "Error: ~/firstmate/data/tasks.json not found." >&2
    exit 1
fi

# Poweroff (unconditional unless running in --no-poweroff / --dry-run)
if [ "$NO_POWEROFF" -eq 0 ]; then
    echo "Powering off system..."
    systemctl poweroff
else
    echo "Dry run complete (poweroff skipped)."
fi
