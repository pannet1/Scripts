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
│    prefix+o    sessionizer — fzf project switcher                   │
│    prefix+"    choose-window — interactive window picker            │
│                                                                     │
│  WINDOWS                                                            │
│    prefix+^C   new window                                           │
│    prefix+^A   last / previous window                               │
│    prefix+n    next window (wraps: last → first)                    │
│    prefix+H/L  previous / next window (no wrap)                     │
│    prefix+"    choose-window — interactive picker                   │
│    prefix+r    rename window                                        │
│    prefix+&    kill window                                          │
│                                                                     │
│  PANE SPLITTING                                                     │
│    prefix+|    split left/right (vertical line = columns)           │
│    prefix+_    split top/bottom (underscore = horizontal line)      │
│    prefix++    zoom current pane (maximize)                         │
│    prefix+-    unzoom current pane (restore)                        │
│    prefix+c    kill pane                                            │
│                                                                     │
│  PANE NAVIGATION                                                    │
│    Ctrl+h/j/k/l   move between panes (also nvim)                   │
│    prefix+h/j/k/l move between panes (tmux native)                 │
│    prefix+,/./= resize pane (grow left/right/up)                    │
│                                                                     │
│  AGENTIC WORKFLOW                                                   │
│    prefix+p    popup terminal (floax) — run agent commands          │
│    prefix+f    fzf menu — switch session/window/pane               │
│    prefix+u    fzf-url — open URLs from pane output                │
│    prefix+Space tmux-thumbs — fuzzy select & yank text              │
│    prefix+q    clear current pane                                   │
│                                                                     │
│  PLUGINS                                                            │
│    prefix+I    install TPM plugins                                  │
│    prefix+U    update TPM plugins                                   │
│                                                                     │
│  MISC                                                               │
│    prefix+/    show this cheatsheet                                 │
│    prefix+R    reload tmux.conf                                     │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
EOF
