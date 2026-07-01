# SSH agent
if [ -z "$SSH_AUTH_SOCK" ] && [ -f ~/.ssh/id_ed25519 ]; then
    eval $(ssh-agent -s) >/dev/null 2>&1
fi

# Find and run welcome menu on interactive login
if [ -t 0 ] && [ -z "$WELCOME_RAN" ]; then
    export WELCOME_RAN=1
    for W in /media/*/welcome.sh "$HOME/Scripts/alpine/welcome.sh" /media/*/Scripts/alpine/welcome.sh; do
        [ -f "$W" ] && WELCOME="$W" && break
    done
    [ -n "$WELCOME" ] && PATH="$(dirname "$WELCOME"):$PATH" "$WELCOME"
fi
