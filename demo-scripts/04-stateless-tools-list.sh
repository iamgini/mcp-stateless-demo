#!/bin/bash
# Beat 2.1 — Stateless: tools/list directly (no initialize, no session)

kubectl delete pod mcp-test --force --grace-period=0 2>/dev/null

echo "=== Response Headers ==="
kubectl run mcp-test --rm -i --restart=Never --image=curlimages/curl -- \
  curl -s -D /dev/stderr \
  -X POST \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  http://mcp-stateless-svc:8080/mcp \
  -d '{"jsonrpc":"2.0","method":"tools/list","id":1}' 2>&1 | \
  tee /tmp/mcp-stateless-response.txt | sed -n 's/^data: //p' | jq '.result.tools[] | {name, title: .annotations.title}'

echo ""
echo "=== Mcp-Session-Id? ==="
grep -i 'mcp-session-id' /tmp/mcp-stateless-response.txt || echo "(none — stateless!)"
