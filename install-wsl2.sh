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
step "1/8: System Packages"
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
step "2/8: Nerd Fonts (WSL)"
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
step "3/8: Neovim"
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
step "4/8: Starship Prompt"
if check_cmd starship; then
    ok "starship binary"
else
    fail "starship binary"
    curl -sS https://starship.rs/install.sh | sh -s -- -y
    ok "starship installed"
fi

# ── 5. Zoxide ──
step "5/8: Zoxide"
if check_cmd zoxide; then
    ok "zoxide binary"
else
    fail "zoxide binary"
    curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
    ok "zoxide installed"
fi

# ── 6. Dotfiles (stow) ──
step "6/8: Dotfiles (stow)"
if ! check_cmd stow; then
    fail "stow"
    sudo apt install -y stow
    ok "stow installed"
fi

cd "$SCRIPTS_DIR"

if stow -R --target="$HOME" common; then
    ok "common symlinked"
else
    fail "common stow"
    fix "stow may have partial links — check manually"
fi

if stow -R --target="$HOME" wsl2; then
    ok "wsl2 symlinked"
else
    fail "wsl2 stow"
    fix "stow may have partial links — check manually"
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

# Tmux TPM plugins
TPM_DIR="$HOME/.tmux/plugins/tpm"
if [ ! -d "$TPM_DIR" ]; then
    fix "installing TPM"
    mkdir -p "$HOME/.tmux/plugins"
    git clone https://github.com/tmux-plugins/tpm "$TPM_DIR"
    "$TPM_DIR/bin/install_plugins" || true
    ok "TPM plugins installed"
fi

# ── 7. Kotlin/Android Development (Optional) ──
step "7/8: Kotlin/Android Development"

read -rp "  Install Kotlin/Android development tools? [y/N] " REPLY_ANDROID

if [[ "$REPLY_ANDROID" =~ ^[Yy]$ ]]; then
    ANDROID_SDK="$HOME/android-sdk"

    # ── 7a. Java & Dependencies ──
    if check_cmd java; then
        ok "java available"
    else
        fail "java"
        fix "installing default-jdk-headless"
        sudo apt install -y default-jdk-headless
        ok "java installed"
    fi

    # ── 7b. Android cmdline-tools ──
    if [ -d "$ANDROID_SDK/cmdline-tools/latest/bin" ]; then
        ok "Android cmdline-tools"
    else
        fail "Android cmdline-tools"
        mkdir -p "$ANDROID_SDK/cmdline-tools"
        cd /tmp
        fix "downloading Android command line tools"
        wget https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip -O cmdline-tools.zip
        unzip -q cmdline-tools.zip
        mv cmdline-tools "$ANDROID_SDK/cmdline-tools/latest"
        rm -f cmdline-tools.zip
        ok "Android cmdline-tools installed"
    fi

    # ── 7c. Environment Variables ──
    NEED_BASHRC=false
    grep -q 'export ANDROID_HOME=' "$HOME/.bashrc" 2>/dev/null && ok "ANDROID_HOME" || { fail "ANDROID_HOME"; NEED_BASHRC=true; }
    grep -q 'ANDROID_HOME/cmdline-tools/latest/bin' "$HOME/.bashrc" 2>/dev/null && ok "cmdline-tools PATH" || { fail "cmdline-tools PATH"; NEED_BASHRC=true; }
    grep -q 'ANDROID_HOME/platform-tools' "$HOME/.bashrc" 2>/dev/null && ok "platform-tools PATH" || { fail "platform-tools PATH"; NEED_BASHRC=true; }

    if $NEED_BASHRC; then
        fix "appending missing Android SDK exports to ~/.bashrc"
        cat >> "$HOME/.bashrc" << 'EOF'

# Android SDK
export ANDROID_HOME="$HOME/android-sdk"
export PATH="$PATH:$ANDROID_HOME/cmdline-tools/latest/bin"
export PATH="$PATH:$ANDROID_HOME/platform-tools"
EOF
        ok "Android SDK exports added to .bashrc"
    fi

    # Source in current shell for script continuation
    export ANDROID_HOME="$HOME/android-sdk"
    export PATH="$PATH:$ANDROID_HOME/cmdline-tools/latest/bin"
    export PATH="$PATH:$ANDROID_HOME/platform-tools"

    # ── 7d. SDK Packages ──
    SDKMANAGER="$ANDROID_SDK/cmdline-tools/latest/bin/sdkmanager"

    # Licenses
    if [ -d "$ANDROID_SDK/licenses" ] && [ "$(ls -A "$ANDROID_SDK/licenses" 2>/dev/null)" ]; then
        ok "SDK licenses accepted"
    else
        fail "SDK licenses"
        fix "accepting licenses"
        yes | "$SDKMANAGER" --licenses || true
        ok "SDK licenses accepted"
    fi

    MISSING=""
    if [ -d "$ANDROID_SDK/platform-tools" ]; then
        ok "platform-tools"
    else
        fail "platform-tools"
        MISSING="$MISSING platform-tools"
    fi

    if [ -d "$ANDROID_SDK/platforms/android-34" ]; then
        ok "platforms;android-34"
    else
        fail "platforms;android-34"
        MISSING="$MISSING platforms;android-34"
    fi

    if [ -d "$ANDROID_SDK/build-tools/34.0.0" ]; then
        ok "build-tools;34.0.0"
    else
        fail "build-tools;34.0.0"
        MISSING="$MISSING build-tools;34.0.0"
    fi

    if [ -n "$MISSING" ]; then
        fix "installing missing:$MISSING"
        # shellcheck disable=SC2086
        if "$SDKMANAGER" $MISSING; then
            ok "SDK packages installed"
        else
            fail "SDK package installation (check internet)"
        fi
    fi

    # ── 7e. ADB Bridge (WSL2 → Windows) ──
    if grep -qi microsoft /proc/version 2>/dev/null; then
        if grep -q "ADB_SERVER_SOCKET" "$HOME/.bashrc" 2>/dev/null; then
            ok "ADB WSL2 socket configured"
        else
            fail "ADB WSL2 socket"
            fix "adding ADB_SERVER_SOCKET to ~/.bashrc"
            cat >> "$HOME/.bashrc" << 'EOF'

# ADB bridge (WSL2 → Windows)
export ADB_SERVER_SOCKET=tcp:$(cat /etc/resolv.conf | grep nameserver | awk '{print $2}'):5037
EOF
            ok "ADB_SERVER_SOCKET added to .bashrc"
        fi

        if check_cmd powershell.exe; then
            # ── Install ADB on Windows ──
            if powershell.exe -Command "if (Get-Command adb -ErrorAction SilentlyContinue) { exit 0 } else { exit 1 }"; then
                ok "ADB available on Windows"
            else
                fail "ADB not found on Windows"
                fix "installing via winget"
                if powershell.exe -Command "winget install Google.AndroidPlatformTools --accept-package-agreements --accept-source-agreements"; then
                    ok "ADB installed via winget"
                else
                    fail "winget install failed"
                    fix "Install manually: scoop install adb  or  winget install Google.AndroidPlatformTools"
                fi
            fi

            # ── Install Android Studio on Windows ──
            if powershell.exe -Command "if (Test-Path 'C:\Program Files\Android\Android Studio\bin\studio64.exe') { exit 0 } else { exit 1 }"; then
                ok "Android Studio installed on Windows"
            else
                fail "Android Studio not found"
                fix "installing via winget (large download)"
                if powershell.exe -Command "winget install Google.AndroidStudio --accept-package-agreements --accept-source-agreements"; then
                    ok "Android Studio installed via winget"
                else
                    fail "winget install failed"
                    fix "Install manually: winget install Google.AndroidStudio"
                fi
            fi

            # ── Start ADB server on Windows ──
            if powershell.exe -Command "if (Get-Command adb -ErrorAction SilentlyContinue) { exit 0 } else { exit 1 }"; then
                fix "starting ADB server on Windows"
                powershell.exe -Command "adb kill-server" || true
                if powershell.exe -Command "Start-Process adb -ArgumentList '-a -P 5037 nodaemon server' -WindowStyle Hidden"; then
                    ok "ADB server started on Windows"
                else
                    fail "Could not start ADB on Windows"
                fi
            fi
        fi
    fi
fi

# ── 8. Git push ──
step "8/8: Git push"
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
echo "  tmux            (then prefix + I for plugins)"
echo "  nvim            (plugins auto-install on first launch)"
