#!/bin/bash
# Beat 2.2 — Stateless: repeat tools/list (100% success every time)

kubectl delete pod mcp-test --force --grace-period=0 2>/dev/null

kubectl run mcp-test --rm -i --restart=Never --image=curlimages/curl -- \
  curl -s -w "\nHTTP Status: %{http_code}\n" \
  -X POST \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  http://mcp-stateless-svc:8080/mcp \
  -d '{"jsonrpc":"2.0","method":"tools/list","id":1}' 2>&1 | sed -n 's/^data: //p' | jq '{tools_count: (.result.tools | length), tool_names: [.result.tools[].name]}'
