#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MODELS_DIR="$SCRIPT_DIR/models"
mkdir -p "$MODELS_DIR"

download() {
  local url="$1"
  local output="$2"
  local name
  name="$(basename "$output")"

  aria2c -x 4 -s 4 -k 1M --continue --summary-interval=0 \
    --dir="$(dirname "$output")" --out="$name" "$url" && \
    echo "  Downloaded: $name ($(du -h "$output" | cut -f1))" || \
    echo "  ⚠ Download interrupted: $name — re-run script to resume"
}

echo "── Downloading chat model (Qwen2.5-7B-Instruct Q4_K_M) ──"
download \
  "https://huggingface.co/bartowski/Qwen2.5-7B-Instruct-GGUF/resolve/main/Qwen2.5-7B-Instruct-Q4_K_M.gguf" \
  "$MODELS_DIR/Qwen2.5-7B-Instruct-Q4_K_M.gguf"

echo ""
echo "── Downloading embedding model (nomic-embed-text v1.5 Q8_0) ──"
download \
  "https://huggingface.co/nomic-ai/nomic-embed-text-v1.5-GGUF/resolve/main/nomic-embed-text-v1.5.Q8_0.gguf" \
  "$MODELS_DIR/nomic-embed-text-v1.5-Q8_0.gguf"

echo ""
ls -lh "$MODELS_DIR"
echo ""
echo "✓ All models downloaded to $MODELS_DIR"
