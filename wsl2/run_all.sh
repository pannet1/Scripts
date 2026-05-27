#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

cd "$SCRIPT_DIR"

for script in \
    1_packages.sh \
    2_nerdfonts.sh \
    3_lazyvim.sh \
    4_starship.sh \
    5_zoxide.sh \
    6_tmux.sh \
    7_bash.sh \
; do
    if [ -f "$script" ]; then
        echo ""
        echo "========================================"
        echo "  Running: $script"
        echo "========================================"
        bash "$script"
    else
        echo "[!] Skipping $script (not found)"
    fi
done

echo ""
echo "========================================"
echo "  All done!"
echo "========================================"
echo ""
echo "Next steps:"
echo "  1. source ~/.bashrc"
echo "  2. Start tmux: tmux"
echo "  3. Inside tmux, press: prefix + I (capital i) to install plugins"
echo "  4. Start nvim: nvim  (plugins auto-install on first launch)"
