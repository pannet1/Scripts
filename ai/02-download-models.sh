#!/usr/bin/env bash
set -uo pipefail

# Proactive downloader for slow internet — resumable, low connections, infinite retries
# Models go to /mnt/data/models (HDD, 861G free) to save NVMe. Falls back to ./models.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -d "/mnt/data/models" ]; then
  MODELS_DIR="/mnt/data/models"
else
  MODELS_DIR="$SCRIPT_DIR/models"
fi
mkdir -p "$MODELS_DIR"
LOG="$SCRIPT_DIR/data/download.log"
mkdir -p "$(dirname "$LOG")"

# Source HF_TOKEN for authenticated downloads (safetensors)
[ -f "$HOME/.secrets/env" ] && set -a; source "$HOME/.secrets/env"; set +a

download_gguf() {
  local url="$1"
  local output="$2"
  local name
  name="$(basename "$output")"
  local tmp="${output}.aria2"

  echo "[$(date '+%F %T')] → $name" | tee -a "$LOG"
  # Slow-internet tuned: 2 connections, 30s timeout, 10s retry, infinite tries, resume
  if aria2c \
    -x 2 -s 2 -k 1M \
    --continue=true \
    --auto-file-renaming=false --allow-overwrite=true \
    --max-tries=0 --retry-wait=10 \
    --timeout=60 --connect-timeout=30 \
    --check-certificate=true \
    --summary-interval=10 --log-level=notice --log="$LOG" \
    --dir="$(dirname "$output")" --out="$name" "$url"; then
    echo "  ✓ $name ($(du -h "$output" | cut -f1))" | tee -a "$LOG"
    return 0
  else
    echo "  ⚠ Interrupted: $name — will resume on re-run (slow link?)" | tee -a "$LOG"
    echo "    Resume: bash $0" | tee -a "$LOG"
    return 1
  fi
}

download_hf() {
  # $1 = repo_id, $2 = local_dir
  local repo="$1"
  local dir="$2"
  local hf_bin="$HOME/.freetoken/venv/bin/hf"
  [ -x "$hf_bin" ] || hf_bin="hf"
  echo "[$(date '+%F %T')] → HF $repo → $dir" | tee -a "$LOG"
  # hf download is resumable and uses 8 workers by default — lower for slow link
  if [ -n "${HF_TOKEN:-}" ]; then
    "$hf_bin" download "$repo" --local-dir "$dir" --max-workers 2 --token "$HF_TOKEN" 2>&1 | tee -a "$LOG" && \
      echo "  ✓ $repo" | tee -a "$LOG" || \
      { echo "  ⚠ Interrupted: $repo — re-run to resume" | tee -a "$LOG"; return 1; }
  else
    echo "  ✗ HF_TOKEN empty in ~/.secrets/env — skip $repo (need https://huggingface.co/settings/tokens)" | tee -a "$LOG"
    return 1
  fi
}

echo "── Models dir: $MODELS_DIR (log: $LOG) ──"
echo "── Slow link: 2 conns, resume, infinite retries ──"
echo ""

# Keep symlink for llama-swap which expects ./models/
if [ "$MODELS_DIR" = "/mnt/data/models" ] && [ ! -L "$SCRIPT_DIR/models/Qwen2.5-7B-Instruct-Q4_K_M.gguf" ]; then
  ln -sf "$MODELS_DIR/Qwen2.5-7B-Instruct-Q4_K_M.gguf" "$SCRIPT_DIR/models/Qwen2.5-7B-Instruct-Q4_K_M.gguf" 2>/dev/null || true
  ln -sf "$MODELS_DIR/Qwen2.5-Coder-7B-Instruct-Q4_K_M.gguf" "$SCRIPT_DIR/models/Qwen2.5-Coder-7B-Instruct-Q4_K_M.gguf" 2>/dev/null || true
  ln -sf "$MODELS_DIR/nomic-embed-text-v1.5-Q8_0.gguf" "$SCRIPT_DIR/models/nomic-embed-text-v1.5-Q8_0.gguf" 2>/dev/null || true
fi

echo "── [1/3] Chat GGUF (Qwen2.5-7B-Instruct Q4_K_M ~4.4G) ──"
download_gguf \
  "https://huggingface.co/bartowski/Qwen2.5-7B-Instruct-GGUF/resolve/main/Qwen2.5-7B-Instruct-Q4_K_M.gguf" \
  "$MODELS_DIR/Qwen2.5-7B-Instruct-Q4_K_M.gguf" || true

echo ""
echo "── [2/3] Coder GGUF (Qwen2.5-Coder-7B Q4_K_M ~4.4G) ──"
download_gguf \
  "https://huggingface.co/bartowski/Qwen2.5-Coder-7B-Instruct-GGUF/resolve/main/Qwen2.5-Coder-7B-Instruct-Q4_K_M.gguf" \
  "$MODELS_DIR/Qwen2.5-Coder-7B-Instruct-Q4_K_M.gguf" || true

echo ""
echo "── [3/3] Embedding GGUF (nomic-embed-text Q8_0 ~140M) ──"
download_gguf \
  "https://huggingface.co/nomic-ai/nomic-embed-text-v1.5-GGUF/resolve/main/nomic-embed-text-v1.5.Q8_0.gguf" \
  "$MODELS_DIR/nomic-embed-text-v1.5-Q8_0.gguf" || true

echo ""
echo "── Optional: FreeToken safetensors (large, slow link — run separately) ──"
echo "  For freetoken hybrid (needs HF_TOKEN):"
echo "    bash $SCRIPT_DIR/03-download-freetoken.sh   # Qwen2.5-Coder-7B ~15G or Qwen3-30B ~30G to $MODELS_DIR/hf/"
echo "  Or manual: ~/.freetoken/venv/bin/hf download Qwen/Qwen2.5-Coder-7B-Instruct --local-dir $MODELS_DIR/hf/Qwen2.5-Coder-7B-Instruct --max-workers 2"

echo ""
ls -lh "$MODELS_DIR" 2>&1 | head -n 20
echo ""
echo "✓ GGUF done. Log: $LOG"
echo "  Re-run this script any time to resume interrupted downloads (slow internet safe)."
