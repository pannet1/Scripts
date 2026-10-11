#!/usr/bin/env bash
# 06-install-image-gen.sh — local image generation via stable-diffusion.cpp + llama-swap
# Verified 2026-10-11 on RTX 3050 6GB (debian13, CUDA 13.3). Idempotent: safe to re-run.
# Installs: sd-server binary (CUDA + embedded web UI), 3 model files (~6.2GB),
# and merges two image entries into ai/config/llama-swap/config-host.yaml.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -d "/mnt/data/models" ]; then MODELS_DIR="/mnt/data/models"; else MODELS_DIR="$SCRIPT_DIR/models"; fi
mkdir -p "$MODELS_DIR"
export PATH="$HOME/.local/bin:$HOME/.local/share/pnpm/bin:$PATH"

echo "── [1/4] Prerequisites (uv, node>=20, pnpm>=10, build tools) ──"
if ! command -v uv &>/dev/null; then
    echo "  installing uv (user, no sudo)..."
    curl -fsSL https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.local/bin:$PATH"
fi
echo "  uv: $(uv --version)"
command -v node &>/dev/null || { echo "  FATAL: node missing — run install-debian.sh step 9 first"; exit 1; }
command -v pnpm &>/dev/null || { echo "  FATAL: pnpm missing — run install-debian.sh pnpm step first"; exit 1; }
echo "  node: $(node --version) / pnpm: $(pnpm --version)"
# Build deps (user runs sudo; tolerate non-interactive shells)
missing=""
for p in cmake build-essential git libcurl4-openssl-dev; do dpkg -s "$p" &>/dev/null || missing="$missing $p"; done
if [ -z "$missing" ]; then
    echo "  build packages present"
else
    echo "  installing:$missing (needs sudo)..."
    sudo apt-get install -y $missing || echo "  WARN: no sudo here — run manually: sudo apt-get install -y$missing"
fi
export PATH="/usr/local/cuda/bin:$PATH"
command -v nvcc &>/dev/null || { echo "  FATAL: nvcc missing — run ai/05-install-llama-gpu.sh first"; exit 1; }

echo ""
echo "── [2/4] Image models (~6.2GB, resumable, skipped if present) ──"
dl_hf() { # $1=repo $2=file
    if [ -f "$MODELS_DIR/$2" ]; then echo "  present: $2"; return 0; fi
    echo "  downloading: $2 ..."
    uvx hf download "$1" "$2" --local-dir "$MODELS_DIR" --max-workers 2
}
dl_hf "OlegSkutte/SDXL-Lightning-GGUF" "sdxl_lightning_4step.q8_0.gguf"                       # 4-step SDXL, Q8_0 ~3.9G
dl_hf "SG161222/Realistic_Vision_V6.0_B1_noVAE" "Realistic_Vision_V6.0_NV_B1_fp16.safetensors" # photoreal SD1.5 fp16 ~2G
dl_hf "stabilityai/sd-vae-ft-mse-original" "vae-ft-mse-840000-ema-pruned.safetensors"          # VAE for RV6 ~320M

echo ""
echo "── [3/4] stable-diffusion.cpp sd-server (CUDA + embedded web UI) ──"
SD_SRC="$HOME/stable-diffusion.cpp"
SD_BIN="$SD_SRC/build/bin/sd-server"
needs_build=0
[ -x "$SD_BIN" ] || needs_build=1
if [ "$needs_build" -eq 0 ]; then
    # Single-process scan (no pipe): with `pipefail`, `strings | grep -q`
    # misreports — grep -q exits at first match, strings then dies of
    # SIGPIPE (141) and the pipeline takes the failure branch.
    if grep -q -a "sdcpp-webui-base-url" "$SD_BIN" 2>/dev/null; then
        echo "  sd-server already built WITH embedded UI — skipping build"
    else
        echo "  sd-server lacks embedded UI — rebuilding with frontend"
        needs_build=1
    fi
fi
if [ "$needs_build" -eq 1 ]; then
    if [ -d "$SD_SRC/.git" ]; then
        echo "  updating existing checkout..."
        git -C "$SD_SRC" pull --ff-only || true
    else
        echo "  cloning (full history, frontend vendored)..."
        git clone https://github.com/leejet/stable-diffusion.cpp "$SD_SRC"
    fi
    cd "$SD_SRC"
    git submodule init && git submodule update
    # Frontend deps (node_modules usually vendored/cached; pnpm install is quick when warm)
    ( cd examples/server/frontend && pnpm install )
    cmake -B build -DSD_CUDA=ON -DSD_SERVER_BUILD_FRONTEND=ON
    cmake --build build --config Release -j"$(nproc)" --target sd-server
    echo "  built: $("$SD_BIN" --help 2>&1 | head -1)"
fi

echo ""
echo "── [4/4] Merging image entries into llama-swap config ──"
HOST_CONFIG="$SCRIPT_DIR/config/llama-swap/config-host.yaml"
[ -f "$HOST_CONFIG" ] || { echo "  FATAL: $HOST_CONFIG missing — run ai/05-install-llama-gpu.sh first"; exit 1; }
cp "$HOST_CONFIG" "$HOST_CONFIG.bak.$(date +%F-%T)"
python3 - "$HOST_CONFIG" <<'EOF'
import re, sys
path = sys.argv[1]
s = open(path).read()
orig = s
# 1. Cold HDD load of 3.9G GGUF exceeds the old 30s limit -> 180s.
s = re.sub(r'^healthCheckTimeout: 30$', 'healthCheckTimeout: 180', s, flags=re.M)
# 2. Qwen on-demand on 6GB (was ttl 0 = pinned): image + LLM can't co-reside.
lines, cur = s.split('\n'), None
for i, l in enumerate(lines):
    m = re.match(r'^  "([^"]+)":$', l)
    if m: cur = m.group(1)
    if cur in ("qwen2.5-7b-instruct", "qwen2.5-coder-7b-instruct") and re.match(r'^    ttl: 0$', l):
        lines[i] = '    ttl: 300'
s = '\n'.join(lines)
open(path, 'w').write(s)
print("  timeout 30->180, qwen ttl 0->300" if s != orig else "  base tweaks already applied")
EOF
# Findings baked in (2026-10-11):
# - sd-server has NO /health (404) -> checkEndpoint MUST be /v1/models or llama-swap
#   kills the backend with "health check timed out".
# - OpenAI route accepts ONLY prompt/n/size (routes_openai.cpp) -> sampler/CFG/steps/
#   negative live as sd-server CLI defaults in cmd, NOT via UI/API.
# - v233 UI has prompt+size only; negative/steps come from cmd below (RV6 card:
#   DPM++ 2M Karras, CFG 3.5-7, 20-30 steps).
if ! grep -q '"sdxl-lightning"' "$HOST_CONFIG"; then
    cat >> "$HOST_CONFIG" <<YAML

  "sdxl-lightning":
    proxy: "http://127.0.0.1:8084"
    ttl: 300
    checkEndpoint: /v1/models
    cmd: >
      $SD_BIN
      -m $MODELS_DIR/sdxl_lightning_4step.q8_0.gguf
      --backend vae=cpu --fa -l 127.0.0.1 --listen-port 8084
YAML
    echo "  added: sdxl-lightning (:8084)"
else echo "  present: sdxl-lightning"; fi
if ! grep -q '"realistic-vision"' "$HOST_CONFIG"; then
    cat >> "$HOST_CONFIG" <<YAML

  "realistic-vision":
    proxy: "http://127.0.0.1:8085"
    ttl: 300
    checkEndpoint: /v1/models
    cmd: >
      $SD_BIN
      -m $MODELS_DIR/Realistic_Vision_V6.0_NV_B1_fp16.safetensors
      --vae $MODELS_DIR/vae-ft-mse-840000-ema-pruned.safetensors
      --steps 25 --cfg-scale 5.0 --sampling-method dpm++2m --scheduler karras
      -n "(deformed iris, deformed pupils, semi-realistic, cgi, 3d, render, sketch, cartoon, drawing, anime:1.4), text, close up, cropped, out of frame, worst quality, low quality, jpeg artifacts, ugly, duplicate, morbid, mutilated, extra fingers, mutated hands, poorly drawn hands, poorly drawn face, mutation, disgusting, amputation"
      --fa -l 127.0.0.1 --listen-port 8085
YAML
    echo "  added: realistic-vision (:8085)"
else echo "  present: realistic-vision"; fi

# Appended keys stay inside the top-level mapping (order-insensitive for YAML).
python3 -c "import re; s=open('$HOST_CONFIG').read(); ids=re.findall(r'^  \"[^\"]+\":', s, flags=re.M); assert s.count('default_model:')==1 and len(set(ids))==len(ids)" \
    && echo "  config sanity OK" || echo "  WARN: inspect $HOST_CONFIG (backup at $HOST_CONFIG.bak.*)"

echo ""
if systemctl --user is-active llama-swap >/dev/null 2>&1; then
    systemctl --user restart llama-swap
    sleep 5
    curl -s http://127.0.0.1:8080/v1/models | python3 -c "import json,sys; print('  models:', [m['id'] for m in json.load(sys.stdin)['data']])"
else
    echo "  llama-swap not running — start: systemctl --user start llama-swap"
fi
echo ""
echo "Use: llama-swap UI :8080 (prompt+size) for quick gens;"
echo "     full UI at :8085/:8084 once model is loaded (prompt, negative, steps, sampler, seed, img2img)."
