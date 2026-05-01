#!/bin/bash
# Deploy script - pull + restart server in one command
# Usage: deploy.sh [project_dir] [server_host] [project_path_on_server]
# Defaults: Current dir, uma@65.20.83.178, /home/uma/no_env/{project_name}

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Find project name from directory
find_project_name() {
    local dir="${1:-$(pwd)}"
    basename "$dir"
}

# Default server config (can be overridden)
SERVER_USER="${SERVER_USER:-uma}"
SERVER_HOST="${SERVER_HOST:-65.20.83.178}"
PROJECT_NAME="$(find_project_name "${1:-$(pwd)}")"
PROJECT_PATH="${2:-/home/uma/no_env/${PROJECT_NAME}}"
SERVER="${SERVER_USER}@${SERVER_HOST}"

echo "=== Deploy to Server ==="
echo "Project: $PROJECT_NAME"
echo "Server: $SERVER:$PROJECT_PATH"

# Get commit message if any
MSG="${*:-quick deploy}"

# Push local changes first
echo "Pushing to remote..."
git add -A
git commit -m "$MSG" 2>/dev/null || echo "No changes to commit"
git push

# Kill ghost processes, pull, restart
echo "Deploying to server..."
ssh "$SERVER" "
    cd $PROJECT_PATH && 
    git pull && 
    pkill -f uvicorn && 
    sleep 2 && 
    systemctl --user start fastapi_app.service
"

# Wait for startup
echo "Waiting for app..."
sleep 5

# Test endpoint
echo "Testing endpoint..."
RESULT=$(ssh "$SERVER" "curl -s http://127.0.0.1:8000/api/chart/settings" 2>/dev/null)

if [[ "$RESULT" == *"ma"* ]]; then
    echo "✅ Deploy successful!"
else
    echo "❌ Deploy may have failed: $RESULT"
    exit 1
fi

echo "=== Done ==="