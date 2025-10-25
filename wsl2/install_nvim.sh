#!/bin/bash

set -e

# Variables
NVIM_URL="https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz"
TMP_DIR="/tmp"
NVIM_INSTALL_DIR="/opt/nvim"

echo "[+] Downloading latest Neovim release..."
cd $TMP_DIR
curl -LO $NVIM_URL

echo "[+] Validating downloaded file..."
file nvim-linux-x86_64.tar.gz | grep "gzip compressed data" || {
	echo "[-] Downloaded file is not valid gzip archive. Aborting."
	exit 1
}

echo "[+] Extracting Neovim..."
tar -xzvf nvim-linux-x86_64.tar.gz

echo "[+] Installing Neovim to $NVIM_INSTALL_DIR..."
sudo rm -rf $NVIM_INSTALL_DIR
sudo mv nvim-linux-x86_64 $NVIM_INSTALL_DIR

echo "[+] Creating symlink..."
sudo ln -sf $NVIM_INSTALL_DIR/bin/nvim /usr/local/bin/nvim

echo "[+] Ensuring /usr/local/bin is in PATH..."
if ! echo $PATH | grep -q "/usr/local/bin"; then
	echo 'export PATH=/usr/local/bin:$PATH' >>~/.bashrc
	source ~/.bashrc
fi

echo "[+] Cleanup temporary files..."
rm nvim-linux-x86_64.tar.gz

echo "[✔] Neovim installation complete!"
echo "nvim version: $(nvim --version | head -n 1)"
