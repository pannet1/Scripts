# ~/.bashrc: executed by bash(1) for non-login shells.
# see /usr/share/doc/bash/examples/startup-files (in the package bash-doc)
# for examples

# If not running interactively, don't do anything
case $- in
*i*) ;;
*) return ;;
esac

HISTSIZE=100000
HISTFILESIZE=200000
HISTCONTROL=ignoreboth:erasedups
HISTTIMEFORMAT="%F %T "

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# If set, the pattern "**" used in a pathname expansion context will
# match all files and zero or more directories and subdirectories.
#shopt -s globstar

# make less more friendly for non-text input files, see lesspipe(1)
#[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# set variable identifying the chroot you work in (used in the prompt below)
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
  debian_chroot=$(cat /etc/debian_chroot)
fi

# set a fancy prompt (non-color, unless we know we "want" color)
case "$TERM" in
xterm-color | *-256color) color_prompt=yes ;;
esac

# uncomment for a colored prompt, if the terminal has the capability; turned
# off by default to not distract the user: the focus in a terminal window
# should be on the output of commands, not on the prompt
#force_color_prompt=yes

if [ -n "$force_color_prompt" ]; then
  if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
    # We have color support; assume it's compliant with Ecma-48
    # (ISO/IEC-6429). (Lack of such support is extremely rare, and such
    # a case would tend to support setf rather than setaf.)
    color_prompt=yes
  else
    color_prompt=
  fi
fi

if [ "$color_prompt" = yes ]; then
  PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
else
  PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
fi
unset color_prompt force_color_prompt

# If this is an xterm set the title to user@host:dir
case "$TERM" in
xterm* | rxvt*)
  PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
  ;;
*) ;;
esac

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
  test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
  alias ls='ls --color=auto'
  #alias dir='dir --color=auto'
  #alias vdir='vdir --color=auto'

  #alias grep='grep --color=auto'
  #alias fgrep='fgrep --color=auto'
  #alias egrep='egrep --color=auto'
fi

# colored GCC warnings and errors
#export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'

# some more ls aliases
#alias ll='ls -l'
#alias la='ls -A'
#alias l='ls -CF'

# Alias definitions.
# You may want to put all your additions into a separate file like
# ~/.bash_aliases, instead of adding them here directly.
# See /usr/share/doc/bash-doc/examples in the bash-doc package.

if [ -f ~/.bash_aliases ]; then
  . ~/.bash_aliases
fi

# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

export PATH=$PATH:~/programs/shell/github.com/pannet1/Scripts/client:/home/pannet1/programs/shell/github.com/pannet1/Scripts/git_hooks:~/.local/bin
eval "$(starship init bash)"
eval "$(zoxide init bash)"
export GPG_TTY=$(tty)

# working but commened out for openclaw
#export NVM_DIR="$HOME/.nvm"
#[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"                   # This loads nvm
#[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion" # This loads nvm bash_completion

# Auto-start tmux if not already inside it
# if [ -z "$TMUX" ]; then
#    tmux attach-session -t default || tmux new-session -s default
# fi

export PATH="$HOME/.npm-global/bin:$PATH"
if grep -qi microsoft /proc/version 2>/dev/null; then
  if grep -qi microsoft /proc/version 2>/dev/null; then
    if grep -qi microsoft /proc/version 2>/dev/null; then
      if grep -qi microsoft /proc/version 2>/dev/null; then
        export LD_LIBRARY_PATH=/usr/lib/wsl/lib:$LD_LIBRARY_PATH
        export WSL_DISABLE_INTEROP=1
        alias usbread='sudo mkdir -p /mnt/d && sudo mount -t drvfs D: /mnt/d && echo "USB Updated Successfully"'
      fi
    fi
  fi
fi
alias mail='/usr/bin/aerc'

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
export EDITOR="/usr/bin/nvim"
###-begin-opencode-completions-###
#
# yargs command completion script
#
# Installation: opencode completion >> ~/.bashrc
#    or opencode completion >> ~/.bash_profile on OSX.
#
_opencode_yargs_completions() {
  local cur_word args type_list

  cur_word="${COMP_WORDS[COMP_CWORD]}"
  args=("${COMP_WORDS[@]}")

  # ask yargs to generate completions.
  # see https://stackoverflow.com/a/40944195/7080036 for the spaces-handling awk
  mapfile -t type_list < <(opencode --get-yargs-completions "${args[@]}")
  mapfile -t COMPREPLY < <(compgen -W "$(printf '%q ' "${type_list[@]}")" -- "${cur_word}" |
    awk '/ / { print "\""$0"\"" } /^[^ ]+$/ { print $0 }')

  # if no match was found, fall back to filename completion
  if [ ${#COMPREPLY[@]} -eq 0 ]; then
    COMPREPLY=()
  fi

  return 0
}
complete -o bashdefault -o default -F _opencode_yargs_completions opencode
###-end-opencode-completions-###
export EDITOR=nvim
export VISUAL=nvim
export PAGER=less
export LESS=-RFX
[ -f ~/.bash_aliases ] && . ~/.bash_aliases
[ -f /usr/share/bash-completion/bash_completion ] && . /usr/share/bash-completion/bash_completion

# Local secrets (machine-specific, not tracked in git)
SECRETS_REPO="$HOME/programs/shell/github.com/pannet1/secrets"
[ -f "$HOME/secrets.key" ] && (cd "$SECRETS_REPO" && git-crypt unlock "$HOME/secrets.key") 2>/dev/null || true
[ -f "$HOME/.secrets/wsl2.env" ] && source "$HOME/.secrets/wsl2.env"

export LLAMACPP="$HOME/llama.cpp"
export PATH="$LLAMACPP/build/bin:$PATH"

# Android SDK
export ANDROID_HOME="$HOME/android-sdk"
export PATH="$PATH:$ANDROID_HOME/cmdline-tools/latest/bin"
export PATH="$PATH:$ANDROID_HOME/platform-tools"

# ADB bridge (WSL2 → Windows)
export ADB_SERVER_SOCKET=tcp:$(cat /etc/resolv.conf | grep nameserver | awk '{print $2}'):5037

# opencode
export PATH=/home/pannet1/.opencode/bin:$PATH

# ffile: find files by pattern, excluding venv/git/cache
ffile() {
  find . -name "$1" -not -path './.venv/*' -not -path './.git/*' -not -path './.pytest_cache/*' 2>/dev/null
}
