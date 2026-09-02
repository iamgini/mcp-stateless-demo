# MCP Goes Stateless — Live Demo Script

## Goal

Prove one thing: **stateful MCP breaks on Kubernetes, stateless MCP just works.**

Same container image. Same tools. Same Kubernetes Service. One flag difference.

Total demo time: **~5 minutes**

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│  ghcr.io/containers/kubernetes-mcp-server:latest                │
│  (containers org — community maintained, ~1.8k GitHub stars)     │
├────────────────────────────┬────────────────────────────────────┤
│  mcp-stateful-server       │  mcp-stateless-server              │
│  2 replicas                │  2 replicas                        │
│  NO --stateless flag       │  WITH --stateless flag             │
│  Requires initialize       │  Direct tools/list                 │
│  Returns Mcp-Session-Id    │  No session headers                │
│  sessionAffinity: None     │  sessionAffinity: None             │
│  → BREAKS with round-robin │  → WORKS with round-robin          │
└────────────────────────────┴────────────────────────────────────┘
```

---

## Pre-requisites (one-time setup, not on stage)

### Step 1 — Create the minikube cluster

```bash
minikube start --cpus=2 --memory=4096 --driver=kvm2 --kubernetes-version=v1.37.0
```

### Step 2 — Deploy MCP servers

```bash
kubectl apply -f mcp-stateful-server.yaml
kubectl apply -f mcp-stateless-server.yaml
kubectl apply -f mcp-stateless-auth-server.yaml
```

Wait for all pods:

```bash
kubectl get pods -l demo=mcp-stateless-talk
```

### Step 3 — Pre-pull curl image

```bash
minikube ssh -- sudo crictl pull curlimages/curl:latest
```

### Step 4 — Set up Claude Code MCP (optional bonus demo)

```bash
./demo-scripts/10-port-forward.sh
claude mcp add-json k8s-auth '{"type":"http","url":"http://localhost:8083/mcp","headers":{"X-Api-Key":"demo-secret-2026"}}'
```

---

## Pre-talk checklist (30 min before stage)

- [ ] `minikube status` — cluster running
- [ ] `kubectl get pods -l demo=mcp-stateless-talk` — 6 pods Running (2 stateful + 2 stateless + 2 auth)
- [ ] Run `./demo-scripts/01-stateful-no-init.sh` once — verify it works
- [ ] Terminal font size large (min 18pt), notifications off
- [ ] If doing bonus demo: `claude mcp get k8s-auth` shows Connected

---

## DEMO FLOW

---

### PART 1 — Stateful MCP: Watch It Break (2.5 min)

#### Beat 1.1 — Show the setup (30 sec)

> "Same MCP server image deployed twice. Same tools, same container. Only difference: one flag."

```bash
./demo-scripts/00-show-setup.sh
```

<details><summary>Full command</summary>

```bash
kubectl get pods -l app=mcp-stateful-server
kubectl get pods -l app=mcp-stateless-server
kubectl get svc mcp-stateful-svc mcp-stateless-svc \
  -o custom-columns='NAME:.metadata.name,AFFINITY:.spec.sessionAffinity'
```

</details>

> "Both services have sessionAffinity: None — plain round-robin."

#### Beat 1.2 — tools/list without initialize → REJECTED (30 sec)

> "Old spec required initialize first. What if I skip it?"

```bash
./demo-scripts/01-stateful-no-init.sh
```

<details><summary>Full command</summary>

```bash
kubectl run mcp-test --rm -it --restart=Never --image=curlimages/curl -- \
  curl -s -w "\n\nHTTP Status: %{http_code}\n" \
  -X POST \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  http://mcp-stateful-svc:8080/mcp \
  -d '{"jsonrpc":"2.0","method":"tools/list","id":1}'
```

</details>

> "Rejected. Server says: you haven't initialized a session."

#### Beat 1.3 — initialize → get session ID (30 sec)

> "Fine. Let's play by the old rules."

```bash
./demo-scripts/02-stateful-initialize.sh
```

<details><summary>Full command</summary>

```bash
kubectl run mcp-test --rm -it --restart=Never --image=curlimages/curl -- \
  curl -s -D /dev/stderr \
  -X POST \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  http://mcp-stateful-svc:8080/mcp \
  -d '{"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"demo","version":"1.0"}},"id":1}'
```

</details>

> "See that Mcp-Session-Id header? Pinned to one pod. Every future request must carry it."

Note the session ID for the next step.

#### Beat 1.4 — tools/list with session → 50% fail (1 min)

> "Two pods, round-robin. Session only exists on one."

Run 2-3 times:

```bash
./demo-scripts/03-stateful-with-session.sh <SESSION_ID>
```

<details><summary>Full command</summary>

```bash
kubectl run mcp-test --rm -it --restart=Never --image=curlimages/curl -- \
  curl -s -w "\nHTTP Status: %{http_code}\n" \
  -X POST \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -H "Mcp-Session-Id: SESSION_ID" \
  http://mcp-stateful-svc:8080/mcp \
  -d '{"jsonrpc":"2.0","method":"tools/list","id":2}'
```

</details>

> "Two replicas and it's already broken. Imagine HPA scaling to 20 pods."

---

### PART 2 — Stateless MCP: Watch It Work (1.5 min)

#### Beat 2.1 — tools/list directly → works (1 min)

> "Same image, same tools, but with `--stateless`. No initialize. Just send the request."

```bash
./demo-scripts/04-stateless-tools-list.sh
```

<details><summary>Full command</summary>

```bash
kubectl run mcp-test --rm -it --restart=Never --image=curlimages/curl -- \
  curl -s -D /dev/stderr \
  -X POST \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  http://mcp-stateless-svc:8080/mcp \
  -d '{"jsonrpc":"2.0","method":"tools/list","id":1}'
```

</details>

> "No Mcp-Session-Id in response. No initialize needed. It just works."

#### Beat 2.2 — Repeat → 100% success (30 sec)

Run 3-4 times:

```bash
./demo-scripts/05-stateless-repeat.sh
```

<details><summary>Full command</summary>

```bash
kubectl run mcp-test --rm -it --restart=Never --image=curlimages/curl -- \
  curl -s -w "\nHTTP Status: %{http_code}\n" \
  -X POST \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  http://mcp-stateless-svc:8080/mcp \
  -d '{"jsonrpc":"2.0","method":"tools/list","id":1}'
```

</details>

> "100% success. Any load balancing algorithm works. That's SEP-2575 and SEP-2567."

---

### PART 3 — Punchline (30 sec)

> "Same image. Same tools. Same two replicas. Same Service with no session affinity. One flag.
> Stateful broke 50%. Stateless worked 100%.
> MCP servers now deploy like any other Kubernetes microservice."

---

## BONUS: Claude Code as MCP Client (if time permits, ~2 min)

> "Let me show you what this looks like from an actual AI agent."

Switch to a terminal with Claude Code already connected to the auth-enabled MCP server.

```
List all pods in the default namespace
```

Claude Code discovers 20 K8s tools via MCP and calls them — no kubectl, no scripts.

Then:

```
Compare the mcp-stateful-server and mcp-stateless-server deployments. What's different?
```

Claude Code makes multiple MCP tool calls, compares results, and explains the `--stateless` flag.

### Setup (done before the talk)

```bash
# Port-forward the auth-enabled MCP server
./demo-scripts/10-port-forward.sh

# Add to Claude Code with API key auth
claude mcp add-json k8s-auth '{"type":"http","url":"http://localhost:8083/mcp","headers":{"X-Api-Key":"demo-secret-2026"}}'

# Verify
claude mcp get k8s-auth
```

### Auth architecture

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

Two auth boundaries:
1. **Claude Code → MCP server:** API key via `X-Api-Key` header, validated by nginx sidecar. In production: agentgateway with OAuth/OIDC (CIMD in 2026 spec)
2. **MCP server → K8s API:** ServiceAccount token, scoped via ClusterRole (read-only)

### Test auth from curl

```bash
# Without key — 401
curl -s -X POST \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  http://localhost:8083/mcp \
  -d '{"jsonrpc":"2.0","method":"tools/list","id":1}'

# With key — 200 + 20 tools
curl -s -X POST \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -H "X-Api-Key: demo-secret-2026" \
  http://localhost:8083/mcp \
  -d '{"jsonrpc":"2.0","method":"tools/list","id":1}' \
  | sed -n 's/^data: //p' | jq '.result.tools | length'
```

### Production auth pattern

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

---

## Cleanup

```bash
# Remove MCP servers from Claude Code + kill port-forwards
./demo-scripts/11-cleanup.sh

# Delete K8s resources (optional)
kubectl delete -f mcp-stateful-server.yaml
kubectl delete -f mcp-stateless-server.yaml
kubectl delete -f mcp-stateless-auth-server.yaml
```

---

## Fallback plans

| Problem | Fix |
|---|---|
| Curl pod name collision | `kubectl delete pod mcp-test --force --grace-period=0` |
| Stateful doesn't reject without session | Skip to Beat 1.4 — session ID fails on wrong pod |
| MCP pods won't start | `kubectl logs -l app=mcp-stateful-server --tail=10` |
| Cluster dead | Show screenshot from rehearsal |

---

## What to mention verbally (not shown live)

| Feature | What to say |
|---|---|
| kagent | "CNCF Sandbox project — runs AI agents as K8s CRDs, uses stateless MCP under the hood." |
| W3C Trace Context | "2026 spec puts trace context in every request. Jaeger/Tempo gives you distributed tracing for free." |
| Mcp-Method / Mcp-Name | "In production, route on these headers at the gateway. Any L7 load balancer works." |
| Tasks extension | "5-minute deployment rollout? Tasks extension gives you async polling — tasks/get to check status." |

---

## Timing summary

| Part | Content | Duration |
|---|---|---|
| 1 | **Stateful breaks** — setup, init, session, 50% failure | 2.5 min |
| 2 | **Stateless works** — direct tools/list, 100% success | 1.5 min |
| 3 | **Punchline** — same image, one flag | 0.5 min |
| Bonus | **Claude Code** — AI agent using MCP (if time) | 2 min |
| **Core total** | | **~4.5 min** |

---

## Quick reference

```bash
# Cluster
minikube status

# Pods
kubectl get pods -l demo=mcp-stateless-talk

# Session affinity
kubectl get svc mcp-stateful-svc mcp-stateless-svc mcp-auth-svc \
  -o custom-columns='NAME:.metadata.name,AFFINITY:.spec.sessionAffinity'

# Port-forwards
./demo-scripts/10-port-forward.sh

# Claude Code MCP
claude mcp add-json k8s-auth '{"type":"http","url":"http://localhost:8083/mcp","headers":{"X-Api-Key":"demo-secret-2026"}}'
claude mcp get k8s-auth
claude mcp remove k8s-auth

# Cleanup
./demo-scripts/11-cleanup.sh
```
