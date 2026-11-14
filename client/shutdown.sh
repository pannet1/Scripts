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

# Sync tasks.json from sales.db (generated strictly within fastapi-apps/ dir)
python3 -c "
import sqlite3, json, sys, os

db_candidates = [
    os.path.expanduser('~/programs/github.com/pannet1/fastapi-apps/apps/breadwinner/data/sales.db'),
    os.path.expanduser('~/programs/github.com/pannet1/fastapi-apps/apps/sales-marketing/data/sales.db'),
    os.path.expanduser('~/programs/github.com/pannet1/breadwinner/data/sales.db'),
    os.path.expanduser('~/programs/github.com/pannet1/sales-marketing/data/sales.db')
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
        sys.stderr.write(f'Notice: db query failed ({e})\n')

# Export tasks.json strictly within fastapi-apps/
fastapi_apps_dir = os.path.expanduser('~/programs/github.com/pannet1/fastapi-apps')
target_paths = [
    os.path.join(fastapi_apps_dir, 'data', 'tasks.json'),
    os.path.join(fastapi_apps_dir, 'tasks.json')
]

for p in target_paths:
    os.makedirs(os.path.dirname(p), exist_ok=True)
    with open(p, 'w', encoding='utf-8') as f:
        json.dump(actions, f, indent=2, ensure_ascii=False)
        f.write('\n')

print(f'Successfully synced {len(actions)} tasks to {target_paths[0]}')
"

TASKS_FILE="$HOME/programs/github.com/pannet1/fastapi-apps/data/tasks.json"
if [ ! -f "$TASKS_FILE" ]; then
    TASKS_FILE="$HOME/programs/github.com/pannet1/fastapi-apps/tasks.json"
fi

# Push tasks to remote server
if [ -f "$TASKS_FILE" ]; then
    echo "Pushing tasks to remote server (srv1)..."
    scp "$TASKS_FILE" carrierc@srv1:./ecomsense.in/data/tasks.json
    echo "Tasks successfully pushed to srv1:./ecomsense.in/data/tasks.json."
else
    echo "Error: $TASKS_FILE not found." >&2
    exit 1
fi

# Poweroff (unconditional unless running in --no-poweroff / --dry-run)
if [ "$NO_POWEROFF" -eq 0 ]; then
    echo "Powering off system..."
    systemctl poweroff
else
    echo "Dry run complete (poweroff skipped)."
fi
