#!/usr/bin/env bash
set -euo pipefail

[ "$(id -u)" -ne 0 ] || { echo "Run as normal user (no sudo): $0"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
export PATH="$HOME/.local/bin:$HOME/.opencode/bin:$PATH"

ok()   { echo "  $1 ✓"; }
fail() { echo "  $1 ✗"; }
fix()  { echo "  → $1"; }
step() { echo ""; echo "--- $1 ---"; }
check_cmd() { command -v "$1" &>/dev/null || [ -x "$HOME/.local/bin/$1" ] || [ -x "$HOME/.opencode/bin/$1" ] || [ -x "$HOME/.bun/bin/$1" ]; }

ensure_pkg() {
    local missing=""
    for p in "$@"; do dpkg -s "$p" &>/dev/null || missing="$missing $p"; done
    [ -n "$missing" ] || { ok "packages present"; return; }
    fail "missing:$missing"
    fix "apt install$missing"
    sudo apt install -y $missing
    ok "packages installed"
}

echo "=============================================="
echo "  Debian Setup"
echo "=============================================="

# ── 0. Self-bootstrap: ensure we run from a full repo checkout ──
step "0/13: Repo checkout"
REPO_DIR="$HOME/programs/shell/github.com/pannet1/Scripts"
if [ -d "$SCRIPT_DIR/common" ] && [ -d "$SCRIPT_DIR/debian" ]; then
    ok "running from checkout: $SCRIPT_DIR"
else
    fail "running from checkout (script was piped via curl?)"
    if ! command -v git &>/dev/null; then
        fix "installing git"
        sudo apt update -y
        sudo apt install -y git
    fi
    if [ -d "$REPO_DIR/.git" ]; then
        fix "updating existing checkout at $REPO_DIR"
        git -C "$REPO_DIR" pull --ff-only -q || true
    else
        fix "cloning repo to $REPO_DIR"
        mkdir -p "$(dirname "$REPO_DIR")"
        git clone --depth 1 https://github.com/pannet1/Scripts.git "$REPO_DIR"
    fi
    ok "re-executing installer from $REPO_DIR"
    exec bash "$REPO_DIR/install-debian.sh"
fi

# ── 1. apt sources (match installed release) ──
step "1/13: apt sources"
RELEASE_CODENAME="$(. /etc/os-release && echo "$VERSION_CODENAME")"
ACTIVE_DEB="$(grep -rhE '^deb ' /etc/apt/sources.list /etc/apt/sources.list.d/ 2>/dev/null || true)"
if echo "$ACTIVE_DEB" | grep -qs "$RELEASE_CODENAME" && echo "$ACTIVE_DEB" | grep -qs non-free-firmware; then
    ok "sources = $RELEASE_CODENAME + non-free-firmware"
else
    fail "sources"
    fix "writing $RELEASE_CODENAME sources (main contrib non-free non-free-firmware)"
    sudo rm -rf /etc/apt/sources.list.d/*.sources /etc/apt/sources.list.d/*.list
    sudo tee /etc/apt/sources.list > /dev/null << EOF
deb http://deb.debian.org/debian/ $RELEASE_CODENAME main contrib non-free non-free-firmware
deb http://deb.debian.org/debian/ ${RELEASE_CODENAME}-updates main contrib non-free non-free-firmware
deb http://security.debian.org/debian-security ${RELEASE_CODENAME}-security main contrib non-free non-free-firmware
EOF
    ok "sources rewritten"
fi

# ── 2. System update ──
step "2/13: System update"
sudo apt update -y
sudo apt --fix-broken install -y
sudo apt dist-upgrade -y
ok "system up to date"

# ── 3. OpenCode (early, so we can fix issues during install) ──
step "3/13: OpenCode"
ensure_pkg curl
if check_cmd opencode; then
    ok "opencode binary"
else
    fail "opencode"
    fix "installing opencode"
    curl -fsSL https://opencode.ai/install -o /tmp/opencode-install.sh
    bash /tmp/opencode-install.sh
    rm -f /tmp/opencode-install.sh
    ok "opencode installed"
fi

# ── 4. Core packages ──
step "4/13: Core packages"
ensure_pkg git curl stow unzip fontconfig xinit xserver-xorg x11-apps x11-xserver-utils xfonts-base xfonts-75dpi xfonts-100dpi \
    libpangocairo-1.0-0 build-essential pkg-config ripgrep fd-find tmux picom alacritty \
    rofi flameshot scrot xwallpaper pcmanfm udisks2 network-manager-gnome ibus xfce4-power-manager \
    alsa-utils fonts-font-awesome fonts-jetbrains-mono libnotify-bin \
    fonts-noto-core fonts-samyak-taml fonts-lohit-taml fonts-taml \
    p7zip-full p7zip-rar rar xdg-utils bind9-dnsutils smartmontools \
    libavcodec-extra61 \
    firefox-esr

# ── 5. Networking ──
step "5/13: Networking"
if check_cmd nmcli; then
    ok "NetworkManager"
else
    fail "NetworkManager"
    ensure_pkg network-manager isc-dhcp-client wpasupplicant firmware-realtek firmware-misc-nonfree firmware-atheros
    sudo systemctl enable --now NetworkManager
    ok "NetworkManager enabled"
fi

# ── 6. NVIDIA ──
step "6/13: NVIDIA"
if lspci 2>/dev/null | grep -qi "VGA.*NVIDIA"; then
    if lsmod | grep -q "^nvidia "; then
        ok "nvidia module loaded"
    else
        fail "nvidia not loaded (nouveau in use)"
        echo -e "blacklist nouveau\noptions nouveau modeset=0" | sudo tee /etc/modprobe.d/blacklist-nouveau.conf > /dev/null
        echo -e "options nvidia_drm modeset=1 fbdev=1" | sudo tee /etc/modprobe.d/nvidia-drm.conf > /dev/null
        sudo mkdir -p /etc/X11/xorg.conf.d
        sudo tee /etc/X11/xorg.conf.d/20-nvidia.conf > /dev/null << 'EOF'
Section "Device"
    Identifier "nvidia"
    Driver "nvidia"
    Option "nvidia-drm-modeset" "1"
    Option "TearFree" "true"
EndSection
EOF
        ensure_pkg linux-headers-$(uname -r) dkms firmware-misc-nonfree
        ensure_pkg nvidia-driver nvidia-kernel-dkms
        sudo modprobe nvidia 2>/dev/null || {
            fix "dkms build failed — purging and reinstalling"
            sudo apt purge "nvidia*" -y
            sudo apt autoremove --purge -y
            ensure_pkg nvidia-driver nvidia-kernel-dkms
            sudo modprobe nvidia
        }
        sudo update-initramfs -u
        fix "REBOOT to finish loading NVIDIA"
    fi
else
    ok "no NVIDIA GPU"
fi

# ── 7. Neovim ──
step "7/13: Neovim"
# luarocks (lua-language-server workspace check) + lazygit (LazyVim git UI)
# must be present before nvim: missing them makes nvim saves block for seconds.
# xclip provides the X11 clipboard for nvim's "+ register.
ensure_pkg luarocks lazygit xclip
if check_cmd nvim; then
    ok "nvim binary"
else
    fail "nvim"
    if apt-cache policy nvim 2>/dev/null | grep -q "Candidate:"; then
        ensure_pkg nvim
    else
        fix "installing latest nvim from GitHub"
        cd /tmp
        curl -fsSL -o nvim.tar.gz "https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz"
        sudo rm -rf /opt/nvim
        sudo tar -xzf nvim.tar.gz -C /opt
        sudo ln -sf /opt/nvim-linux-x86_64/bin/nvim /usr/local/bin/nvim
        rm -f nvim.tar.gz
        cd "$SCRIPT_DIR"
    fi
    ok "nvim installed"
fi

# ── 8. Node.js / npm (to ~/.local) ──
step "8/13: Node.js / npm"
if check_cmd node && check_cmd npm; then
    ok "node $(node --version) / npm $(npm --version)"
else
    fail "node/npm"
    fix "installing latest Node.js LTS to ~/.local"
    mkdir -p "$HOME/.local/bin"
    NODE_VERSION="$(curl -fsSL https://nodejs.org/dist/index.json | python3 -c "import json,sys; print(next(x['version'] for x in json.load(sys.stdin) if x.get('lts')))")"
    curl -fsSL "https://nodejs.org/dist/$NODE_VERSION/node-$NODE_VERSION-linux-x64.tar.xz" -o /tmp/node.tar.xz
    tar -xJf /tmp/node.tar.xz -C "$HOME/.local" --strip-components=1
    rm -f /tmp/node.tar.xz
    ok "node $NODE_VERSION installed"
fi

# ── 9. Qtile (via uv) ──
step "9/13: Qtile"
if check_cmd uv; then
    ok "uv binary"
else
    fail "uv"
    fix "installing uv"
    curl -LsSf https://astral.sh/uv/install.sh | sh
    ok "uv installed"
fi
if uv tool list 2>/dev/null | grep -q qtile; then
    ok "qtile (uv)"
else
    fail "qtile (uv)"
    uv tool install qtile
    ok "qtile installed via uv"
fi
if [ -f "$HOME/.xinitrc" ] && grep -q "qtile" "$HOME/.xinitrc"; then
    ok ".xinitrc"
else
    fix "writing ~/.xinitrc"
    cat << 'EOF' > "$HOME/.xinitrc"
#!/bin/sh
exec ~/.local/bin/qtile start
EOF
    chmod +x "$HOME/.xinitrc"
    ok ".xinitrc written"
fi

# ── 10. Shell tools ──
step "10/13: Shell tools"
ensure_pkg git-crypt adb
if check_cmd starship; then
    ok "starship binary"
else
    fail "starship"
    fix "installing starship"
    curl -sS https://starship.rs/install.sh | sh -s -- -y
    ok "starship installed"
fi
if check_cmd zoxide; then
    ok "zoxide binary"
else
    fail "zoxide"
    fix "installing zoxide"
    curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
    ok "zoxide installed"
fi
if check_cmd bun; then
    ok "bun binary"
else
    fail "bun"
    fix "installing bun (PATH set in .bashrc)"
    curl -fsSL https://bun.sh/install | bash 2>/dev/null || true
    ok "bun installed"
fi
if check_cmd wallust; then
    ok "wallust binary"
else
    fail "wallust"
    fix "installing wallust (prebuilt binary — not a Python package, so uv can't install it)"
    mkdir -p "$HOME/.local/bin"
    curl -fsSL -o /tmp/wallust.tar.gz "https://codeberg.org/explosion-mental/wallust/releases/download/3.5.2/wallust-3.5.2-x86_64-unknown-linux-musl.tar.gz"
    tar -xzf /tmp/wallust.tar.gz -C "$HOME/.local/bin" wallust
    rm -f /tmp/wallust.tar.gz
    ok "wallust installed"
fi

FONT_DIR="$HOME/.local/share/fonts"
if ls "$FONT_DIR"/FiraCode*.ttf &>/dev/null; then
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
    if ls "$FONT_DIR"/FiraCode*.ttf &>/dev/null; then
        ok "FiraCode Nerd Font installed"
    else
        fail "FiraCode Nerd Font install FAILED"
    fi
fi

# ── 11. Dotfiles (stow) ──
step "11/13: Dotfiles (stow)"
cd "$SCRIPT_DIR"
backup_dir="$HOME/.dotfiles-backup/$(date +%Y%m%d_%H%M%S)"
backed_up=false

for pkg in common debian; do
    [ -d "$pkg" ] || continue
    while read -r f; do
        rel="${f#"$pkg/"}"
        target="$HOME/$rel"
        # Skip if target already resolves to this package's own file
        # (stow-managed dir, e.g. ~/.config/qtile/config -> package dir).
        # Otherwise readlink resolves through the symlinked dir and we'd
        # back up + delete the package's source file itself.
        if [ -e "$target" ] && [ "$(readlink -f "$target")" = "$(readlink -f "$f")" ]; then
            continue
        fi
        if [ -e "$target" ] && ! [ -L "$target" ]; then
            mkdir -p "$(dirname "$backup_dir/$rel")"
            cp -a "$target" "$backup_dir/$rel"
            rm -f "$target"
            backed_up=true
            fix "backing up ~/$rel"
        elif [ -L "$target" ]; then
            rm "$target"
        fi
    done < <(find "$pkg" -type f -not -path "*/node_modules/*" -not -path "*/.git/*" -not -path "*/kilo/*" -not -path "*/ZCode/*")
    if stow -R --target="$HOME" "$pkg"; then
        ok "$pkg symlinked"
    else
        fail "$pkg stow"
        fix "stow may have partial links — check manually"
    fi
done

[ "$backed_up" = true ] && echo "    → Backed up to $backup_dir"

# ── 12. User systemd services ──
step "12/13: User systemd services"
systemctl --user daemon-reload
for svc in picom; do
    if systemctl --user enable "$svc.service" 2>/dev/null; then
        ok "$svc.service enabled"
    else
        fail "$svc.service enable"
        fix "check unit exists after stow"
    fi
done

# ── 13. LazyVim (nvim config) ──
step "13/13: LazyVim"
if [ -d "$HOME/.config/nvim" ] && [ -n "$(ls -A "$HOME/.config/nvim" 2>/dev/null)" ]; then
    ok "nvim config present"
else
    fail "nvim config"
    rm -rf "$HOME/.config/nvim"
    fix "cloning LazyVim starter"
    git clone --depth 1 https://github.com/LazyVim/starter "$HOME/.config/nvim"
    rm -rf "$HOME/.config/nvim/.git"
    ok "LazyVim starter cloned (plugins auto-install on first launch)"
fi

echo ""
echo "=============================================="
echo "  Done!"
echo "=============================================="
echo ""
echo "  Reboot (NVIDIA), then: startx"
echo "  tmux            (then prefix + I for plugins)"
echo "  nvim            (plugins auto-install on first launch)"
