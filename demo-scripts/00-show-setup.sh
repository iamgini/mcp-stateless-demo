#!/bin/bash
# Beat 1.1 — Show pods and services

echo "=== MCP Server Pods ==="
kubectl get pods -l app=mcp-stateful-server
echo ""
kubectl get pods -l app=mcp-stateless-server

echo ""
echo "=== Service Session Affinity ==="
kubectl get svc mcp-stateful-svc mcp-stateless-svc \
  -o custom-columns='NAME:.metadata.name,AFFINITY:.spec.sessionAffinity'
