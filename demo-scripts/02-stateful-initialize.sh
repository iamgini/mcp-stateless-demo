#!/bin/bash
# Beat 1.3 — Stateful: send initialize, get Mcp-Session-Id back

kubectl delete pod mcp-test --force --grace-period=0 2>/dev/null

echo "=== Response Headers + Body ==="
kubectl run mcp-test --rm -i --restart=Never --image=curlimages/curl -- \
  curl -s -D /dev/stderr \
  -X POST \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  http://mcp-stateful-svc:8080/mcp \
  -d '{"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"demo","version":"1.0"}},"id":1}' 2>&1 | \
  tee /tmp/mcp-init-response.txt

echo ""
echo "=== Mcp-Session-Id ==="
grep -i 'mcp-session-id' /tmp/mcp-init-response.txt | sed 's/.*: //'
