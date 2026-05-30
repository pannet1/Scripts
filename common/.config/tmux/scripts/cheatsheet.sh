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
│    prefix+H/L  previous / next window                               │
│    prefix+&    kill window                                          │
│                                                                     │
│  PANE SPLITTING                                                     │
│    prefix+|    split left/right (vertical line = columns)           │
│    prefix+_    split top/bottom (underscore = horizontal line)      │
│    prefix+z    zoom / unzoom current pane                           │
│    prefix+c    kill pane                                            │
│                                                                     │
│  PANE NAVIGATION                                                    │
│    Ctrl+h/j/k/l   move between panes (also nvim)                   │
│    prefix+h/j/k/l move between panes (tmux native)                 │
│    prefix+,/./-/= resize pane (grow left/right/down/up)             │
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
