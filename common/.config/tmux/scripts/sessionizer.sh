#!/bin/bash
# =============================================================================
# sessionizer.sh — fzf-based tmux session switcher
# =============================================================================
# Keybinding: prefix+O
# Scans project directories, fuzzy-finds one, switches to existing tmux session
# or creates a new session named after the directory.
#
# Customize session roots via SESSIONIZER_ROOTS env var:
#   export SESSIONIZER_ROOTS="$HOME/src:$HOME/work"
# Defaults to common project locations if unset.
# =============================================================================
set -euo pipefail

# Directories to scan for projects (colon-separated, override via env)
if [ -n "${SESSIONIZER_ROOTS:-}" ]; then
  IFS=':' read -ra ROOTS <<< "$SESSIONIZER_ROOTS"
else
  ROOTS=(
    "$HOME/programs"
    "$HOME/projects"
    "$HOME/github"
    "$HOME/.config"
  )
fi

selected="$(
  find "${ROOTS[@]}" -mindepth 1 -maxdepth 3 -type d 2>/dev/null \
    | grep -v '/node_modules$' \
    | grep -v '/vendor$' \
    | grep -v '/.git$' \
    | sort -u \
    | fzf --height=100% \
        --prompt="  session > " \
        --header="  Switch / Create tmux session" \
        --preview="ls -1 --color=always {} 2>/dev/null" \
        --preview-window="right:40%"
)" || exit 0

# Session name = directory basename (sanitized)
session_name="$(basename "$selected" | tr ' .' '_')"

if ! tmux has-session -t "$session_name" 2>/dev/null; then
  tmux new-session -d -s "$session_name" -c "$selected"
fi

tmux switch-client -t "$session_name"
