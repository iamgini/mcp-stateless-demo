#!/bin/bash
# Beat 1.2 — Stateful: tools/list WITHOUT initialize (should be rejected)

kubectl delete pod mcp-test --force --grace-period=0 2>/dev/null

kubectl run mcp-test --rm -i --restart=Never --image=curlimages/curl -- \
  curl -s -w "\n\nHTTP Status: %{http_code}\n" \
  -X POST \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  http://mcp-stateful-svc:8080/mcp \
  -d '{"jsonrpc":"2.0","method":"tools/list","id":1}' 2>&1 | sed -n 's/^data: //p' | jq '.'
