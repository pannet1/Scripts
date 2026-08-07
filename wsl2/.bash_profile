# ~/.bash_profile: executed by bash for login shells.
# Source .bashrc (which handles interactive shell setup)
if [ -f "$HOME/.bashrc" ]; then
    . "$HOME/.bashrc"
fi


# Added by Antigravity CLI installer
export PATH="/home/pannet1/.local/bin:$PATH"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
