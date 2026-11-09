#!/usr/bin/env bash
set -euo pipefail

# Ensure ~/tasks.json is synced from ~/REBOOT_PLAN.yaml if REBOOT_PLAN exists
if [ -f "$HOME/REBOOT_PLAN.yaml" ]; then
    python3 -c "
import yaml, json, sys, os
try:
    plan_path = os.path.expanduser('~/REBOOT_PLAN.yaml')
    tasks_path = os.path.expanduser('~/tasks.json')
    with open(plan_path) as f:
        data = yaml.safe_load(f)
    actions = data.get('active_actions', [])
    with open(tasks_path, 'w') as f:
        json.dump(actions, f, indent=2)
except Exception as e:
    sys.stderr.write(f'Notice: tasks sync skipped: {e}\n')
" 2>/dev/null || true
fi

# Push tasks to remote server
if [ -f "$HOME/tasks.json" ]; then
    echo "Pushing tasks to remote server (srv1)..."
    scp "$HOME/tasks.json" carrierc@srv1:./ecomsense.in/data/.
    echo "Tasks successfully pushed to srv1:./ecomsense.in/data/."
else
    echo "Error: ~/tasks.json not found." >&2
    exit 1
fi

# Unconditional poweroff
echo "Powering off system..."
systemctl poweroff
