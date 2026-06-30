#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

cd "$SCRIPT_DIR"

echo "── Starting AI Stack ──"
echo "  Service        Port      Where"
echo "  ─────────────────────────────────"
echo "  llama-swap     :${LLAMA_SWAP_PORT:-8080}   host (systemd --user)"
echo "  anythingllm    :${ANYTHINGLLM_PORT:-3001}  docker"
echo "  n8n            :${N8N_PORT:-5678}          docker"
echo ""

echo "  ※ Ensure llama-swap is running: systemctl --user start llama-swap"
echo ""
docker compose --env-file .env up -d

echo ""
echo "✓ Docker services started. Show logs: docker compose logs -f"
echo "  llama-swap logs: journalctl --user -u llama-swap -f"
echo "  Stop Docker:     docker compose down"
echo "  Stop llama-swap: systemctl --user stop llama-swap"
