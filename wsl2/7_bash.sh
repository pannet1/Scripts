#!/bin/bash

set -e

BASHRC="$HOME/.bashrc"
ALIASES="$HOME/.bash_aliases"

cat > "$ALIASES" << 'EOF'
# ── Safety ──
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'
alias ln='ln -i'

# ── ls ──
alias ls='ls --color=auto'
alias l='ls -CF'
alias ll='ls -lAh'
alias la='ls -A'
alias lt='ls -lAhtr'

# ── Navigation ──
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias ~='cd ~'
alias -- -='cd -'

# ── grep ──
alias grep='grep --color=auto'
alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'

# ── Shortcuts ──
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

# ── WSL ──
alias explorer='explorer.exe .'
alias open='explorer.exe'
alias pbcopy='clip.exe'
alias pbpaste='powershell.exe -Command Get-Clipboard'

# ── Reload ──
alias reload='exec bash'
alias ..bash='exec bash'
EOF

for hook in \
    'export EDITOR=nvim' \
    'export VISUAL=nvim' \
    'export PAGER=less' \
    'export LESS=-RFX' \
    '[ -f ~/.bash_aliases ] && . ~/.bash_aliases' \
    '[ -f /usr/share/bash-completion/bash_completion ] && . /usr/share/bash-completion/bash_completion' \
; do
    if ! grep -Fxq "$hook" "$BASHRC"; then
        echo "$hook" >> "$BASHRC"
    fi
done

if ! grep -q "HISTSIZE=" "$BASHRC"; then
    cat >> "$BASHRC" << 'EOF'

# ── History ──
HISTSIZE=100000
HISTFILESIZE=200000
HISTCONTROL=ignoreboth:erasedups
HISTTIMEFORMAT="%F %T "
shopt -s histappend
shopt -s cmdhist
EOF
fi

echo "[✔] bash aliases written to ~/.bash_aliases"
echo "    Reload: source ~/.bashrc"
