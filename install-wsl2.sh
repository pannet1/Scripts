#!/bin/bash
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


echo "=============================================="
echo "  WSL2 Debian Setup"
echo "=============================================="

# ── 1. Packages ──
step "1/10: System Packages"
PACKAGES="git curl wget fontconfig file tar zip unzip gzip tmux xclip build-essential pkg-config ripgrep fd-find lazygit python3 python3-pip python3-venv sshpass openssh-client nmap tree gh sqlite3 cmake fzf rustc cargo"

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
step "2/10: Nerd Fonts (WSL)"
FONT_DIR="$HOME/.local/share/fonts"
font_files_exist() { ls "$FONT_DIR"/FiraCode*.ttf &>/dev/null; }

if font_files_exist; then
    ok "FiraCode Nerd Font installed"
else
    fail "FiraCode Nerd Font"
    mkdir -p "$FONT_DIR"
    cd /tmp
    fix "downloading FiraCode Nerd Font"
    curl -fLo FiraCode.zip -L "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip"
    unzip -o FiraCode.zip -d "$FONT_DIR" >/dev/null
    rm FiraCode.zip
    fc-cache -f "$FONT_DIR" >/dev/null 2>&1
    if font_files_exist; then
        ok "FiraCode Nerd Font installed"
    else
        fail "FiraCode Nerd Font install FAILED"
    fi
fi

# ── 3. Neovim ──
step "3/10: Neovim"
NVIM_DEPS="build-essential pkg-config ripgrep fd-find lazygit python3 python3-pip python3-venv"
NEEDS_NVIM=false

if check_cmd nvim; then
    ok "nvim binary"
else
    fail "nvim binary"; NEEDS_NVIM=true
fi

if $NEEDS_NVIM; then
    fix "installing nvim dependencies"
    [ ! -f /usr/local/bin/fd ] && command -v fdfind &>/dev/null && sudo ln -s "$(which fdfind)" /usr/local/bin/fd || true

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

    if pip3 list --format=columns 2>/dev/null | grep -q "python-lsp-server" && \
       pip3 list --format=columns 2>/dev/null | grep -q "pynvim"; then
        ok "pip packages already installed"
    else
        pip3 install --break-system-packages python-lsp-server pynvim || true
        ok "pip packages installed"
    fi
fi

# ── 4. Starship ──
step "4/10: Starship Prompt"
if check_cmd starship; then
    ok "starship binary"
else
    fail "starship binary"
    curl -sS https://starship.rs/install.sh | sh -s -- -y
    ok "starship installed"
fi

# ── 5. Zoxide ──
step "5/10: Zoxide"
if check_cmd zoxide; then
    ok "zoxide binary"
else
    fail "zoxide binary"
    curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
    ok "zoxide installed"
fi

# ── 6. bashrc Dependencies ──
step "6/10: bashrc Dependencies"

# Tools that .bashrc directly execs or references at source time.
# Install before dotfiles deploy so the first source is clean.

check_cmd git-crypt || fix "git-crypt"
check_cmd adb        || fix "adb"

sudo apt install -y git-crypt adb

if ! check_cmd bun; then
    fix "installing bun (PATH in .bashrc)"
    curl -fsSL https://bun.sh/install | bash 2>/dev/null || true
fi
ok "bashrc optional deps handled"

# Windows Terminal integration (WSL2-specific)
# Windows Terminal provides proper TERM propagation and the wt launcher.
# Install via winget on the Windows host, reachable from WSL2 through interop.
if grep -qi microsoft /proc/version 2>/dev/null; then
    if check_cmd wt.exe; then
        ok "Windows Terminal (wt.exe)"
    else
        fail "wt.exe not found"
        if check_cmd winget.exe; then
            fix "installing Windows Terminal via winget"
            winget.exe install --id Microsoft.WindowsTerminal --accept-package-agreements --accept-source-agreements 2>/dev/null || true
            if check_cmd wt.exe; then
                ok "Windows Terminal installed"
            else
                fix "winget install reported success but wt.exe still missing — try manually: winget install Microsoft.WindowsTerminal"
            fi
        else
            fix "winget.exe not found — install Windows Terminal from Microsoft Store, or install winget from https://github.com/microsoft/winget-cli"
            fix "  then re-run: winget install --id Microsoft.WindowsTerminal"
        fi
    fi
fi

# ── 7. WSL Config (.wslconfig) ──
step "7/10: WSL Config (.wslconfig)"
# Enable mirrored networking mode for full network feature parity.
# Requires Windows 11 22H2+. Skipped silently on older Windows.
# https://learn.microsoft.com/en-us/windows/wsl/networking#mirrored-mode-networking
configure_wsl_networking() {
    local win_home wsl_config
    win_home=$(wslpath "$(cmd.exe /c 'echo %USERPROFILE%' 2>/dev/null | tr -d '\r')" 2>/dev/null) || return
    [ -z "$win_home" ] && return
    wsl_config="$win_home/.wslconfig"

    if grep -qs "networkingMode=mirrored" "$wsl_config" 2>/dev/null; then
        ok "WSL mirrored networking already configured"
        return
    fi

    if [ -f "$wsl_config" ]; then
        if grep -qs "^\[wsl2\]" "$wsl_config" 2>/dev/null; then
            sed -i '/^\[wsl2\]/a networkingMode=mirrored' "$wsl_config"
        else
            printf "\n[wsl2]\nnetworkingMode=mirrored\n" >> "$wsl_config"
        fi
    else
        mkdir -p "$(dirname "$wsl_config")"
        printf "[wsl2]\nnetworkingMode=mirrored\n" > "$wsl_config"
    fi
    ok "WSL mirrored networking configured"
}
configure_wsl_networking

# ── 8. OpenCode ──
step "8/10: OpenCode"
if check_cmd opencode; then
    ok "opencode binary"
else
    fail "opencode binary"
    fix "installing opencode"
    curl -fsSL https://opencode.ai/install | bash -s -- --no-modify-path
    ok "opencode installed"
fi

# ── 9. Dotfiles (stow) ──
step "9/10: Dotfiles (stow)"
if ! check_cmd stow; then
    fail "stow"
    sudo apt install -y stow
    ok "stow installed"
fi

cd "$SCRIPTS_DIR"

# ── Backup pre-existing target files before stowing ──
# If stow finds a file at $HOME that it wants to manage, it errors out.
# The naive fix is to delete the file, which is how dotfiles get lost.
# Instead, back up any such files, then use --override to force the symlink.
backup_dir="$HOME/.dotfiles-backup/$(date +%Y%m%d_%H%M%S)"
backed_up=false

backup_conflicts() {
    local pkg="$1"
    # Walk all files managed by stow, skipping dirs stow shouldn't own
    # (node_modules, .git, etc. are runtime deps, not dotfiles)
    while read -r f; do
        local rel="${f#"$pkg/"}"
        local target="$HOME/$rel"
        if [ -e "$target" ] && ! [ -L "$target" ]; then
            mkdir -p "$(dirname "$backup_dir/$rel")"
            cp -a "$target" "$backup_dir/$rel"
            backed_up=true
            fix "backing up ~/$rel"
        fi
    done < <(find "$pkg" -type f \
        -not -path "*/node_modules/*" \
        -not -path "*/.git/*" \
        -not -path "*/__pycache__/*" \
        -not -path "*/target/*" \
        -not -name "*.pyc")
}

backup_conflicts common

# ── Remove conflicting symlinks ──
# Stow's --override only handles regular files, not symlinks.
# If a symlink already exists at a path stow manages (e.g. from a prior
# manual ln -sf), stow prints "Ignoring absolute symlink" and skips it.
# We remove any such symlinks here so stow can create its own relative ones.
while read -r f; do
    rel="${f#common/}"
    rel="${rel#wsl2/}"
    target="$HOME/$rel"
    if [ -L "$target" ]; then
        rm "$target"
        fix "removed stale symlink ~/$rel"
    fi
done < <(find common wsl2 -type f -o -type l \
    -not -path "*/node_modules/*" \
    -not -path "*/.git/*")
backup_conflicts wsl2

if $backed_up; then
    echo "    → Backed up to $backup_dir"
fi

# ── Stow with --override to recover from broken states ──
# --override tells stow to treat any existing target file as if it belongs
# to that package, allowing the symlink to be forced through.

if stow -R --override=common --target="$HOME" common; then
    ok "common symlinked"
else
    fail "common stow"
    fix "stow may have partial links — check manually"
fi

if stow -R --override=wsl2 --target="$HOME" wsl2; then
    ok "wsl2 symlinked"
else
    fail "wsl2 stow"
    fix "stow may have partial links — check manually"
fi

# ── Verify critical symlinks ──
# Check that the files stow manages are actually pointing back to the repo.
VERIFY_FAILED=false
verify_symlink() {
    local pkg="$1"
    local rel="$2"
    local link="$HOME/$rel"
    # Stow creates relative symlinks from the target. When run from SCRIPTS_DIR,
    # the link target for wsl2/.bashrc is ../wsl2/.bashrc (relative to $HOME).
    local expected="$SCRIPTS_DIR/$pkg/$rel"
    if [ -L "$link" ] && [ "$(readlink -f "$link")" = "$expected" ]; then
        ok "$rel"
    else
        fail "$rel → $expected"
        VERIFY_FAILED=true
    fi
}

verify_symlink common .gitconfig
verify_symlink common .bash_aliases
verify_symlink wsl2 .bashrc
verify_symlink wsl2 .bash_profile

if $VERIFY_FAILED; then
    fail "Some symlinks are incorrect"
    fix "Re-run: stow -R --override=PACKAGE --target=\"$HOME\" PACKAGE"
fi

# Secrets symlink
SECRETS_DIR="$HOME/programs/shell/github.com/pannet1/secrets"
SECRETS_ENV="$SECRETS_DIR/github.com/pannet1/shell/wsl2/.env"
if [ -d "$SECRETS_DIR" ]; then
    # Unlock git-crypt if key exists
    if [ -f "$HOME/secrets.key" ]; then
        cd "$SECRETS_DIR"
        if [ -f "$SECRETS_ENV" ] && grep -q "=" "$SECRETS_ENV" 2>/dev/null; then
            ok "secrets already unlocked"
        else
            git-crypt unlock "$HOME/secrets.key" || true
            ok "secrets unlocked"
        fi
    fi
    mkdir -p "$HOME/.secrets"
    ln -sf "$SECRETS_ENV" "$HOME/.secrets/wsl2.env"
    ok "secrets symlinked"
fi

# .agents symlink (opencode agent runtime)
AGENTS_DIR="$HOME/programs/shell/github.com/pannet1/Scripts/agents"
if [ -d "$AGENTS_DIR" ]; then
    ln -sfn "$AGENTS_DIR" "$HOME/.agents"
    ok ".agents symlinked"
fi

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
step "10/10: Git push"
git add -A
if ! git diff --cached --quiet; then
    git commit -m "wsl2: update $(date +%Y-%m-%d)"
    git push
    ok "pushed to origin"
else
    ok "nothing to commit"
fi

echo ""
echo "=============================================="
echo "  Done!"
echo "=============================================="
echo ""
echo "  source ~/.bashrc"
echo "  Backup:    $backup_dir  (if files were replaced)"
echo "  tmux            (then prefix + I for plugins)"
echo "  nvim            (plugins auto-install on first launch)"
