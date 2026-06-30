#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/.env"

echo "── Installing CUDA 12.6 toolkit + llama.cpp (GPU) + llama-swap ──"
echo "  (CUDA toolkit is ~2-3GB download — required for GPU compilation)"
echo ""

if ! command -v nvcc &>/dev/null; then
    echo "Step 1: Installing CUDA 12.6 toolkit..."
    cd /tmp
    curl -fsSLO https://developer.download.nvidia.com/compute/cuda/repos/debian12/x86_64/cuda-keyring_1.1-1_all.deb
    sudo dpkg -i cuda-keyring_1.1-1_all.deb
    sudo apt-get update
    sudo apt-get install -y cuda-toolkit-12-6 build-essential cmake git gcc-13 g++-13
    echo 'export PATH=/usr/local/cuda-12.6/bin:$PATH' | sudo tee /etc/profile.d/cuda.sh
    export PATH=/usr/local/cuda-12.6/bin:$PATH
else
    echo "  nvcc found: $(nvcc --version | tail -1)"
fi

if ! command -v /usr/local/bin/llama-server &>/dev/null; then
    echo ""
    echo "Step 2: Building llama.cpp with CUDA..."
    # Workaround: CUDA 12.6 + glibc 2.40+ noexcept mismatch
    MATH_H="/usr/local/cuda-12.6/targets/x86_64-linux/include/crt/math_functions.h"
    if grep -q "cospi(double" "$MATH_H" 2>/dev/null && ! grep -q "noexcept" "$MATH_H" 2>/dev/null; then
        sudo sed -i 's/extern \(__DEVICE_FUNCTIONS_DECL__ __device_builtin__ double *sinpi(double x)\);/extern \1 noexcept;/' "$MATH_H"
        sudo sed -i 's/extern \(__DEVICE_FUNCTIONS_DECL__ __device_builtin__ float *sinpif(float x)\);/extern \1 noexcept;/' "$MATH_H"
        sudo sed -i 's/extern \(__DEVICE_FUNCTIONS_DECL__ __device_builtin__ double *cospi(double x)\);/extern \1 noexcept;/' "$MATH_H"
        sudo sed -i 's/extern \(__DEVICE_FUNCTIONS_DECL__ __device_builtin__ float *cospif(float x)\);/extern \1 noexcept;/' "$MATH_H"
    fi
    cd /tmp
    git clone --depth 1 --branch b9843 https://github.com/ggml-org/llama.cpp
    cd llama.cpp
    export CUDACXX=/usr/local/cuda-12.6/bin/nvcc
    cmake -B build \
        -DGGML_CUDA=ON \
        -DGGML_NATIVE=OFF \
        -DCMAKE_CUDA_ARCHITECTURES=86 \
        -DCMAKE_CUDA_FLAGS="-allow-unsupported-compiler" \
        -DCMAKE_CUDA_HOST_COMPILER=/usr/bin/gcc-13 \
        -DCMAKE_CUDA_COMPILER=/usr/local/cuda-12.6/bin/nvcc \
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
cat > "$HOST_CONFIG" << YAML
healthCheckTimeout: 30

models:
  "qwen2.5-7b-instruct":
    proxy: "http://127.0.0.1:8081"
    ttl: 0
    cmd: >
      /usr/local/bin/llama-server
      --host 127.0.0.1 --port 8081
      --model $MODELS_DIR/$CHAT_MODEL
      --n-gpu-layers 99
      --ctx-size 8192
      --flash-attn

  "nomic-embed-text":
    proxy: "http://127.0.0.1:8082"
    ttl: 0
    cmd: >
      /usr/local/bin/llama-server
      --host 127.0.0.1 --port 8082
      --model $MODELS_DIR/$EMBED_MODEL
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
ExecStart=/usr/local/bin/llama-swap --config $HOST_CONFIG
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
