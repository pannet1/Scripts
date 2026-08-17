#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/.env"

echo "── Installing CUDA 12.6 toolkit + llama.cpp (GPU) + llama-swap ──"
echo "  (CUDA toolkit is ~2-3GB download — required for GPU compilation)"
echo ""

if ! command -v nvcc &>/dev/null; then
    echo "Step 1: Installing CUDA toolkit..."
    cd /tmp
    # Match the installed Debian release; the debian12 keyring's SHA1-bound
    # signature is rejected by apt (policy change 2026-02-01).
    DEBIAN_VER="$(. /etc/os-release && echo "$VERSION_ID")"
    curl -fsSL -o cuda-keyring.deb \
        "https://developer.download.nvidia.com/compute/cuda/repos/debian${DEBIAN_VER}/x86_64/cuda-keyring_1.1-1_all.deb"
    sudo dpkg -i cuda-keyring.deb
    # Remove stale repo files for other Debian releases (apt can't verify them)
    for f in /etc/apt/sources.list.d/cuda-debian*-x86_64.list; do
        if [ -f "$f" ] && ! grep -q "repos/debian${DEBIAN_VER}/" "$f"; then
            sudo rm -f "$f"
        fi
    done
    sudo apt-get update
    # debian12 repo only ships up to CUDA 12.6; debian13 repo ships 13.x.
    # Pick the highest cuda-toolkit-13-x meta-package available (exclude
    # -config-common and other sub-packages).
    CUDA_TOOLKIT="$(apt-cache search '^cuda-toolkit-13-[0-9]+$' 2>/dev/null | awk '{print $1}' | sort -V | tail -1)"
    CUDA_VER="$(echo "$CUDA_TOOLKIT" | sed 's/^cuda-toolkit-//')"
    sudo apt-get install -y "$CUDA_TOOLKIT" build-essential cmake git gcc-13 g++-13
    echo "export PATH=/usr/local/cuda-$CUDA_VER/bin:\$PATH" | sudo tee /etc/profile.d/cuda.sh
    export PATH="/usr/local/cuda-$CUDA_VER/bin:$PATH"
else
    echo "  nvcc found: $(nvcc --version | tail -1)"
fi

if ! command -v /usr/local/bin/llama-server &>/dev/null; then
    echo ""
    echo "Step 2: Building llama.cpp with CUDA..."
    CUDA_DIR="$(ls -d /usr/local/cuda-* 2>/dev/null | sort -V | tail -1)"
    # Workaround: CUDA 12.6 + glibc 2.40+ noexcept mismatch
    MATH_H="$CUDA_DIR/targets/x86_64-linux/include/crt/math_functions.h"
    if grep -q "cospi(double" "$MATH_H" 2>/dev/null && ! grep -q "noexcept" "$MATH_H" 2>/dev/null; then
        sudo sed -i 's/extern \(__DEVICE_FUNCTIONS_DECL__ __device_builtin__ double *sinpi(double x)\);/extern \1 noexcept;/' "$MATH_H"
        sudo sed -i 's/extern \(__DEVICE_FUNCTIONS_DECL__ __device_builtin__ float *sinpif(float x)\);/extern \1 noexcept;/' "$MATH_H"
        sudo sed -i 's/extern \(__DEVICE_FUNCTIONS_DECL__ __device_builtin__ double *cospi(double x)\);/extern \1 noexcept;/' "$MATH_H"
        sudo sed -i 's/extern \(__DEVICE_FUNCTIONS_DECL__ __device_builtin__ float *cospif(float x)\);/extern \1 noexcept;/' "$MATH_H"
    fi
    cd /tmp
    git clone --depth 1 --branch b9843 https://github.com/ggml-org/llama.cpp
    cd llama.cpp
    export CUDACXX="$CUDA_DIR/bin/nvcc"
    cmake -B build \
        -DGGML_CUDA=ON \
        -DGGML_NATIVE=OFF \
        -DCMAKE_CUDA_ARCHITECTURES=86 \
        -DCMAKE_CUDA_FLAGS="-allow-unsupported-compiler" \
        -DCMAKE_CUDA_HOST_COMPILER=/usr/bin/gcc-13 \
        -DCMAKE_CUDA_COMPILER="$CUDA_DIR/bin/nvcc" \
        -DBUILD_SHARED_LIBS=OFF
    cmake --build build --config Release -j$(nproc) --target llama-server
    sudo cp build/bin/llama-server /usr/local/bin/llama-server
    rm -rf /tmp/llama.cpp
else
    echo "  llama-server already installed"
fi

if ! command -v /usr/local/bin/llama-swap &>/dev/null; then
    echo ""
    echo "Step 3: Installing llama-swap..."
    curl -fsSL \
        https://github.com/mostlygeek/llama-swap/releases/download/v233/llama-swap_233_linux_amd64.tar.gz \
        | tar xz -C /tmp/ llama-swap
    sudo mv /tmp/llama-swap /usr/local/bin/llama-swap
    sudo chmod +x /usr/local/bin/llama-swap
else
    echo "  llama-swap already installed"
fi

echo ""
echo "Step 4: Writing host config..."
HOST_CONFIG="$SCRIPT_DIR/config/llama-swap/config-host.yaml"
# llama-swap runs with CWD=$HOME, so model paths must be absolute.
MODELS_ABS="$(readlink -f "$SCRIPT_DIR/$MODELS_DIR")"
cat > "$HOST_CONFIG" << YAML
healthCheckTimeout: 30

models:
  "qwen2.5-7b-instruct":
    proxy: "http://127.0.0.1:8081"
    ttl: 0
    cmd: >
      /usr/local/bin/llama-server
      --host 127.0.0.1 --port 8081
      --model $MODELS_ABS/$CHAT_MODEL
      --n-gpu-layers 99
      --ctx-size 8192
      --flash-attn on

  "nomic-embed-text":
    proxy: "http://127.0.0.1:8082"
    ttl: 0
    cmd: >
      /usr/local/bin/llama-server
      --host 127.0.0.1 --port 8082
      --model $MODELS_ABS/$EMBED_MODEL
      --embd --embd-normalize 2
      --ctx-size 8192

default_model: qwen2.5-7b-instruct
YAML
echo "  Config: $HOST_CONFIG"

echo ""
echo "Step 5: Creating systemd user service..."
mkdir -p "$HOME/.config/systemd/user"
SERVICE_FILE="$HOME/.config/systemd/user/llama-swap.service"
cat > "$SERVICE_FILE" << UNIT
[Unit]
Description=llama-swap AI inference router (GPU)
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/llama-swap -listen localhost:8080 --config $HOST_CONFIG
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
UNIT
systemctl --user daemon-reload

echo ""
echo "── Installation complete ──"
echo ""
echo "Models:"
ls -lh "$SCRIPT_DIR/$MODELS_DIR"
echo ""
echo "Start:   systemctl --user start llama-swap"
echo "Status:  systemctl --user status llama-swap"
echo "Logs:    journalctl --user -u llama-swap -f"
echo ""
echo "After starting, run:  sudo bash start.sh"
echo "  (start.sh launches AnythingLLM + n8n in Docker)"
