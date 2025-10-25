#!/bin/bash

# Exit immediately if a command exits with a non-zero status,
# treat unset variables as an error, and exit with last command's exit code.
set -euo pipefail

# --- VARIABLES ---
NVIM_URL="https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz"
TMP_DIR="/tmp"
NVIM_INSTALL_DIR="/opt/nvim"

echo "--- Starting Complete Neovim/LazyVim Setup for Debian/Python ---"

# -----------------------------------------------------
# 1. INSTALL SYSTEM UTILITIES AND DEPENDENCIES
# -----------------------------------------------------

echo "[1/5] Installing core system utilities and dependencies..."

# Install essential utilities and tools needed for plugins (ripgrep, fd-find)
sudo apt install -y \
	build-essential \
	pkg-config \
	ripgrep \
	fd-find \
	lazygit

# Fix 'fd' command name on Debian/Ubuntu (it installs as 'fdfind')
echo "[*] Creating symlink for 'fd-find' to 'fd'..."
if [ ! -f /usr/local/bin/fd ]; then
	sudo ln -s "$(which fdfind)" /usr/local/bin/fd
fi

# -----------------------------------------------------
# 2. INSTALL NEOCVIM (The editor itself)
# -----------------------------------------------------

echo "[2/5] Downloading and Installing Neovim..."
cd "$TMP_DIR"

echo "[*] Downloading latest Neovim release..."
curl -LO "$NVIM_URL"

echo "[*] Extracting and Installing Neovim to $NVIM_INSTALL_DIR..."
# The 'file' command is now installed, so we can run the validation check (line 15 from original request)
file nvim-linux-x86_64.tar.gz | grep "gzip compressed data" || {
	echo "[-] Downloaded file is not valid gzip archive. Aborting."
	exit 1
}

# Clean up any previous install directory and move the new one
sudo rm -rf "$NVIM_INSTALL_DIR"
tar -xzvf nvim-linux-x86_64.tar.gz
sudo mv nvim-linux-x86_64 "$NVIM_INSTALL_DIR"

echo "[*] Creating symlink for nvim..."
sudo ln -sf "$NVIM_INSTALL_DIR/bin/nvim" /usr/local/bin/nvim

# -----------------------------------------------------
# 3. CONFIGURE PATH
# -----------------------------------------------------

echo "[3/5] Ensuring necessary directories are in PATH..."

# Ensure /usr/local/bin is in PATH for the 'nvim' symlink
if ! echo "$PATH" | grep -q "/usr/local/bin"; then
	echo "export PATH=/usr/local/bin:$PATH" >>~/.bashrc
fi

# -----------------------------------------------------
# 4. PYTHON VENV SUPPORT AND GLOBAL LSP
# -----------------------------------------------------

echo "[4/5] Installing Core Python System Tools and Global LSP Server..."

# Python 3 and venv support (required to manage virtual environments)
sudo apt install -y python3 python3-pip python3-venv

# Install essential Python tools GLOBALLY: LSP server and Neovim bridge
echo "[*] Installing Global Python LSP Server and Neovim Integration via pip..."
pip3 install --break-system-packages \
	python-lsp-server \
	pynvim

# Add the local user bin directory to the PATH for the installed Python tools (like the pylsp executable)
if ! echo "$PATH" | grep -q "${HOME}/.local/bin"; then
	echo 'export PATH="$HOME/.local/bin:$PATH"' >>~/.bashrc
fi

# -----------------------------------------------------
# 5. INSTALL LAZYVIM CONFIGURATION
# -----------------------------------------------------

echo "[5/5] Cloning LazyVim configuration..."

if [ -d "$HOME/.config/nvim" ]; then
	echo "WARNING: $HOME/.config/nvim already exists. Skipping LazyVim config clone."
	echo "Please back up and remove it manually if you wish to proceed."
else
	git clone https://github.com/LazyVim/starter "$HOME/.config/nvim"
	echo "LazyVim starter successfully cloned!"
fi

# -----------------------------------------------------
# 6. CLEANUP AND FINISH
# -----------------------------------------------------

echo "[*] Cleanup temporary files..."
rm -f "$TMP_DIR/nvim-linux-x86_64.tar.gz"

echo "nvim version: $(nvim --version | head -n 1)"
echo "---"
echo "--- [✔] Complete Neovim/LazyVim setup finished successfully! ---"
echo "---"
echo "--- NEXT STEPS: ---"
echo "1. Source your environment: source ~/.bashrc"
echo "2. Launch Neovim: nvim (The editor will download all Lua plugins on first run.)"
echo "3. Remember to install project-specific tools (black, isort, flake8) inside your venv."
echo "-------------------"
