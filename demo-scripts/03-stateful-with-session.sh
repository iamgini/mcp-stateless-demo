#!/bin/bash
# Beat 1.4 — Stateful: tools/list WITH session ID (50% fail on wrong pod)
# Usage: ./03-stateful-with-session.sh <SESSION_ID>

SESSION_ID="${1:?Usage: $0 <Mcp-Session-Id from step 02>}"

kubectl delete pod mcp-test --force --grace-period=0 2>/dev/null

kubectl run mcp-test --rm -i --restart=Never --image=curlimages/curl -- \
  curl -s \
  -X POST \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -H "Mcp-Session-Id: ${SESSION_ID}" \
  http://mcp-stateful-svc:8080/mcp \
  -d '{"jsonrpc":"2.0","method":"tools/list","id":2}' 2>&1 | sed -n 's/^data: //p' | jq '.'
