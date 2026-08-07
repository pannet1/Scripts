#!/usr/bin/env bash
set -euo pipefail

echo "── Stopping AI Stack ──"
systemctl --user stop llama-swap
echo "✓ llama-swap stopped"
