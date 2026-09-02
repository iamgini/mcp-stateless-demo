# Speaker Notes — MCP Goes Stateless
## CNCF Cloud Native Singapore Meetup 2026
### Gineesh Madapparambath | Architect, Red Hat

---

## Slide 1 — Title

> "Quick show of hands — how many of you have heard of MCP? How many have built something with it?"

MCP is already in Claude, Cursor, VS Code, kagent. But most people don't know what changed in July 2026, and why it matters for Kubernetes. Today: a protocol deep dive with a live demo.

---

## Slide 2 — About the Speaker

---

## Slide 3 — Agenda

> "We'll start with the problem MCP solves, how it works architecturally, then the stateful-to-stateless transition — the heart of today's talk. What it means for Kubernetes: load balancing, HPA, rolling updates. Then a live demo. About 40 minutes total."

---

## Slide 4 — The Tool Integration Problem

> "Every AI framework invented its own tool interface. LangGraph uses LangChain tools. CrewAI has its own format. AutoGen uses Python function wrappers. OpenAI has function calling. Anthropic has tool use. Same Kubernetes API — five different integrations."

> "No reuse. No standards. No governance. This is 2014 all over again — containers before Docker, services before Kubernetes."

> "MCP is the Kubernetes moment for tool integration. One protocol. All frameworks. All tools."

---

## Slide 5 — What is MCP?

> "MCP is an open standard for connecting AI agents to tools and data. Think of it as USB-C for AI — one connector, any device."

Timeline:
- **Nov 2024:** Anthropic launches MCP
- **Dec 2025:** Donated to Linux Foundation AAIF — becomes a community standard
- **Jul 2026:** Spec 2026-07-28 — goes stateless

Three primitives:
- **Tools:** functions the agent can call (like k8s_get_pods)
- **Resources:** data it can read (files, DB records)
- **Prompts:** reusable templates

> "Over 20,000 MCP servers indexed. 400 million monthly SDK downloads. 1 billion+ TypeScript and Python downloads. 247 AAIF member orgs. This is not a niche protocol."

---

## Slide 6 — API vs MCP

> "REST APIs were designed for humans writing code. MCP was designed for AI agents discovering tools dynamically at runtime. The agent doesn't read docs — it calls tools/list and gets everything it needs."

Row by row:
- **Discovery:** docs to auto-discovery. Zero integration code.
- **Schema:** MCP servers are self-describing. No OpenAPI spec needed.
- **Versioning:** MCP negotiates per request.
- **Auth:** agentgateway handles it centrally instead of 20 different API keys.

> "MCP does not replace REST APIs. Most MCP servers wrap existing REST APIs. MCP adds the discovery layer agents need."

---

## Slide 7 — MCP Architecture

> "MCP is client-server over JSON-RPC. Client is your AI agent — Claude, Cursor, kagent, VS Code. Server exposes tools, resources, or prompts."

Flow: `tools/list` → catalogue → `tools/call` → execute → structured results

New in 2026:
- **Mcp-Method / Mcp-Name headers:** header-based routing without body inspection. Any L7 load balancer works.
- **ttlMs + cacheScope:** HTTP-style caching. Client knows how long tools/list is fresh.
- **W3C Trace Context in _meta:** OpenTelemetry distributed tracing across the full agent graph.

---

## Slide 8 — Stateful MCP: The Kubernetes Problem

> "Before 2026-07-28, MCP used sessions. Client connects, server creates a Mcp-Session-Id, every request carries that ID. Pinned to one pod."

**1. Load Balancing:**
> "Couldn't use round-robin. Had to set sessionAffinity: ClientIP. Client IP changes in cloud — session breaks."

**2. HPA:**
> "New pods appear under load. Existing sessions pinned to old pods. New pods sit idle."

**3. Rolling Updates:**
> "Pod gets terminated. Agent mid-task gets an error. Had to drain sessions gracefully."

**4. Session Store:**
> "Redis or a database alongside every MCP server deployment. Enormous operational burden."

> "We were treating MCP servers like stateful databases. That's not cloud native."

---

## Slide 9 — Stateless MCP: The 2026 Fix

> "July 28, 2026 — largest revision since launch. Six SEPs. The headline: initialize handshake is gone."

- **initialize removed (SEP-2575):** no session setup round-trip
- **Mcp-Session-Id removed (SEP-2567):** no pinning, any request hits any pod
- **_meta carries everything:** protocol version + client info on every request
- **server/discover:** new optional RPC, mandatory for servers to implement

> "sessionAffinity — gone. Redis — gone. HPA breaking sessions — gone. Rolling update outages — gone."

> "MCP servers now deploy like any other Kubernetes microservice."

---

## Slide 10 — Stateful vs Stateless: Honest Trade-offs

> "Stateless wins on every infrastructure dimension. But it's not free."

Wins: load balancing, HPA, rolling updates, no session store.

Caveats:

**Long-running ops:**
> "Stateless needs the Tasks extension for async operations. Included in 2026 spec but it's an extension."

**Streaming:**
> "Native SSE was simple. Stateless streaming needs subscriptions/listen."

**Migration:**
> "Breaking change. 10-week validation window. Check if your MCP servers have a 2026-07-28 compatible version."

> "One-time migration pain for permanent operational improvement. Worth it."

---

## Slide 11 — MCP in the CNCF Ecosystem

**kagent (CNCF Sandbox):**
> "AI agents as Kubernetes-native CRDs. Tools are MCP servers — RemoteMCPServer resources. Stateless Streamable HTTP. Agents that scale like any other microservice."

**Grafana MCP:**
> "Official MCP server at github.com/grafana/mcp-grafana. 3k+ stars. Query dashboards, metrics, alerts via MCP."

**agentgateway (AAIF):**
> "Governs MCP traffic like Envoy governs HTTP. Auth, filtering, routing, observability at the edge."

**OpenTelemetry (CNCF Graduated):**
> "W3C Trace Context is first-class in _meta. Every tool call propagates trace context. Distributed tracing across the agent graph for free."

---

## Slide 12 — What's New in MCP 2026

**Stateless Core:** covered in depth already.

**Tasks Extension:**
> "Agent triggers a deployment rollout — that takes minutes. Tasks extension gives async polling: tasks/get, tasks/update."

**MCP Apps:**
> "Server-rendered UIs through MCP. Grafana dashboards inside agent conversations."

**Authorization Hardening:**
> "CIMD replaces Dynamic Client Registration. Aligns with OIDC and Keycloak. DCR still works for 12 months."

**Extensions Framework:**
> "Community extends MCP without touching core spec. Reverse-DNS identifiers like io.modelcontextprotocol/tasks."

**Deprecations:**
> "Roots, Sampling, Logging deprecated. Move to tool parameters and OpenTelemetry."

---

## Slide 13 — Live Demo

See `mcp_demo.md` for full script.

### Checklist
- [ ] `minikube status` — cluster running
- [ ] `kubectl get pods -l demo=mcp-stateless-talk` — 6 pods Running
- [ ] Test `./demo-scripts/01-stateful-no-init.sh` once
- [ ] Font large (18pt+), notifications off
- [ ] Bonus: `claude mcp get k8s-auth` shows Connected

### Flow (~5 min)

**Part 1 — Stateful Breaks (2.5 min)**
- Show 2+2 replicas, sessionAffinity: None
- `tools/list` without `initialize` → rejected
- `initialize` → get `Mcp-Session-Id`
- `tools/list` with session ID → ~50% fail

> "Two replicas and it's already broken. Imagine HPA scaling to 20 pods."

**Part 2 — Stateless Works (1.5 min)**
- `tools/list` directly → works, no session header
- Repeat 3-4 times → 100% success

> "One HTTP POST. No handshake. No session."

**Part 3 — Punchline (30 sec)**

> "Same image. Same tools. One flag. The protocol finally caught up."

**Bonus — Claude Code as MCP Client (if time, 2 min)**

Switch to Claude Code. Ask it to list pods or compare deployments. 20 K8s tools discovered via MCP — no kubectl.

> "Claude Code connects to the MCP server, discovers 20 Kubernetes tools, and calls them. No kubectl, no scripts, no custom integration."

### Q&A: "Where's the auth?"

> "Two layers. MCP server uses a Kubernetes ServiceAccount — standard RBAC. For client-to-server auth, we have an nginx sidecar validating an API key header. In production: agentgateway — auth, rate limiting, routing at the edge. The 2026 spec added CIMD for OAuth/OIDC."

### Fallback
- Pod name collision: `kubectl delete pod mcp-test --force --grace-period=0`
- Stateful doesn't reject: skip to session ID fails on wrong pod
- Cluster dead: show screenshot from rehearsal

---

## Slide 14 — Questions & Feedback

> "MCP went stateless in July 2026. Your Kubernetes cluster is already ready for it. The question is whether you'll be ready when AI agents start knocking on your services."

> "Happy to take questions. My contact details are right here on screen."

Contact links on slide: LinkedIn, gineesh.com, techbeatly.com, t.me/techbeatly

---

## Slide 15 — References & Links

> "Everything from today — YAMLs, demo script, curl commands — is at github.com/iamgini/mcp-stateless-demo. Clone it, try it on minikube."

> "MCP spec: modelcontextprotocol.io. The 2026-07-28 blog post is the authoritative source. AAIF at lfaidata.foundation."

> "kagent.dev for K8s-native agents. agentgateway for MCP traffic governance. Grafana MCP at github.com/grafana/mcp-grafana."

---

## Timing Summary

| Slide | Topic | Duration |
|---|---|---|
| 1 | Title | 1 min |
| 2 | About | 0.5 min |
| 3 | Agenda | 0.5 min |
| 4 | Tool Integration Problem | 2-3 min |
| 5 | What is MCP | 3 min |
| 6 | API vs MCP | 3 min |
| 7 | MCP Architecture | 2 min |
| 8 | Stateful Problem | 4 min |
| 9 | Stateless Fix | 4 min |
| 10 | Trade-offs | 2 min |
| 11 | CNCF Ecosystem | 3 min |
| 12 | What's New 2026 | 2 min |
| 13 | Live Demo | 5 min |
| 14 | Q&A | 5 min |
| 15 | References | 1 min |
| **Total** | | **~42 min** |
