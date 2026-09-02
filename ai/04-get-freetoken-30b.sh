#!/usr/bin/env bash
set -euo pipefail
# Correct FreeToken model for 6GB RTX 3050 — Qwen3-30B-A3B MoE (only ~3B active, hybrid fits 6GB)
# Dense 7B bf16 OOMs on 6GB (needs 14GB), so we removed 7B 15G safetensors (see MEMORY.md)
# Usage: bash ai/04-get-freetoken-30b.sh  (resumable, run with nohup if slow link)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source ~/.secrets/env 2>/dev/null || true
if [ -z "${HF_TOKEN:-}" ]; then echo "HF_TOKEN missing in ~/.secrets/env"; exit 1; fi
BASE_DIR="/mnt/data/models/hf"
[ -d "/mnt/data/models" ] || BASE_DIR="$SCRIPT_DIR/models/hf"
mkdir -p "$BASE_DIR"
LOG="$SCRIPT_DIR/data/freetoken-30b.log"
mkdir -p "$(dirname "$LOG")"
HF_BIN="$HOME/.freetoken/venv/bin/hf"
[ -x "$HF_BIN" ] || HF_BIN="hf"
echo "── FreeToken 30B-A3B → $BASE_DIR (log: $LOG) ──"
echo "Workers=2, resume safe — Ctrl+C to pause, re-run to resume"
echo "After: ~/.freetoken/venv/bin/ft serve --model Qwen/Qwen3-30B-A3B --port 1919 --host 127.0.0.1 --tool-call-parser qwen25"
echo ""
# Stop llama-swap to free VRAM before serving ft (both need 6GB)
# systemctl --user stop llama-swap
"$HF_BIN" download "Qwen/Qwen3-30B-A3B" --local-dir "$BASE_DIR/Qwen3-30B-A3B" --max-workers 2 --token "$HF_TOKEN" 2>&1 | tee -a "$LOG"
echo ""
echo "✓ done $(du -sh "$BASE_DIR/Qwen3-30B-A3B" 2>/dev/null | cut -f1) — serve with:"
echo "  ~/.freetoken/venv/bin/ft serve --model Qwen/Qwen3-30B-A3B --port 1919 --host 127.0.0.1 --tool-call-parser qwen25 --memory-ratio 0.9"
echo "  curl http://127.0.0.1:1919/v1/models"
