# MCP Goes Stateless: Live Demo

Live demo materials for the talk **"MCP Goes Stateless: How the AI Agent Protocol Finally Became Cloud Native"** at CNCF Cloud Native and HUG Singapore Meetup (August 2026).

## What this demo proves

Stateful MCP breaks on Kubernetes. Stateless MCP just works. Same container image, same tools, same Service — one flag difference.

## Files

| File | Purpose |
|---|---|
| `mcp_demo.md` | Full demo script with setup, commands, speaker cues, and fallback plans |
| `mcp_speaker_notes.md` | Slide-by-slide speaker notes for the full talk |
| `mcp-stateful-server.yaml` | MCP server deployment — stateful mode (old spec, requires initialize/session) |
| `mcp-stateless-server.yaml` | MCP server deployment — stateless mode (2026-07-28 spec, no session) |

## Quick start

```bash
# 1. Start minikube
minikube start --cpus=2 --memory=4096 --driver=kvm2

# 2. Deploy both MCP servers
kubectl apply -f mcp-stateful-server.yaml
kubectl apply -f mcp-stateless-server.yaml

# 3. Wait for pods
kubectl get pods -l demo=mcp-stateless-talk -w

# 4. Run the demo (see mcp_demo.md for full script)
```

## MCP server image

Both deployments use [`ghcr.io/containers/kubernetes-mcp-server`](https://github.com/containers/kubernetes-mcp-server) — a Red Hat maintained Kubernetes MCP server. The `--stateless` flag toggles between stateful (old spec) and stateless (2026-07-28 spec) modes.

## Key MCP spec changes (2026-07-28)

- **SEP-2575**: `initialize` handshake removed
- **SEP-2567**: `Mcp-Session-Id` header removed
- **SEP-2243**: `Mcp-Method` / `Mcp-Name` headers for L7 routing
- **SEP-2549**: `ttlMs` + `cacheScope` for HTTP-style caching

## Related

- [MCP Specification](https://spec.modelcontextprotocol.io/)
- [kagent — AI Agents as Kubernetes CRDs](https://kagent.dev/) (CNCF Sandbox)
- [kubernetes-mcp-server](https://github.com/containers/kubernetes-mcp-server)
- [agentgateway](https://github.com/agentgateway/agentgateway) (AAIF)

## Speaker

**Gineesh Madapparambath** | Architect, Red Hat
- [techbeatly.com](https://techbeatly.com)
- [linkedin.com/in/gineesh](https://linkedin.com/in/gineesh)
