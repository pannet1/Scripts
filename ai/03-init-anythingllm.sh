#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/.env" || true

BASE_URL="${ANYTHINGLLM_URL:-http://localhost:3001}"
API_KEY="${ANYTHINGLLM_API_KEY:-sk-anythingllm-local-dev}"
WORKSPACE="${WORKSPACE_NAME:-Local RAG}"

echo "── Waiting for AnythingLLM to be ready ──"
for i in $(seq 1 30); do
  if curl -f "$BASE_URL/api/health"; then
    echo "  ✓ AnythingLLM ready (attempt $i)"
    break
  fi
  printf "  ."
  sleep 2
done

echo ""
echo "── Creating default admin account (if first boot) ──"
curl -f -X POST "$BASE_URL/api/auth" \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"username":"admin@local","password":"admin","name":"Admin"}' \
  && echo "  ✓ Admin account ready" || echo "  ⚠ Admin setup skipped or already configured"

echo ""
echo "── Creating default workspace ──"
WS_EXISTS=$(curl -f "$BASE_URL/api/workspaces" \
  -H "Authorization: Bearer $API_KEY" 2>/dev/null | \
  python3 -c "import sys,json; data=json.load(sys.stdin).get('workspaces',[]); print(any(w.get('name')=='$WORKSPACE' for w in data))" 2>/dev/null || echo "false")

if [ "$WS_EXISTS" = "True" ]; then
  echo "  ✓ Workspace '$WORKSPACE' already exists"
else
  curl -f -X POST "$BASE_URL/api/workspace" \
    -H "Authorization: Bearer $API_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"name\":\"$WORKSPACE\"}" \
    && echo "  ✓ Created workspace: $WORKSPACE"
fi

echo ""
echo "── Verifying llama-swap (LLM backend) ──"
LLM_OK=$(curl -sf http://localhost:${LLAMA_SWAP_PORT:-8080}/v1/models | \
  python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d.get('data',[]))>0)" 2>/dev/null || echo "false")
if [ "$LLM_OK" = "True" ]; then
  echo "  ✓ llama-swap running with models"
  curl -sf http://localhost:${LLAMA_SWAP_PORT:-8080}/v1/models | python3 -m json.tool 2>/dev/null
else
  echo "  ⚠ llama-swap not responding — run: systemctl --user start llama-swap"
fi

echo ""
echo "✓ Init complete. Open $BASE_URL in your browser."
echo "  Next: run 04-init-rag.sh to ingest documents"
