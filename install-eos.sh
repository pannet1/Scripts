#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

ok()    { echo "  $1 ✓"; }
fail()  { echo "  $1 ✗"; }
fix()   { echo "  → $1"; }
step()  { echo ""; echo "--- $1 ---"; }
check_cmd() { command -v "$1" &>/dev/null; }

echo "=============================================="
echo "  EndeavourOS Setup"
echo "=============================================="

# ── 1. Packages ──
step "1/4: System Packages"
if ! check_cmd stow; then
    sudo pacman -S --noconfirm stow
fi

# ── 2. Dotfiles (stow) ──
step "2/4: Dotfiles (stow)"
cd "$SCRIPTS_DIR"

stow -R --target="$HOME" common 2>/dev/null || stow --target="$HOME" common
ok "common symlinked"

stow -R --target="$HOME" eos 2>/dev/null || stow --target="$HOME" eos
ok "eos symlinked"

# ── 3. Git push ──
step "3/4: Git push"
git add -A
if ! git diff --cached --quiet; then
    git commit -m "eos: update $(date +%Y-%m-%d)"
    git push
    ok "pushed to origin"
else
    ok "nothing to commit"
fi

# ── 4. Notes ──
step "4/4: Next steps"
echo "  Qtile:    startx or select from display manager"
echo "  Kitty:    kitty"
echo "  Xonsh:    xonsh (default shell)"
echo "  Picom:    picom --daemon"
echo "  Dunst:    dunst &"

echo ""
echo "=== Done! ==="
