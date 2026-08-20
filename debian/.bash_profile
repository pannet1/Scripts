# ~/.bash_profile: executed by bash for login shells (Debian desktop).
# Source .bashrc (which handles interactive shell setup)
if [ -f "$HOME/.bashrc" ]; then
    . "$HOME/.bashrc"
fi

# Auto-start X + qtile on tty1 (getty autologin); inert elsewhere (ssh, pts)
if [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
    exec startx > "$HOME/.xsession-log" 2>&1
fi


# Added by Antigravity CLI installer
export PATH="/home/pannet1/.local/bin:$PATH"
. "$HOME/.cargo/env"
