# MCP Goes Stateless — Live Demo Script

## Goal of this demo

Prove one thing: **stateful MCP breaks on Kubernetes, stateless MCP just works.**

Same container image. Same tools. Same Kubernetes Service. One flag difference.

Total demo time: **5-7 minutes**

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
│  Sessions in-memory/pod    │  No server-side state              │
│  sessionAffinity: None     │  sessionAffinity: None             │
│  → BREAKS with round-robin │  → WORKS with round-robin          │
└────────────────────────────┴────────────────────────────────────┘
```

---

## Pre-requisites (one-time setup, not on stage)

Assumes minikube and kubectl are already installed.

### Step 1 — Create the minikube cluster

```bash
minikube start --cpus=2 --memory=4096 --driver=kvm2
kubectl cluster-info
```

### Step 2 — Deploy the MCP comparison servers (stateful vs stateless)

```bash
kubectl apply -f mcp-stateful-server.yaml
kubectl apply -f mcp-stateless-server.yaml
```

Wait for all 4 pods (2 stateful + 2 stateless):
```bash
kubectl get pods -l app=mcp-stateful-server
kubectl get pods -l app=mcp-stateless-server
```

### Step 3 — Pre-pull curl image (avoid slow pull on stage)

```bash
minikube ssh -- sudo crictl pull curlimages/curl:latest
```

---

## Pre-talk checklist (30 min before going on stage)

- [ ] Minikube running: `minikube status`
- [ ] MCP comparison pods running (4 pods): `kubectl get pods -l app=mcp-stateful-server && kubectl get pods -l app=mcp-stateless-server`
- [ ] Test the curl commands below at least once
- [ ] Terminal font size large (min 18pt)
- [ ] Notifications off, Slack/email closed

---

## Stage layout

Single terminal window, dark theme, large font.

---

## DEMO FLOW

---

### PART 1 — Stateful MCP: Watch It Break (3 minutes)

---

#### Beat 1.1 — Introduce the setup (30 seconds)

Say:
> "I have the same MCP server image deployed twice in this cluster.
> Same code, same tools, same container. The only difference is one flag:
> `--stateless`. Let me show you what happens with each."

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

Expected: both have 2 replicas Running, both services show `sessionAffinity: None`.

Say:
> "Both services have sessionAffinity: None — plain round-robin."

---

#### Beat 1.2 — Stateful: tools/list without initialize → REJECTED (30 seconds)

Say:
> "Let's try the old stateful server first. In the pre-2026 spec, you had
> to send an initialize request before doing anything else. What happens
> if I skip it and go straight to tools/list?"

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

Expected: error response — server requires initialization first.

Say:
> "Rejected. The server says: you haven't initialized a session.
> In the old spec, every client had to start with a handshake."

---

#### Beat 1.3 — Stateful: initialize → get session ID (30 seconds)

Say:
> "Fine. Let's play by the old rules. Send initialize."

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

Point out in the response:
> "See that header? `Mcp-Session-Id`. The server created a session and
> pinned it to this specific pod. Every future request must carry that
> header — and must hit the same pod."

Note the `Mcp-Session-Id` value from the response headers for the next step.

---

#### Beat 1.4 — Stateful: tools/list with session → works sometimes, fails sometimes (1 minute)

Say:
> "Now watch what happens when I send tools/list with the session ID.
> I have two pods behind round-robin. The session only exists on one pod."

Run this multiple times (replace `SESSION_ID` with the actual value from Beat 1.3):

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

Expected: roughly 50% succeed (hit the right pod), 50% fail (hit the wrong pod).

Say:
> "There it is. Same session ID, same service, but round-robin sends it to
> different pods. The pod that doesn't have my session rejects the request.
> This is why the old spec forced you to use sessionAffinity: ClientIP,
> or run Redis as a shared session store.
> Two replicas and it's already broken. Imagine this with HPA scaling
> to 20 pods under load."

---

### PART 2 — Stateless MCP: Watch It Work (2 minutes)

---

#### Beat 2.1 — Stateless: tools/list directly → works immediately (1 minute)

Say:
> "Now the same image, same tools — but with the `--stateless` flag.
> This is the 2026-07-28 spec. No initialize. No session. Just send
> the request."

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

Point out:
1. **No `Mcp-Session-Id` in the response headers** — no session was created
2. **No `initialize` needed** — we went straight to `tools/list`
3. **Got a full tool list back** — it just works

Say:
> "One HTTP POST. No handshake. No session. The server doesn't know or
> care which pod handled the last request."

---

#### Beat 2.2 — Stateless: repeat it — works every single time (30 seconds)

Run this 3-4 times:

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

Expected: 100% success rate.

Say:
> "Every request succeeds. Round-robin, random, least-connections —
> any load balancing algorithm works. No session affinity needed.
> This is what SEP-2575 and SEP-2567 gave us."

---

### PART 3 — The Punchline (30 seconds)

Say:
> "Same image. Same tools. Same two replicas. Same Service with no
> session affinity. The only difference: one flag.
> The stateful server broke 50% of the time. The stateless server
> worked 100% of the time.
> That's the entire 2026-07-28 spec change in one demo."

Pause. Let it land.

> "MCP servers now deploy like any other Kubernetes microservice.
> No sticky sessions. No Redis sidecars. No HPA headaches.
> Your cluster was always ready. The protocol finally caught up."

---

## Cleanup after demo

```bash
kubectl delete -f mcp-stateful-server.yaml
kubectl delete -f mcp-stateless-server.yaml
```

---

## Fallback plans

### Curl pod name collision

```bash
kubectl delete pod mcp-test --force --grace-period=0 2>/dev/null
```

Then retry the curl command.

### Stateful server doesn't reject tools/list without session

Some SDK versions auto-create sessions. In that case, skip Beat 1.2 and focus on
Beat 1.4 (session ID not recognized by the other pod). The scaling failure is the
stronger demo point anyway.

### MCP server pods won't start

Check logs:
```bash
kubectl logs -l app=mcp-stateful-server --tail=10
```

Common fix — the image needs `--port 8080` (not `--transport http`).

### Minikube issues

```bash
minikube status
minikube ssh -- crictl images | grep kubernetes-mcp
```

---

## What to mention verbally (not shown live)

| Feature | What to say |
|---|---|
| kagent | "kagent is a CNCF Sandbox project that runs AI agents as Kubernetes CRDs. It uses stateless MCP under the hood — the same protocol you just saw." |
| W3C Trace Context | "The 2026 spec puts W3C trace context in every request. With Jaeger or Tempo, you get distributed tracing across the agent graph for free." |
| Mcp-Method / Mcp-Name headers | "In production, put agentgateway in front and route on these headers. Any L7 load balancer can do method-based routing now." |
| Tasks extension | "What about a 5-minute deployment rollout? The Tasks extension gives you async polling — tasks/get to check status." |

---

## Timing summary

| Part | Content | Duration |
|---|---|---|
| 1 | **Stateful breaks** — initialize, session ID, 50% failure | 3 min |
| 2 | **Stateless works** — direct tools/list, 100% success | 2 min |
| 3 | **Punchline** — same image, one flag, protocol caught up | 0.5 min |
| **Total** | | **~5.5 min** |

---

## Quick reference — key commands

```bash
# Minikube status
minikube status

# MCP server pods
kubectl get pods -l app=mcp-stateful-server
kubectl get pods -l app=mcp-stateless-server

# Session affinity check
kubectl get svc mcp-stateful-svc mcp-stateless-svc \
  -o custom-columns='NAME:.metadata.name,AFFINITY:.spec.sessionAffinity'

# Cleanup
kubectl delete -f mcp-stateful-server.yaml
kubectl delete -f mcp-stateless-server.yaml
```
