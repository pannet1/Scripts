# SSH agent for git operations
if [ -z "$SSH_AUTH_SOCK" ] && [ -f ~/.ssh/id_ed25519 ]; then
    eval $(ssh-agent -s) >/dev/null 2>&1
fi

export PATH=$PATH:~/Scripts/client/:/root/Scripts/alpine/:/media/usb/Scripts/alpine/

# Launch welcome menu if interactive login and not already running
if [ -t 0 ] && [ -z "$WELCOME_RAN" ]; then
    export WELCOME_RAN=1
    WELCOME=$(command -v welcome.sh 2>/dev/null || echo "/root/Scripts/alpine/welcome.sh" 2>/dev/null)
    [ -x "$WELCOME" ] && "$WELCOME"
fi
