#!/bin/bash

set -e

FONT_DIR="$HOME/.local/share/fonts"
NERD_FONT_NAME="FiraCode"
NERD_FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip"

echo "[+] Creating font directory if it doesn't exist..."
mkdir -p "$FONT_DIR"

echo "[+] Downloading $NERD_FONT_NAME Nerd Font..."
cd /tmp
curl -fLo FiraCode.zip -L "$NERD_FONT_URL"

echo "[+] Extracting font files..."
unzip -o FiraCode.zip -d "$FONT_DIR"
rm FiraCode.zip

echo "[+] Rebuilding font cache..."
fc-cache -fv

echo "[✔] Nerd Font installation complete!"
echo "    Font installed for WSL apps (tmux, nvim, etc.)"
echo "    Windows Terminal font is set automatically by pwsh/2_install_debian.ps1"
echo ""
echo "[+] Verify: fc-list | grep 'FiraCode'"
