#!/bin/bash
# Port-forward MCP services to localhost for Claude Code access
# Stateless:      localhost:8082 → mcp-stateless-svc:8080
# Stateful:       localhost:8081 → mcp-stateful-svc:8080
# Stateless+Auth: localhost:8083 → mcp-auth-svc:9080
#
# Runs in background. Use ./11-cleanup.sh to stop.

# Kill any existing port-forwards first
pkill -f "kubectl port-forward svc/mcp-" 2>/dev/null
sleep 1

echo "=== Starting port-forwards ==="
echo ""

kubectl port-forward svc/mcp-stateless-svc 8082:8080 &>/dev/null &
kubectl port-forward svc/mcp-stateful-svc 8081:8080 &>/dev/null &

AUTH_AVAILABLE=false
if kubectl get svc mcp-auth-svc &>/dev/null; then
  kubectl port-forward svc/mcp-auth-svc 8083:9080 &>/dev/null &
  AUTH_AVAILABLE=true
fi

sleep 2

echo "=== Port-forwards active (background) ==="
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
echo "  claude mcp add-json k8s-auth '{\"type\":\"http\",\"url\":\"http://localhost:8083/mcp\",\"headers\":{\"X-Api-Key\":\"demo-secret-2026\"}}'"
fi
echo ""
echo "To stop: ./demo-scripts/11-cleanup.sh"
