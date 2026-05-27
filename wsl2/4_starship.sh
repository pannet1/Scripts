#!/bin/bash

set -e

if ! command -v starship &>/dev/null; then
    echo "[+] Installing Starship..."
    curl -sS https://starship.rs/install.sh | sh -s -- -y
fi

STARSHIP_DIR="$HOME/.config"
mkdir -p "$STARSHIP_DIR"

cat > "$STARSHIP_DIR/starship.toml" << 'EOF'
# ── Disable default modules ──
add_newline = true

# ── Format ──
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

right_format = ""

# ── Modules ──
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
up_to_date = ""
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
EOF

LINE='eval "$(starship init bash)"'
if ! grep -Fxq "$LINE" ~/.bashrc; then
    echo "$LINE" >> ~/.bashrc
    echo "[+] Added starship init to .bashrc"
else
    echo "[*] starship init already in .bashrc"
fi

echo "[✔] Starship configured!"
echo "    Config: ~/.config/starship.toml"
