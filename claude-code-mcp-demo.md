# Claude Code + MCP: Kubernetes Agent Demo

Use Claude Code as an MCP client to interact with Kubernetes through the MCP server — no kubectl, no custom scripts, just natural language.

## Architecture

```
┌──────────────┐     port-forward      ┌─────────────────────────┐     K8s API     ┌────────────────┐
│  Claude Code  │ ──── localhost:8082 ──→│  mcp-stateless-server   │ ──────────────→ │  K8s API Server │
│  (MCP Client) │     Streamable HTTP   │  (ServiceAccount+RBAC)  │   in-cluster    │                │
└──────────────┘                        └─────────────────────────┘                 └────────────────┘
```

**Auth flow:**
1. **Claude Code → MCP server:** port-forward (localhost, no auth needed). In production: agentgateway with OAuth/OIDC (CIMD in 2026 spec)
2. **MCP server → K8s API:** ServiceAccount token auto-mounted by Kubernetes, scoped via ClusterRole/ClusterRoleBinding (read-only in this demo)

## Setup

### Step 1 — Start port-forwards

In a separate terminal:

```bash
./demo-scripts/10-port-forward.sh
```

Or manually:

```bash
kubectl port-forward svc/mcp-stateless-svc 8082:8080 &
kubectl port-forward svc/mcp-stateful-svc 8081:8080 &
```

### Step 2 — Verify MCP servers respond

```bash
curl -s -X POST \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  http://localhost:8082/mcp \
  -d '{"jsonrpc":"2.0","method":"tools/list","id":1}' \
  | sed -n 's/^data: //p' | jq '.result.tools | length'
```

Expected: a number (the tool count — should be 20 Kubernetes tools).

### Step 3 — Add MCP servers to Claude Code

```bash
# Stateless (2026-07-28 spec — recommended)
claude mcp add --transport http k8s-stateless http://localhost:8082/mcp

# Stateful (old spec — for comparison)
claude mcp add --transport http k8s-stateful http://localhost:8081/mcp
```

Verify they're configured:

```bash
claude mcp list
```

### Step 4 — Launch Claude Code

```bash
claude
```

Claude Code will connect to both MCP servers on startup. You'll see the tool count in the status bar.

## Sample Prompts

### Discovery — what tools are available?

```
What Kubernetes tools do you have available via MCP? List them all.
```

Claude Code calls `tools/list` on the MCP server and shows all 21 tools.

### Basic operations

```
List all pods in the default namespace
```

```
What deployments are running in this cluster?
```

```
Show me all services and their types
```

### Deeper inspection

```
Describe the mcp-stateless-server deployment — how many replicas, what image, what args?
```

```
Show me the ClusterRole and ClusterRoleBinding for the MCP server ServiceAccount
```

```
Are there any pods not in Running state?
```

### Multi-step reasoning

```
Compare the mcp-stateful-server and mcp-stateless-server deployments.
What's different between them?
```

This is where MCP shines — Claude Code will call `tools/call` multiple times, compare the results, and explain the `--stateless` flag difference.

### The auth question

```
What ServiceAccount is the MCP server using? What permissions does it have?
Show me the RBAC chain: ServiceAccount → ClusterRoleBinding → ClusterRole → rules.
```

Claude Code will trace the full RBAC chain through MCP tool calls — making the auth model visible.

## Stateful vs Stateless Comparison

### Why stateless works through port-forward

Port-forward creates a tunnel to one pod, so even the stateful server appears to work. This masks the load-balancing issue.

To see the real difference, use the **curl-based demo** (`mcp_demo.md`) which runs from inside the cluster and hits the Service directly — round-robin exposes the stateful failure.

### What Claude Code shows differently

With the **stateless** MCP server, Claude Code:
- Connects with zero handshake — no `initialize` round-trip
- Sends `tools/list` immediately
- Every request is independent — reconnects transparently if the port-forward drops

With the **stateful** MCP server, Claude Code:
- Must send `initialize` first (handled automatically by the MCP client)
- Gets back a `Mcp-Session-Id` header
- All subsequent requests carry that session ID
- If the port-forward reconnects to a different pod, the session is lost

Try this: kill the port-forward and restart it while Claude Code is connected.
- **Stateless:** Claude Code recovers automatically — next request just works
- **Stateful:** Claude Code gets a session error — must re-initialize

### Quick test: kill and reconnect

```bash
# In another terminal, while Claude Code is running:

# Kill the stateless port-forward
kill $(lsof -ti:8082) 2>/dev/null

# Restart it (may land on a different pod)
kubectl port-forward svc/mcp-stateless-svc 8082:8080 &

# Now ask Claude Code to list pods again — it should work immediately
```

```bash
# Same test with stateful:
kill $(lsof -ti:8081) 2>/dev/null
kubectl port-forward svc/mcp-stateful-svc 8081:8080 &

# Ask Claude Code to list pods — stateful server may reject (session lost)
```

## Auth-Enabled MCP Server (API Key)

Adds an nginx sidecar that validates an `X-Api-Key` header before proxying to the MCP server. Same pattern as agentgateway, simplified for demos.

### Deploy

```bash
kubectl apply -f mcp-stateless-auth-server.yaml
kubectl wait --for=condition=ready pod -l app=mcp-auth-server --timeout=60s
```

### Port-forward

```bash
kubectl port-forward svc/mcp-auth-svc 8083:9080 &
```

### Test auth from curl

```bash
# Without key — 401
curl -s -X POST \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  http://localhost:8083/mcp \
  -d '{"jsonrpc":"2.0","method":"tools/list","id":1}'

# With key — 200 + tools
curl -s -X POST \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -H "X-Api-Key: demo-secret-2026" \
  http://localhost:8083/mcp \
  -d '{"jsonrpc":"2.0","method":"tools/list","id":1}' \
  | sed -n 's/^data: //p' | jq '.result.tools | length'
```

### Connect Claude Code with auth

```bash
claude mcp add --transport http \
  --header "X-Api-Key: demo-secret-2026" \
  k8s-auth http://localhost:8083/mcp
```

Claude Code sends the `X-Api-Key` header on every MCP request. Nginx validates it and proxies to the MCP server. Without the header or with a wrong key, you get a clean JSON-RPC 401 error.

### How it works

```
Claude Code                    nginx sidecar              MCP server          K8s API
    │                              │                          │                  │
    │── POST /mcp ────────────────→│                          │                  │
    │   X-Api-Key: demo-secret-2026│                          │                  │
    │                              │── validates key ──→ OK   │                  │
    │                              │── proxy_pass ───────────→│                  │
    │                              │                          │── SA token ─────→│
    │                              │                          │←── pods list ────│
    │                              │←─── tools/list result ──│                  │
    │←──── SSE response ──────────│                          │                  │
```

### Architecture (same pod, two containers)

```yaml
Pod:
  ├── nginx:alpine          (port 9080, validates X-Api-Key)
  └── kubernetes-mcp-server (port 8080, --stateless, no auth)
Service: mcp-auth-svc → port 9080
```

The API key is `demo-secret-2026` — set in the nginx ConfigMap. In production, use a Kubernetes Secret + environment variable substitution, or use agentgateway with proper OAuth/OIDC.

---

## Cleanup

### Step 1 — Remove MCP servers from Claude Code

```bash
claude mcp remove k8s-stateless
claude mcp remove k8s-stateful
claude mcp remove k8s-auth
```

Verify they're gone:

```bash
claude mcp list
```

### Step 2 — Stop port-forwards

If you used `10-port-forward.sh`, press `Ctrl+C` in that terminal.

If you started port-forwards manually in the background:

```bash
./demo-scripts/11-cleanup.sh
```

Or manually:

```bash
# Kill all kubectl port-forward processes
pkill -f "kubectl port-forward" 2>/dev/null
```

### Step 3 — Delete Kubernetes resources (optional)

```bash
kubectl delete -f mcp-stateless-auth-server.yaml
kubectl delete -f mcp-stateless-server.yaml
kubectl delete -f mcp-stateful-server.yaml
```

## Production Auth Pattern

In production, you wouldn't use port-forward. The stack looks like:

```
┌──────────────┐      HTTPS + OAuth      ┌────────────────┐      ClusterIP      ┌──────────────┐
│  Claude Code  │ ─────────────────────→ │  agentgateway   │ ─────────────────→ │  MCP Server   │
│  (external)   │   CIMD / OIDC token    │  (edge proxy)   │   (internal only)  │  (stateless)  │
└──────────────┘                         │  - auth          │                    │  - SA + RBAC  │
                                         │  - rate limiting │                    └──────────────┘
                                         │  - per-tool ACL  │
                                         │  - OTel tracing  │
                                         └────────────────┘
```

- **agentgateway** handles auth at the edge (OAuth/OIDC via CIMD, the 2026 spec replacement for DCR)
- **MCP server** stays internal (ClusterIP), no direct external access
- **ServiceAccount + RBAC** scopes what the MCP server can do on the K8s API
- **Mcp-Method / Mcp-Name headers** enable per-tool routing and access control at the gateway
