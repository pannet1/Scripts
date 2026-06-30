#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE_URL="${ANYTHINGLLM_URL:-http://localhost:3001}"
API_KEY="${ANYTHINGLLM_API_KEY:-sk-anythingllm-local-dev}"
WORKSPACE="${WORKSPACE_NAME:-Local RAG}"
DOCUMENTS_DIR="$SCRIPT_DIR/documents"
AUTH="Authorization: Bearer $API_KEY"

echo "── Looking up workspace slug ──"
WS_SLUG=$(curl -sf "$BASE_URL/api/v1/workspaces" -H "$AUTH" | \
  python3 -c "
import sys,json
data=json.load(sys.stdin).get('workspaces',[])
for w in data:
  if w.get('name')=='$WORKSPACE':
    print(w.get('slug',''))
    break
" 2>/dev/null || echo "")

if [ -z "$WS_SLUG" ]; then
  echo "  ✗ Workspace '$WORKSPACE' not found — run 03-init-anythingllm.sh first"
  exit 1
fi
echo "  ✓ Found workspace: $WORKSPACE (slug: $WS_SLUG)"

echo ""
echo "── Uploading documents directly with workspace link ──"
for doc in "$DOCUMENTS_DIR"/*; do
  [ -f "$doc" ] || continue
  echo "  Uploading: $(basename "$doc")"
  RESP=$(curl -sf -X POST "$BASE_URL/api/v1/document/upload" \
    -H "$AUTH" \
    -F "file=@$doc" \
    -F "addToWorkspaces=$WS_SLUG" 2>/dev/null)
  if echo "$RESP" | python3 -c "import sys,json; d=json.load(sys.stdin); exit(0 if d.get('success') else 1)" 2>/dev/null; then
    echo "    ✓ Uploaded"
  else
    echo "    ✗ Failed"
  fi
done

echo ""
echo "── Triggering vector embedding ──"
# v1 API doesn't have an embed trigger — embeddings happen automatically on upload
echo "  ✓ Embedding handled automatically on upload"

echo ""
echo "── Verifying with test query ──"
sleep 3
RESULT=$(curl -sf -X POST "$BASE_URL/api/v1/workspace/$WS_SLUG/chat" \
  -H "$AUTH" \
  -H "Content-Type: application/json" \
  -d '{"message":"Summarize the key topics from my documents","mode":"query"}')

if [ -n "$RESULT" ]; then
  echo "  ✓ RAG query returned a response"
  echo "$RESULT" | python3 -c "
import sys,json
try:
  data=json.load(sys.stdin)
  print('  Response:', (data.get('textResponse','') or '')[:200])
except: print('  (raw response)')
" 2>/dev/null
else
  echo "  ⚠ Query returned empty — embeddings may still be processing"
fi

echo ""
echo "✓ RAG init complete."
