#!/bin/bash
# Port-forward MCP services to localhost for Claude Code access
# Stateless:      localhost:8082 → mcp-stateless-svc:8080
# Stateful:       localhost:8081 → mcp-stateful-svc:8080
# Stateless+Auth: localhost:8083 → mcp-auth-svc:9080

set -e

PIDS=""

cleanup() {
  echo ""
  echo "Stopping port-forwards..."
  kill $PIDS 2>/dev/null
  exit 0
}
trap cleanup INT TERM

echo "=== Starting port-forwards ==="
echo ""

kubectl port-forward svc/mcp-stateless-svc 8082:8080 &
PIDS="$PIDS $!"

kubectl port-forward svc/mcp-stateful-svc 8081:8080 &
PIDS="$PIDS $!"

# Auth-enabled variant (nginx sidecar validates X-Api-Key header)
if kubectl get svc mcp-auth-svc &>/dev/null; then
  kubectl port-forward svc/mcp-auth-svc 8083:9080 &
  PIDS="$PIDS $!"
  AUTH_AVAILABLE=true
fi

sleep 2

echo ""
echo "=== Port-forwards active ==="
echo "  Stateless MCP: http://localhost:8082/mcp"
echo "  Stateful MCP:  http://localhost:8081/mcp"
if [ "$AUTH_AVAILABLE" = true ]; then
echo "  Auth MCP:      http://localhost:8083/mcp  (requires X-Api-Key header)"
fi
echo ""
echo "Add to Claude Code:"
echo "  claude mcp add --transport http k8s-stateless http://localhost:8082/mcp"
echo "  claude mcp add --transport http k8s-stateful http://localhost:8081/mcp"
if [ "$AUTH_AVAILABLE" = true ]; then
echo "  claude mcp add --transport http --header 'X-Api-Key: demo-secret-2026' k8s-auth http://localhost:8083/mcp"
fi
echo ""
echo "Press Ctrl+C to stop"
echo ""

wait
