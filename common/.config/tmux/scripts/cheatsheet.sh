#!/bin/bash
# =============================================================================
# cheatsheet.sh — curated tmux keybinding reference popup
# =============================================================================
# Keybinding: prefix+/
# Shows a categorized list of custom/important keybindings in a popup.
# =============================================================================

cat <<'EOF'
┌─────────────────────────────────────────────────────────────────────┐
│                       TMUX CHEATSHEET                               │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  SESSION MANAGEMENT                                                 │
│    prefix+O    sessionizer — fzf project switcher                   │
│    prefix+S    choose-session — interactive session picker          │
│    prefix+"    choose-window — interactive window picker            │
│                                                                     │
│  WINDOWS                                                            │
│    prefix+C    new window (Ctrl-C)                                  │
│    prefix+H/L  previous / next window                               │
│    prefix+&    kill window                                          │
│                                                                     │
│  PANE SPLITTING                                                     │
│    prefix+|    split left/right (vertical line = columns)           │
│    prefix+-    split top/bottom (horizontal line = rows)            │
│    prefix+z    zoom / unzoom current pane                           │
│    prefix+c    kill pane                                            │
│                                                                     │
│  PANE NAVIGATION                                                    │
│    Ctrl+h/j/k/l   move between panes (also nvim)                   │
│    prefix+h/j/k/l move between panes (tmux native)                 │
│    prefix+,/./_/= resize pane (grow left/right/down/up)             │
│                                                                     │
│  AGENTIC WORKFLOW                                                   │
│    prefix+p    popup terminal (floax) — run agent commands          │
│    prefix+F    fzf menu — switch session/window/pane               │
│    prefix+u    fzf-url — open URLs from pane output                │
│    prefix+Space tmux-thumbs — fuzzy select & yank text              │
│    prefix+K    clear current pane                                   │
│                                                                     │
│  PLUGINS                                                            │
│    prefix+I    install TPM plugins                                  │
│    prefix+U    update TPM plugins                                   │
│                                                                     │
│  MISC                                                               │
│    prefix+/    show this cheatsheet                                 │
│    prefix+?    show ALL keybindings (built-in)                      │
│    prefix+R    reload tmux.conf                                     │
│    prefix+D    detach from session                                  │
│    prefix+:    command prompt                                       │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
EOF
read -n 1 -s
