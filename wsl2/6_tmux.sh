#!/bin/bash

set -e

TMUX_CONF="$HOME/.tmux.conf"
TPM_DIR="$HOME/.tmux/plugins/tpm"

if [ -f "$TMUX_CONF" ]; then
    echo "[!] $TMUX_CONF already exists. Backing up to $TMUX_CONF.bak"
    cp "$TMUX_CONF" "$TMUX_CONF.bak"
fi

cat > "$TMUX_CONF" << 'EOF'
# ============ General ============
set -g default-shell /bin/bash
set -g mouse on
set -g base-index 1
set -g renumber-windows on
set -g escape-time 0
set -g history-limit 50000

# ============ Key Bindings ============
bind r source-file ~/.tmux.conf \; display "Reloaded!"
bind | split-window -h
bind - split-window -v
bind h select-pane -L
bind j select-pane -D
bind k select-pane -U
bind l select-pane -R

# ============ Colors ============
set -g default-terminal "tmux-256color"
set -ga terminal-overrides ",*256col*:Tc"
set -ga terminal-overrides '*:Ss=\E[%p1%d q:Se=\E[ q'

# ============ Status Bar ============
set -g status-interval 5
set -g status-position top
set -g status-fg white
set -g status-bg default

set -g status-left "#[fg=green]##S #[fg=cyan]• #[fg=yellow]#I:#P "
set -g status-right "#[fg=cyan]%a %d-%b %y #[fg=green]%H:%M "
set -g window-status-format " #[fg=blue]#I:#W "
set -g window-status-current-format " #[fg=green,bold]#I:#W "
set -g window-status-separator ""

# ============ Plugins via TPM ============
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-sensible'
set -g @plugin 'tmux-plugins/tmux-yank'
set -g @plugin 'tmux-plugins/tmux-resurrect'
set -g @plugin 'tmux-plugins/tmux-continuum'

set -g @continuum-restore 'on'
set -g @resurrect-capture-pane-contents 'on'

run '~/.tmux/plugins/tpm/tpm'
EOF

echo "[+] Installing TPM (Tmux Plugin Manager)..."
mkdir -p "$HOME/.tmux/plugins"
if [ ! -d "$TPM_DIR" ]; then
    git clone https://github.com/tmux-plugins/tpm "$TPM_DIR"
else
    echo "[!] TPM already installed, updating..."
    git -C "$TPM_DIR" pull
fi

echo "[+] Installing TPM plugins..."
"$TPM_DIR/bin/install_plugins" || true

echo "[✔] tmux configured! Open a new tmux session: tmux"
echo "    Press prefix + I (capital i) inside tmux to install any missing plugins"
