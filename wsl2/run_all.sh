#!/bin/bash
set -euo pipefail

BASHRC="$HOME/.bashrc"

echo "=============================================="
echo "  WSL2 Debian Setup"
echo "=============================================="
echo ""

# ── 1. Packages ──
echo "--- 1/7: System Packages ---"
sudo apt update -y && sudo apt upgrade -y
sudo apt install -y console-setup
echo "console-setup console-setup/codeset47 select UTF-8" | sudo debconf-set-selections
echo "console-setup console-setup/fontface87 select Terminus" | sudo debconf-set-selections
sudo dpkg-reconfigure -f noninteractive console-setup
sudo ln -sf /usr/share/zoneinfo/Asia/Kolkata /etc/localtime
sudo apt install -y git curl wget fontconfig file tar zip unzip gzip tmux xclip
echo ""

# ── 2. Nerd Fonts ──
echo "--- 2/7: Nerd Fonts (WSL) ---"
FONT_DIR="$HOME/.local/share/fonts"
mkdir -p "$FONT_DIR"
cd /tmp
curl -fLo FiraCode.zip -L "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip"
unzip -o FiraCode.zip -d "$FONT_DIR"
rm FiraCode.zip
fc-cache -fv
echo ""

# ── 3. Neovim + LazyVim ──
echo "--- 3/7: Neovim + LazyVim ---"
NVIM_URL="https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz"
NVIM_INSTALL_DIR="/opt/nvim"
sudo apt install -y build-essential pkg-config ripgrep fd-find lazygit python3 python3-pip python3-venv
if [ ! -f /usr/local/bin/fd ]; then
	sudo ln -s "$(which fdfind)" /usr/local/bin/fd
fi
cd /tmp
curl -LO "$NVIM_URL"
file nvim-linux-x86_64.tar.gz | grep "gzip compressed data" || { echo "Invalid archive"; exit 1; }
sudo rm -rf "$NVIM_INSTALL_DIR"
tar -xzvf nvim-linux-x86_64.tar.gz
sudo mv nvim-linux-x86_64 "$NVIM_INSTALL_DIR"
sudo ln -sf "$NVIM_INSTALL_DIR/bin/nvim" /usr/local/bin/nvim
rm -f nvim-linux-x86_64.tar.gz
if ! echo "$PATH" | grep -q "/usr/local/bin"; then
	echo 'export PATH=/usr/local/bin:$PATH' >> "$BASHRC"
fi
pip3 install --break-system-packages python-lsp-server pynvim
if ! echo "$PATH" | grep -q "${HOME}/.local/bin"; then
	echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$BASHRC"
fi
if [ -d "$HOME/.config/nvim" ]; then
	echo "  ~/.config/nvim exists — skipping LazyVim clone"
else
	git clone https://github.com/LazyVim/starter "$HOME/.config/nvim"
fi
echo ""

# ── 4. Starship ──
echo "--- 4/7: Starship Prompt ---"
if ! command -v starship &>/dev/null; then
	curl -sS https://starship.rs/install.sh | sh -s -- -y
fi
mkdir -p "$HOME/.config"
cat > "$HOME/.config/starship.toml" << 'STAREOF'
add_newline = true
format = """
[│](#bf616a)$username$hostname\
[│](bold:#bf616a)$directory\
[│](bold:#88c0d0)$git_branch$git_status\
[│](bold:#a3be8c)$nodejs$python$rust\
[│](bold:#b48ead)$shlvl\
$fill\
$shell\
$time\
[│](bold:#d08770)\n\
$character"""
[username]
show_always = true
style_user = "bold:#a3be8c"
style_root = "bold:#bf616a"
format = "[$user]($style)"
[hostname]
ssh_only = true
format = "@[$hostname](bold:#88c0d0) "
[directory]
style = "bold:#88c0d0"
truncation_length = 3
truncation_symbol = "…/"
format = "[$path]($style)[$read_only]($read_only_style) "
[git_branch]
style = "bold:#a3be8c"
format = "[$branch]($style)"
ignore_branches = ["master", "main"]
[git_status]
style = "#d08770"
format = "([$all_status$ahead_behind]($style) )"
conflicted = "🏳"
untracked = "?"
stashed = "📦"
modified = "!"
staged = "+"
renamed = "»"
deleted = "✘"
[nodejs]
format = "via [⬢ $version](bold:#a3be8c) "
[python]
format = "via [🐍 $version](bold:#88c0d0) "
[rust]
format = "via [🦀 $version](bold:#d08770) "
[shlvl]
threshold = 2
format = "[$shlvl](bold:red) "
style = "bold:#bf616a"
[time]
disabled = false
time_format = "%H:%M"
style = "bold:#d08770"
format = "[$time]($style) "
[fill]
symbol = " "
[shell]
disabled = false
bash_indicator = ""
style = "bold:#b48ead"
format = "[$indicator]($style) "
[character]
success_symbol = "[❯](bold:#a3be8c)"
error_symbol = "[❯](bold:#bf616a)"
format = "$symbol "
STAREOF
LINE='eval "$(starship init bash)"'
grep -Fxq "$LINE" "$BASHRC" || echo "$LINE" >> "$BASHRC"
echo ""

# ── 5. Zoxide ──
echo "--- 5/7: Zoxide ---"
curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
LINE='eval "$(zoxide init bash)"'
if ! grep -Fxq "$LINE" "$BASHRC"; then
	echo "$LINE" >> "$BASHRC"
fi
echo ""

# ── 6. Tmux ──
echo "--- 6/7: Tmux ---"
TMUX_CONF="$HOME/.tmux.conf"
TPM_DIR="$HOME/.tmux/plugins/tpm"
if [ -f "$TMUX_CONF" ]; then
	cp "$TMUX_CONF" "$TMUX_CONF.bak"
fi
cat > "$TMUX_CONF" << 'TMUXEOF'
set -g default-shell /bin/bash
set -g mouse on
set -g base-index 1
set -g renumber-windows on
set -g escape-time 0
set -g history-limit 50000
bind r source-file ~/.tmux.conf \; display "Reloaded!"
bind | split-window -h
bind - split-window -v
bind h select-pane -L
bind j select-pane -D
bind k select-pane -U
bind l select-pane -R
set -g default-terminal "tmux-256color"
set -ga terminal-overrides ",*256col*:Tc"
set -ga terminal-overrides '*:Ss=\E[%p1%d q:Se=\E[ q'
set -g status-interval 5
set -g status-position top
set -g status-fg white
set -g status-bg default
set -g status-left "#[fg=green]##S #[fg=cyan]• #[fg=yellow]#I:#P "
set -g status-right "#[fg=cyan]%a %d-%b %y #[fg=green]%H:%M "
set -g window-status-format " #[fg=blue]#I:#W "
set -g window-status-current-format " #[fg=green,bold]#I:#W "
set -g window-status-separator ""
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-sensible'
set -g @plugin 'tmux-plugins/tmux-yank'
set -g @plugin 'tmux-plugins/tmux-resurrect'
set -g @plugin 'tmux-plugins/tmux-continuum'
set -g @continuum-restore 'on'
set -g @resurrect-capture-pane-contents 'on'
run '~/.tmux/plugins/tpm/tpm'
TMUXEOF
mkdir -p "$HOME/.tmux/plugins"
if [ ! -d "$TPM_DIR" ]; then
	git clone https://github.com/tmux-plugins/tpm "$TPM_DIR"
else
	git -C "$TPM_DIR" pull
fi
"$TPM_DIR/bin/install_plugins" || true
echo ""

# ── 7. Bash ──
echo "--- 7/7: Bash Config ---"
ALIASES="$HOME/.bash_aliases"
cat > "$ALIASES" << 'ALIASEOF'
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'
alias ln='ln -i'
alias ls='ls --color=auto'
alias l='ls -CF'
alias ll='ls -lAh'
alias la='ls -A'
alias lt='ls -lAhtr'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias ~='cd ~'
alias -- -='cd -'
alias grep='grep --color=auto'
alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'
alias c='clear'
alias h='history'
alias q='exit'
alias t='tmux'
alias ta='tmux attach -t'
alias tn='tmux new -s'
alias tl='tmux list-sessions'
alias mkdir='mkdir -pv'
alias df='df -h'
alias du='du -ch'
alias free='free -h'
alias ip='ip -c'
alias explorer='explorer.exe .'
alias open='explorer.exe'
alias pbcopy='clip.exe'
alias pbpaste='powershell.exe -Command Get-Clipboard'
alias reload='exec bash'
ALIASEOF
for hook in \
	'export EDITOR=nvim' \
	'export VISUAL=nvim' \
	'export PAGER=less' \
	'export LESS=-RFX' \
	'[ -f ~/.bash_aliases ] && . ~/.bash_aliases' \
	'[ -f /usr/share/bash-completion/bash_completion ] && . /usr/share/bash-completion/bash_completion' \
; do
	grep -Fxq "$hook" "$BASHRC" || echo "$hook" >> "$BASHRC"
done
if ! grep -q "HISTSIZE=" "$BASHRC"; then
	cat >> "$BASHRC" << 'HISTEOF'

HISTSIZE=100000
HISTFILESIZE=200000
HISTCONTROL=ignoreboth:erasedups
HISTTIMEFORMAT="%F %T "
shopt -s histappend
shopt -s cmdhist
HISTEOF
fi

echo ""
echo "=============================================="
echo "  Done!"
echo "=============================================="
echo ""
echo "  source ~/.bashrc"
echo "  tmux            (then prefix + I for plugins)"
echo "  nvim            (plugins auto-install on first launch)"
