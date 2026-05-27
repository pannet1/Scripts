#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPTS_DIR="$SCRIPT_DIR"

ok()    { echo "  $1 ✓"; }
fail()  { echo "  $1 ✗"; }
fix()   { echo "  → $1"; }
step()  { echo ""; echo "--- $1 ---"; }
check_cmd()   { command -v "$1" &>/dev/null; }
check_file()  { [ -f "$1" ]; }
check_dir()   { [ -d "$1" ]; }
check_line()  { grep -Fxq "$1" "$2" 2>/dev/null; }
check_font()  { fc-list | grep -qi "$1" &>/dev/null; }

echo "=============================================="
echo "  WSL2 Debian Setup"
echo "=============================================="

# ── 1. Packages ──
step "1/7: System Packages"
PACKAGES="git curl wget fontconfig file tar zip unzip gzip tmux xclip build-essential pkg-config ripgrep fd-find lazygit python3 python3-pip python3-venv"

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
        sudo apt update -y && sudo apt upgrade -y
        sudo apt install -y $PACKAGES
        ok "packages installed"
    fi
    if ! $TZ_OK; then
        fail "timezone"
        sudo ln -sf /usr/share/zoneinfo/Asia/Kolkata /etc/localtime
        ok "timezone Asia/Kolkata"
    fi
fi

# ── 2. Nerd Fonts ──
step "2/7: Nerd Fonts"
FONT_DIR="$HOME/.local/share/fonts"
if ls "$FONT_DIR"/FiraCode*.ttf &>/dev/null && check_font "FiraCode"; then
    ok "FiraCode Nerd Font installed"
else
    fail "FiraCode Nerd Font"
    mkdir -p "$FONT_DIR"
    cd /tmp
    curl -fLo FiraCode.zip -L "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip"
    unzip -o FiraCode.zip -d "$FONT_DIR" >/dev/null
    rm FiraCode.zip
    fc-cache -f "$FONT_DIR" >/dev/null 2>&1
    ok "FiraCode Nerd Font installed"
fi

# ── 3. Neovim ──
step "3/7: Neovim"
if check_cmd nvim; then
    ok "nvim binary"
else
    fail "nvim binary"
    NVIM_URL="https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz"
    cd /tmp
    curl -LO "$NVIM_URL"
    sudo rm -rf /opt/nvim
    tar -xzf nvim-linux-x86_64.tar.gz
    sudo mv nvim-linux-x86_64 /opt/nvim
    sudo ln -sf /opt/nvim/bin/nvim /usr/local/bin/nvim
    rm -f nvim-linux-x86_64.tar.gz
    ok "nvim installed"
fi

# ── 4. Starship ──
step "4/7: Starship Prompt"
if check_cmd starship; then
    ok "starship binary"
else
    fail "starship binary"
    curl -sS https://starship.rs/install.sh | sh -s -- -y
    ok "starship installed"
fi

# ── 5. Zoxide ──
step "5/7: Zoxide"
if check_cmd zoxide; then
    ok "zoxide binary"
else
    fail "zoxide binary"
    curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
    ok "zoxide installed"
fi

# ── 6. Dotfiles (stow) ──
step "6/7: Dotfiles (stow)"
if ! check_cmd stow; then
    fail "stow"
    sudo apt install -y stow
    ok "stow installed"
fi

cd "$SCRIPTS_DIR"

stow -R --target="$HOME" common 2>/dev/null || stow --target="$HOME" common
ok "common symlinked"

stow -R --target="$HOME" wsl2 2>/dev/null || stow --target="$HOME" wsl2
ok "wsl2 symlinked"

# Tmux TPM plugins
TPM_DIR="$HOME/.tmux/plugins/tpm"
if [ ! -d "$TPM_DIR" ]; then
    fix "installing TPM"
    mkdir -p "$HOME/.tmux/plugins"
    git clone https://github.com/tmux-plugins/tpm "$TPM_DIR"
    "$TPM_DIR/bin/install_plugins" || true
    ok "TPM plugins installed"
fi

# ── 7. Git push ──
step "7/7: Git push"
git add -A
if ! git diff --cached --quiet; then
    git commit -m "wsl2: update $(date +%Y-%m-%d)"
    git push
    ok "pushed to origin"
else
    ok "nothing to commit"
fi

echo ""
echo "=== Done! ==="
