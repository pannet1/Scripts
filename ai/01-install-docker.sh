#!/usr/bin/env bash
set -euo pipefail

echo "[1/6] Installing Docker Engine from Debian Trixie repos..."
sudo apt-get update
sudo apt-get install -y docker.io docker-compose docker-buildx

echo "[2/6] Enabling and starting Docker..."
sudo systemctl enable docker
sudo systemctl start docker

echo "[3/6] Adding user to docker group..."
sudo usermod -aG docker "$USER"

echo "[4/6] Installing nvidia-container-toolkit..."
curl -fL https://nvidia.github.io/libnvidia-container/gpgkey | \
  sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -fL https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
  sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
  sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
sudo apt-get update
sudo apt-get install -y nvidia-container-toolkit

echo "[5/6] Configuring Docker runtime for NVIDIA..."
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker

echo "[6/6] Verifying GPU access in Docker..."
docker run --rm --gpus all debian:trixie-slim nvidia-smi && \
  echo "✓ GPU passthrough verified" || \
  echo "⚠ GPU test failed — check nvidia-container-toolkit installation"

echo ""
echo "✓ Docker + GPU setup complete."
echo "  Start stack:    bash start.sh"
echo "  (If docker permission denied, run 'newgrp docker' first)"
