#!/usr/bin/env bash
set -uo pipefail

# Proactive FreeToken safetensors downloader for slow internet
# Uses hf download (resumable, 2 workers) + HF_TOKEN, stores to /mnt/data/models/hf
# Run: bash 03-download-freetoken.sh [7b|30b|all]  (default 7b)
# Re-run anytime to resume. Use nohup for overnight: nohup bash 03-download-freetoken.sh > data/freetoken.log 2>&1 &

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE_DIR="/mnt/data/models/hf"
[ -d "/mnt/data/models" ] || BASE_DIR="$SCRIPT_DIR/models/hf"
mkdir -p "$BASE_DIR"
LOG="$SCRIPT_DIR/data/freetoken-download.log"
mkdir -p "$(dirname "$LOG")"

[ -f "$HOME/.secrets/env" ] && set -a; source "$HOME/.secrets/env"; set +a
HF_BIN="$HOME/.freetoken/venv/bin/hf"
[ -x "$HF_BIN" ] || HF_BIN="hf"

if [ -z "${HF_TOKEN:-}" ]; then
  echo "✗ HF_TOKEN empty in ~/.secrets/env — get one at https://huggingface.co/settings/tokens"
  exit 1
fi
if ! command -v "$HF_BIN" &>/dev/null && ! [ -x "$HF_BIN" ]; then
  echo "✗ hf not found — install freetoken first: bash ../install-debian.sh (step 16)"
  exit 1
fi

MODE="${1:-7b}"
download() {
  local repo="$1"
  local dir="$BASE_DIR/$(basename "$repo")"
  echo "[$(date '+%F %T')] → $repo → $dir" | tee -a "$LOG"
  echo "  Workers=2 (slow link), resume safe — Ctrl+C to pause, re-run to resume" | tee -a "$LOG"
  if "$HF_BIN" download "$repo" --local-dir "$dir" --max-workers 2 --token "$HF_TOKEN" 2>&1 | tee -a "$LOG"; then
    echo "  ✓ $repo ($(du -sh "$dir" 2>/dev/null | cut -f1))" | tee -a "$LOG"
  else
    echo "  ⚠ Interrupted — re-run: bash $0 $MODE" | tee -a "$LOG"
    return 1
  fi
}

echo "── FreeToken safetensors → $BASE_DIR (slow link: 2 workers, resume) ──"
case "$MODE" in
  7b) download "Qwen/Qwen2.5-Coder-7B-Instruct" ;;
  30b) download "Qwen/Qwen3-30B-A3B" ;;
  all) download "Qwen/Qwen2.5-Coder-7B-Instruct"; download "Qwen/Qwen3-30B-A3B" ;;
  *) echo "Usage: $0 [7b|30b|all]"; exit 1 ;;
esac

echo ""
echo "── After download, serve with: ──"
echo "  ~/.freetoken/venv/bin/ft serve --model Qwen/Qwen2.5-Coder-7B-Instruct --port 1919 --host 127.0.0.1"
echo "  # ft will find cached HF files in $BASE_DIR or HF cache"
echo "  # Endpoint: http://127.0.0.1:1919/v1"
ls -lh "$BASE_DIR" 2>&1 | head -n 20
echo "Log: $LOG"
