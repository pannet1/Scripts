#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

source .env 2>/dev/null || true

echo "── Starting AI Stack ──"
echo "  Service        Port      Where"
echo "  ─────────────────────────────────"
echo "  llama-swap     :${LLAMA_SWAP_PORT:-8080}   host (systemd --user)"
echo ""
systemctl --user start llama-swap

echo ""
echo "✓ llama-swap started. Logs: journalctl --user -u llama-swap -f"
echo "  Stop: ./stop.sh"
