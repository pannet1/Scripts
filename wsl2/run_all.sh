#!/bin/bash
set -euo pipefail

ok()    { echo "  $1 ✓"; }
fail()  { echo "  $1 ✗"; }
fix()   { echo "  → $1"; }
step()  { echo ""; echo "--- $1 ---"; }

check_cmd()   { command -v "$1" &>/dev/null; }
check_file()  { [ -f "$1" ]; }
check_dir()   { [ -d "$1" ]; }
check_line()  { grep -Fxq "$1" "$2" 2>/dev/null; }
check_font()  { fc-list | grep -qi "$1" &>/dev/null; }

BASHRC="$HOME/.bashrc"

echo "=============================================="
echo "  WSL2 Debian Setup"
echo "=============================================="

# ── 1. Packages ──
step "1/7: System Packages"
PACKAGES="git curl wget fontconfig file tar zip unzip gzip tmux xclip"

ALL_PRESENT=true
for pkg in $PACKAGES; do
    if ! dpkg -s "$pkg" &>/dev/null; then
        ALL_PRESENT=false; break
    fi
done

TZ_OK=false
[ "$(timedatectl show --property=Timezone --value 2>/dev/null)" = "Asia/Kolkata" ] && TZ_OK=true

if $ALL_PRESENT && $TZ_OK; then
    ok "packages installed"
    ok "timezone Asia/Kolkata"
else
    if ! $ALL_PRESENT; then
        fail "packages"
        fix "apt update && install packages"
        sudo apt update -y && sudo apt upgrade -y
        sudo apt install -y console-setup $PACKAGES
        echo "console-setup console-setup/codeset47 select UTF-8" | sudo debconf-set-selections
        echo "console-setup console-setup/fontface87 select Terminus" | sudo debconf-set-selections
        sudo dpkg-reconfigure -f noninteractive console-setup
        ok "packages installed"
    fi
    if ! $TZ_OK; then
        fail "timezone ($(timedatectl show --property=Timezone --value 2>/dev/null))"
        fix "setting timezone to Asia/Kolkata"
        sudo ln -sf /usr/share/zoneinfo/Asia/Kolkata /etc/localtime
        ok "timezone Asia/Kolkata"
    fi
fi

# ── 2. Nerd Fonts ──
step "2/7: Nerd Fonts (WSL)"
if check_font "FiraCode"; then
    ok "FiraCode Nerd Font installed"
else
    fail "FiraCode Nerd Font"
    FONT_DIR="$HOME/.local/share/fonts"
    mkdir -p "$FONT_DIR"
    cd /tmp
    fix "downloading FiraCode Nerd Font"
    curl -fLo FiraCode.zip -L "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip"
    unzip -o FiraCode.zip -d "$FONT_DIR" >/dev/null
    rm FiraCode.zip
    fc-cache -f >/dev/null 2>&1
    if check_font "FiraCode"; then
        ok "FiraCode Nerd Font installed"
    else
        fail "FiraCode Nerd Font install FAILED"
    fi
fi

# ── 3. Neovim + LazyVim ──
step "3/7: Neovim + LazyVim"
NVIM_DEPS="build-essential pkg-config ripgrep fd-find lazygit python3 python3-pip python3-venv"
NEEDS_NVIM=false

if check_cmd nvim; then
    ok "nvim binary"
else
    fail "nvim binary"; NEEDS_NVIM=true
fi

if check_dir "$HOME/.config/nvim"; then
    ok "LazyVim config"
else
    fail "LazyVim config"; NEEDS_NVIM=true
fi

if $NEEDS_NVIM; then
    fix "installing nvim dependencies"
    sudo apt install -y $NVIM_DEPS

    if [ ! -f /usr/local/bin/fd ] && command -v fdfind &>/dev/null; then
        sudo ln -s "$(which fdfind)" /usr/local/bin/fd
    fi

    NVIM_URL="https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz"
    cd /tmp
    fix "downloading latest Neovim"
    curl -LO "$NVIM_URL"
    file nvim-linux-x86_64.tar.gz | grep -q "gzip compressed data" || { echo "  Invalid archive"; exit 1; }
    sudo rm -rf /opt/nvim
    tar -xzf nvim-linux-x86_64.tar.gz
    sudo mv nvim-linux-x86_64 /opt/nvim
    sudo ln -sf /opt/nvim/bin/nvim /usr/local/bin/nvim
    rm -f nvim-linux-x86_64.tar.gz
    ok "nvim installed"

    pip3 install --break-system-packages python-lsp-server pynvim >/dev/null 2>&1 || true

    if ! check_dir "$HOME/.config/nvim"; then
        fix "cloning LazyVim starter"
        git clone https://github.com/LazyVim/starter "$HOME/.config/nvim"
        ok "LazyVim cloned"
    fi

    check_line 'export PATH=/usr/local/bin:$PATH' "$BASHRC" || \
        echo 'export PATH=/usr/local/bin:$PATH' >> "$BASHRC"
    check_line 'export PATH="$HOME/.local/bin:$PATH"' "$BASHRC" || \
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$BASHRC"
fi

# ── 4. Starship ──
step "4/7: Starship Prompt"
STARSHIP_OK=true

if check_cmd starship; then
    ok "starship binary"
else
    fail "starship binary"; STARSHIP_OK=false
fi

if check_file "$HOME/.config/starship.toml"; then
    ok "starship.toml"
else
    fail "starship.toml"; STARSHIP_OK=false
fi

if check_line 'eval "$(starship init bash)"' "$BASHRC"; then
    ok "starship init in .bashrc"
else
    fail "starship init in .bashrc"; STARSHIP_OK=false
fi

if ! $STARSHIP_OK; then
    if ! check_cmd starship; then
        fix "installing Starship"
        curl -sS https://starship.rs/install.sh | sh -s -- -y
        ok "starship installed"
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
    ok "starship.toml written"

    if ! check_line 'eval "$(starship init bash)"' "$BASHRC"; then
        echo 'eval "$(starship init bash)"' >> "$BASHRC"
        ok "starship init added to .bashrc"
    fi
fi

# ── 5. Zoxide ──
step "5/7: Zoxide"
ZOXIDE_OK=true

if check_cmd zoxide; then
    ok "zoxide binary"
else
    fail "zoxide binary"; ZOXIDE_OK=false
fi

if check_line 'eval "$(zoxide init bash)"' "$BASHRC"; then
    ok "zoxide init in .bashrc"
else
    fail "zoxide init in .bashrc"; ZOXIDE_OK=false
fi

if ! $ZOXIDE_OK; then
    if ! check_cmd zoxide; then
        fix "installing Zoxide"
        curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
        ok "zoxide installed"
    fi
    if ! check_line 'eval "$(zoxide init bash)"' "$BASHRC"; then
        echo 'eval "$(zoxide init bash)"' >> "$BASHRC"
        ok "zoxide init added to .bashrc"
    fi
fi

# ── 6. Tmux ──
step "6/7: Tmux"
TMUX_OK=true

if check_file "$HOME/.tmux.conf"; then
    ok ".tmux.conf"
else
    fail ".tmux.conf"; TMUX_OK=false
fi

if check_dir "$HOME/.tmux/plugins/tpm"; then
    ok "TPM installed"
else
    fail "TPM"; TMUX_OK=false
fi

if ! $TMUX_OK; then
    TMUX_CONF="$HOME/.tmux.conf"
    TPM_DIR="$HOME/.tmux/plugins/tpm"

    if [ -f "$TMUX_CONF" ]; then
        cp "$TMUX_CONF" "$TMUX_CONF.bak"
    fi

    fix "writing .tmux.conf"
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
    ok ".tmux.conf written"

    mkdir -p "$HOME/.tmux/plugins"
    if [ ! -d "$TPM_DIR" ]; then
        fix "cloning TPM"
        git clone https://github.com/tmux-plugins/tpm "$TPM_DIR"
    else
        fix "updating TPM"
        git -C "$TPM_DIR" pull
    fi
    "$TPM_DIR/bin/install_plugins" || true
    ok "TPM plugins installed"
fi

# ── 7. Bash ──
step "7/7: Bash Config"
BASH_OK=true

if check_file "$HOME/.bash_aliases"; then
    ok ".bash_aliases"
else
    fail ".bash_aliases"; BASH_OK=false
fi

HOOKS=(
    'export EDITOR=nvim'
    'export VISUAL=nvim'
    'export PAGER=less'
    'export LESS=-RFX'
    '[ -f ~/.bash_aliases ] && . ~/.bash_aliases'
    '[ -f /usr/share/bash-completion/bash_completion ] && . /usr/share/bash-completion/bash_completion'
)

HOOKS_MISSING=false
for hook in "${HOOKS[@]}"; do
    if ! check_line "$hook" "$BASHRC"; then
        HOOKS_MISSING=true; break
    fi
done

if $HOOKS_MISSING; then
    BASH_OK=false
fi

if grep -q "HISTSIZE=" "$BASHRC" 2>/dev/null; then
    ok "history settings"
else
    fail "history settings"; BASH_OK=false
fi

if ! $BASH_OK; then
    ALIASES="$HOME/.bash_aliases"

    fix "writing .bash_aliases"
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
    ok ".bash_aliases written"

    for hook in "${HOOKS[@]}"; do
        if ! check_line "$hook" "$BASHRC"; then
            echo "$hook" >> "$BASHRC"
        fi
    done
    ok "bashrc hooks added"

    if ! grep -q "HISTSIZE=" "$BASHRC" 2>/dev/null; then
        cat >> "$BASHRC" << 'HISTEOF'

HISTSIZE=100000
HISTFILESIZE=200000
HISTCONTROL=ignoreboth:erasedups
HISTTIMEFORMAT="%F %T "
shopt -s histappend
shopt -s cmdhist
HISTEOF
        ok "history settings added"
    fi
fi

echo ""
echo "=============================================="
echo "  Done!"
echo "=============================================="
echo ""
echo "  source ~/.bashrc"
echo "  tmux            (then prefix + I for plugins)"
echo "  nvim            (plugins auto-install on first launch)"
