#!/bin/bash
# Cleanup: remove MCP servers from Claude Code and kill port-forwards

echo "=== Removing MCP servers from Claude Code ==="
claude mcp remove k8s-stateless 2>/dev/null && echo "  Removed k8s-stateless" || echo "  k8s-stateless not found"
claude mcp remove k8s-stateful 2>/dev/null && echo "  Removed k8s-stateful" || echo "  k8s-stateful not found"
claude mcp remove k8s-auth 2>/dev/null && echo "  Removed k8s-auth" || echo "  k8s-auth not found"

echo ""
echo "=== Killing port-forwards ==="
KILLED=$(pkill -f "kubectl port-forward" 2>/dev/null && echo "yes" || echo "no")
if [ "$KILLED" = "yes" ]; then
  echo "  Port-forward processes stopped"
else
  echo "  No port-forward processes found"
fi

echo ""
echo "=== Done ==="
echo "To also delete K8s resources:"
echo "  kubectl delete -f mcp-stateless-auth-server.yaml"
echo "  kubectl delete -f mcp-stateless-server.yaml"
echo "  kubectl delete -f mcp-stateful-server.yaml"
