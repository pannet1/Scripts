#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "── Stopping AI Stack ──"
docker compose --env-file .env down
echo ""
echo "  To also stop llama-swap (host):"
echo "    systemctl --user stop llama-swap"
echo "✓ Docker services stopped"
