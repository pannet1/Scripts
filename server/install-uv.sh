#!/bin/bash
# install-uv.sh - Install uv and Python 3.10 on VPS
# Usage: ./install-uv.sh user@ipaddress
# Or via SSH: ssh user@host "bash -s" < install-uv.sh

set -e

TARGET="$1"

if [ -z "$TARGET" ]; then
    echo "Usage: ./install-uv.sh user@ipaddress"
    echo "Example: ./install-uv.sh uma@65.20.83.178"
    exit 1
fi

echo "=== Installing uv and Python 3.10 on $TARGET ==="

# Install uv via SSH
ssh "$TARGET" 'bash -s' <<'EOF'
set -e

echo "Installing uv..."
curl -LsSf https://astral.sh/uv/install.sh | sh

# Source uv environment
if [ -f "$HOME/.local/bin/env" ]; then
    source "$HOME/.local/bin/env"
fi

# Add to PATH permanently if not already
if ! grep -q "\.local/bin/env" "$HOME/.bashrc" 2>/dev/null; then
    echo 'source $HOME/.local/bin/env' >> "$HOME/.bashrc"
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
EOF

echo "uv and Python 3.10 installed on $TARGET"