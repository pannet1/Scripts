#!/bin/bash
# setup-uv.sh - Generic uv setup for any project
# Usage: ./setup-uv.sh [project_dir]
# Creates venv with pinned Python and installs dependencies

set -e

PROJECT_DIR="${1:-.}"
cd "$PROJECT_DIR"

echo "=== Setting up uv in $PROJECT_DIR ==="

# Install Python 3.10 if not available
echo "[1/4] Installing Python 3.10..."
uv python install 3.10 2>/dev/null || true
uv python pin 3.10

# Handle requirements.txt -> pyproject.toml conversion
if [ -f "requirements.txt" ]; then
    echo "[2/4] Converting requirements.txt to pyproject.toml..."
    
    if [ ! -f "pyproject.toml" ]; then
        cat > pyproject.toml << 'EOF'
[project]
name = "project"
version = "0.1.0"
requires-python = ">=3.10"

dependencies = []
EOF
    fi
    
    # Parse requirements.txt and add to pyproject.toml
    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ "$line" =~ ^# ]] && continue
        [[ -z "$line" ]] && continue
        
        # Parse package name (remove version specs)
        pkg=$(echo "$line" | sed 's/==.*//;s/>=.*//;s/<=.*//;s/>.*//;s/<.*//;s/ .*//' | xargs)
        
        if [[ -n "$pkg" ]]; then
            # Add to dependencies array
            sed -i "s/dependencies = \[\]/dependencies = [\n    \"$pkg\",/g" pyproject.toml
        fi
    done < requirements.txt
    
    # Fix the array format (basic fix)
    sed -i 's/\[\n    "/["/g; s/",\n    "/", "/g' pyproject.toml
    
    echo "[3/4] Removing requirements.txt..."
    rm requirements.txt
fi

# Create/refresh venv and install from pyproject.toml
if [ -f "pyproject.toml" ]; then
    echo "[3/4] Creating virtual environment with Python 3.10..."
    if [ -d ".venv" ]; then
        rm -rf .venv
    fi
    uv venv .venv --python 3.10
    
    echo "[4/4] Installing dependencies from pyproject.toml..."
    uv pip install -e . || uv pip install -r pyproject.toml
else
    echo "[!] No requirements.txt or pyproject.toml found - creating basic venv..."
    if [ -d ".venv" ]; then
        rm -rf .venv
    fi
    uv venv .venv --python 3.10
fi

echo ""
echo "=== Done! ==="
.venv/bin/python --version