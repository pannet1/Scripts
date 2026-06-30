#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE_URL="${ANYTHINGLLM_URL:-http://localhost:3001}"
API_KEY="${ANYTHINGLLM_API_KEY:-sk-anythingllm-local-dev}"
WORKSPACE="${WORKSPACE_NAME:-Local RAG}"
DOCUMENTS_DIR="$SCRIPT_DIR/documents"

echo "── Uploading documents from $DOCUMENTS_DIR ──"
for doc in "$DOCUMENTS_DIR"/*; do
  [ -f "$doc" ] || continue
  echo "  Uploading: $(basename "$doc")"
  curl -f -X POST "$BASE_URL/api/document/upload" \
    -H "Authorization: Bearer $API_KEY" \
    -F "file=@$doc" \
    && echo "    ✓ Uploaded" || echo "    ✗ Failed"
done

echo ""
echo "── Moving documents to workspace '$WORKSPACE' ──"
WS_SLUG=$(curl -f "$BASE_URL/api/workspaces" \
  -H "Authorization: Bearer $API_KEY" | \
  python3 -c "
import sys,json
data=json.load(sys.stdin)
for w in data:
  if w.get('name')=='$WORKSPACE':
    print(w.get('slug',''))
    break
" || echo "")

if [ -z "$WS_SLUG" ]; then
  echo "  ✗ Workspace '$WORKSPACE' not found — run 03-init-anythingllm.sh first"
  exit 1
fi

DOC_IDS=$(curl -f "$BASE_URL/api/documents" \
  -H "Authorization: Bearer $API_KEY" | \
  python3 -c "
import sys,json
data=json.load(sys.stdin)
ids=[d.get('id') for d in data if not d.get('workspace_id')]
print(' '.join(ids))
" || echo "")

for doc_id in $DOC_IDS; do
  curl -f -X POST "$BASE_URL/api/workspace/$WS_SLUG/document" \
    -H "Authorization: Bearer $API_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"documents\":[\"$doc_id\"]}" \
    && echo "  ✓ Moved document $doc_id" || echo "  ✗ Failed to move $doc_id"
done

echo ""
echo "── Triggering vector embedding ──"
curl -f -X POST "$BASE_URL/api/workspace/$WS_SLUG/update-embeddings" \
  -H "Authorization: Bearer $API_KEY" \
  && echo "  ✓ Embedding triggered" || echo "  ✗ Embedding trigger failed"

echo ""
echo "── Verifying with test query ──"
sleep 5
RESULT=$(curl -f -X POST "$BASE_URL/api/workspace/$WS_SLUG/chat" \
  -H "Authorization: Bearer $API_KEY" \
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
"
else
  echo "  ⚠ Query returned empty — embeddings may still be processing"
fi

echo ""
echo "✓ RAG init complete."
