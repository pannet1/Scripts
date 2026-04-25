#!/bin/bash
# install-uv.sh - Install uv and Python 3.10 on VPS
# Usage: curl -fsSL https://raw.githubusercontent.com/pannet1/Scripts/main/server/install-uv.sh | ssh user@host 'cat > /tmp/install-uv.sh && chmod +x /tmp/install-uv.sh && /tmp/install-uv.sh'

set -e

echo "=== Installing uv and Python 3.10 ==="

# Install uv (standalone installer)
if command -v uv &> /dev/null; then
    echo "uv already installed"
else
    echo "Installing uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
fi

# Source uv environment
if [ -f "$HOME/.local/bin/env" ]; then
    source "$HOME/.local/bin/env"
fi

# Add to PATH permanently if not already
if ! grep -q "\.local/bin/env" "$HOME/.bashrc" 2>/dev/null; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
    echo "Added uv to PATH in ~/.bashrc"
fi

# Install Python 3.10
echo "Installing Python 3.10..."
uv python install 3.10

# Verify
echo ""
echo "=== Verification ==="
/home/$(whoami)/.local/bin/python3.10 --version
echo ""
echo "uv Python list:"
uv python list | head -5

echo ""
echo "=== Done ==="
echo "To use: source ~/.bashrc or restart shell"