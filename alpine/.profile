# SSH agent for git operations
if [ -z "$SSH_AUTH_SOCK" ] && [ -f ~/.ssh/id_ed25519 ]; then
    eval $(ssh-agent -s) >/dev/null 2>&1
fi

# Scan media mount points for Scripts directory
MEDIA_PATH=""
for m in /media/*; do
    if [ -d "$m/Scripts/alpine" ]; then
        MEDIA_PATH="$m/Scripts/alpine:$m"
        break
    fi
done
# Fallback: flat scripts on USB root
[ -z "$MEDIA_PATH" ] && for m in /media/*; do
    [ -f "$m/welcome.sh" ] && MEDIA_PATH="$m" && break
done
export PATH=$PATH:~/Scripts/client/:/root/Scripts/alpine/:${MEDIA_PATH}

# Launch welcome menu if interactive login and not already running
if [ -t 0 ] && [ -z "$WELCOME_RAN" ]; then
    export WELCOME_RAN=1
    WELCOME=$(command -v welcome.sh 2>/dev/null || echo "/root/Scripts/alpine/welcome.sh" 2>/dev/null)
    [ -x "$WELCOME" ] && "$WELCOME"
fi
