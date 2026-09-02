# Speaker Notes — MCP Goes Stateless
## CNCF Cloud Native Singapore Meetup 2026
### Gineesh Madapparambath | Architect, Red Hat

---

## Slide 1 — Title

Opening line:
> "Before we talk about MCP going stateless, let me ask a quick question — how many of you have heard of MCP? How many have built something with it?"

Set the scene: MCP is already everywhere — in Claude, Cursor, VS Code, kagent. But most people using it don't fully understand what changed under the hood in July 2026, and why that change matters enormously for Kubernetes platform engineers.

Today's talk is about that change. Not a product pitch. A protocol deep dive — with a live demo at the end.

**Duration: 1 minute max. Get to the content quickly.**

---

## Slide 2 — About the Speaker

---

## Slide 3 — Agenda

Walk the audience through the structure quickly — set expectations.

> "We'll start with the problem that MCP was created to solve, then look at how MCP works architecturally, then spend the most time on the stateful-to-stateless transition because that's the heart of today's talk. We'll look at what it means concretely for Kubernetes — load balancing, HPA, rolling updates. Then we'll see it live in a demo. Total time about 40 minutes."

**Duration: 30 seconds.**

---

## Slide 4 — The Tool Integration Problem

This is the setup. Make the pain tangible before showing the solution.

Key talking point:
> "Every AI framework invented its own tool interface. LangGraph uses LangChain tools. CrewAI has its own format. AutoGen uses Python function wrappers. OpenAI has function calling. Anthropic has tool use. If you want to expose the same Kubernetes API to all five frameworks, you're writing the same integration five different times."

Pause for effect:
> "No reuse. No standards. No governance. Sound familiar? This is 2014 all over again — containers before Docker, services before Kubernetes."

Landing line:
> "MCP is the Kubernetes moment for tool integration. One protocol. All frameworks. All tools."

**Duration: 2-3 minutes.**

---

## Slide 5 — What is MCP?

Give a crisp definition first:
> "MCP is an open standard protocol for connecting AI agents to tools and data sources. Think of it as USB-C for AI — one connector, any device."

Walk the timeline briefly:
- **Nov 2024:** Anthropic launches MCP. Nobody pays attention at first.
- **Dec 2025:** Donated to the Linux Foundation's AAIF alongside goose and AGENTS.md. This is the moment it becomes a community standard, not an Anthropic proprietary protocol.
- **Jul 2026:** Spec 2026-07-28 — goes stateless. This is why we're here today.

Three primitives — keep this fast:
- **Tools:** functions the agent can call (like k8s_get_pods)
- **Resources:** data it can read (files, DB records)
- **Prompts:** reusable templates

The scale numbers hit hard (match what's on the slide):
> "Over 20,000 MCP servers indexed. 400 million monthly SDK downloads. TypeScript and Python SDKs have each crossed 1 billion total downloads. 247 AAIF member orgs. This is not a niche protocol."

**Duration: 3 minutes.**

---

## Slide 6 — API vs MCP

This slide often gets the best audience reaction. Start with the key insight:

> "REST APIs were designed for humans writing code. You read the docs, you write the integration, you maintain it. MCP was designed for AI agents discovering and calling tools dynamically at runtime. The agent doesn't read docs. It just calls tools/list and gets everything it needs."

Walk the table row by row — 30 seconds per row max:
- **Discovery:** The shift from docs to auto-discovery is the big one. Zero integration code.
- **Schema:** MCP servers are self-describing. The agent knows what each tool does without you writing an OpenAPI spec.
- **Versioning:** REST versioning is painful. MCP negotiates per request.
- **Auth:** Instead of managing 20 different API keys, agentgateway handles it centrally.

Important nuance — say this clearly:
> "MCP does not replace REST APIs. Most MCP servers wrap existing REST APIs underneath. What MCP adds is the discovery and invocation layer that agents need to call them without custom glue code."

**Duration: 3 minutes.**

---

## Slide 7 — MCP Architecture

Keep this technical but accessible. Two minutes max.

> "MCP is a client-server protocol over JSON-RPC. The client is your AI agent — Claude, Cursor, kagent, VS Code. The server is whatever exposes tools, resources, or prompts."

The flow:
1. Client calls `tools/list` — gets back a catalogue of everything the server can do
2. Client calls `tools/call` with the tool name and parameters
3. Server executes and returns structured results
4. Agent uses the result in its reasoning

Point out the new 2026 additions specifically:
- **Mcp-Method and Mcp-Name headers:** "This is what enables plain header-based routing without inspecting the JSON body. Any L7 load balancer can route on this. No sticky sessions needed."
- **ttlMs + cacheScope:** "HTTP-style caching. The client knows how long a tools/list response is fresh. Drastically reduces round-trips."
- **W3C Trace Context in _meta:** "OpenTelemetry distributed tracing out of the box. Every tool call is traceable across the full agent graph."

**Duration: 2 minutes.**

---

## Slide 8 — Stateful MCP: The Kubernetes Problem

This is where you build tension before the resolution on slide 9. Take your time here — the audience needs to feel the pain to appreciate the fix.

> "Before spec 2026-07-28, MCP used a session model. When a client connected, the server created a session and handed back a Mcp-Session-Id header. Every subsequent request carried that ID. That ID pinned you to one specific server instance."

Walk through each problem card:

**1. Load Balancing:**
> "You couldn't use plain round-robin. You had to set sessionAffinity: ClientIP on every Kubernetes Service. The moment a client's IP changed — common in cloud environments — the session broke."

**2. HPA:**
> "When HPA scaled out under load, new pods appeared. But existing sessions were pinned to old pods. You couldn't redistribute. The new pods sat idle while the old ones were overloaded."

**3. Rolling Updates:**
> "Deploy a new version? The pod serving active sessions gets terminated. The agent mid-task gets an error. You had to drain sessions gracefully, which made rolling updates significantly more complex."

**4. Session Store:**
> "To make sessions survive pod restarts, you had to run Redis or a database alongside every MCP server deployment. For a 'just spin up an MCP server' use case, that's an enormous operational burden."

Landing line:
> "We were treating MCP servers like stateful databases. That's not cloud native."

**Duration: 3-4 minutes. This is the setup for your hero slide.**

---

## Slide 9 — Stateless MCP: The 2026 Fix

This is your hero slide. Build it up.

> "On July 28, 2026, the MCP spec released the largest revision since launch. Six separate enhancement proposals landed at once. The headline change: the initialize handshake is gone."

Explain each change:
- **initialize removed (SEP-2575):** "No more session setup round-trip. The client just starts sending requests."
- **Mcp-Session-Id removed (SEP-2567):** "No header means no pinning. Any request can land on any server instance."
- **_meta carries everything:** "Protocol version, client info, capabilities — all travel inside the request metadata on every call. Stateless by design."
- **server/discover:** "New optional RPC. Clients can call it to get capabilities up front. Every server must implement it, but calling it is optional."

Then walk the before/after:
> "sessionAffinity: ClientIP — gone. Redis session store — gone. HPA breaking sessions — gone. Rolling update outages — gone."

Landing line — say this slowly:
> "MCP servers now deploy like any other Kubernetes microservice."

Let that land. Pause. It's the core message of the entire talk.

**Duration: 4 minutes. This is the climax.**

---

## Slide 10 — Stateful vs Stateless: Honest Trade-offs

Don't oversell stateless. Be honest — it earns more trust.

> "The stateless move wins for Kubernetes on every infrastructure dimension. But it's not free — and I want to be honest about the trade-offs."

Walk the wins quickly — load balancing, HPA, rolling updates, session store. These are obvious from slide 9.

Then pause on the caveats:

**1. Long-running ops:**
> "In the stateful model, an agent could hold a session open for a complex multi-step task. In stateless, long-running async operations need the Tasks extension — io.modelcontextprotocol/tasks. It's included in the 2026 spec but it's an extension, not the core. Check if your MCP server supports it."

**2. Streaming:**
> "Native SSE streaming over a session was simple. Stateless streaming needs the subscriptions/listen stream pattern which is more complex to implement. Watch this space."

**3. Migration:**
> "This is a breaking change. Existing MCP clients and servers need updates. The spec included a 10-week validation window. If you have MCP servers in production, check if they've published a 2026-07-28 compatible version."

Verdict:
> "One-time migration pain for permanent operational improvement. Worth it."

**Duration: 2 minutes.**

---

## Slide 11 — MCP in the CNCF Ecosystem

This grounds the talk in concrete projects your audience already uses or knows.

**kagent (CNCF Sandbox):**
> "kagent lets you run AI agents as Kubernetes-native CRDs. The agent's tools are MCP servers — defined as RemoteMCPServer resources in your cluster. All speaking stateless Streamable HTTP. No sticky sessions, no session stores. kagent is what happens when you combine Kubernetes operators with stateless MCP — agents that scale like any other microservice."

**Grafana MCP:**
> "Grafana Labs maintains an official MCP server at github.com/grafana/mcp-grafana. 3,239 GitHub stars. Apache 2.0. Your agents can query dashboards, metrics, and alerts via MCP without writing any custom integration. Just point kagent at the Grafana MCP server."

**agentgateway (AAIF):**
> "agentgateway governs MCP traffic the same way Envoy governs HTTP traffic in a service mesh. Auth, filtering, routing, observability — all at the edge, before the request reaches your MCP server. If you're running MCP servers in production with multiple clients, agentgateway is the governance layer."

**OpenTelemetry (CNCF Graduated):**
> "The 2026-07-28 spec made W3C Trace Context a first-class citizen in _meta. Every tool call propagates trace context. If your MCP servers and clients implement OTel — and most will by default in the new SDKs — you get distributed tracing across the entire agent graph for free."

**Duration: 3 minutes.**

---

## Slide 12 — What's New in MCP 2026

Keep this fast — 2 minutes. These are supplementary to the main stateless story.

**Stateless Core:** Already covered in depth.

**Tasks Extension:**
> "For Kubernetes ops specifically this is important. Imagine an agent triggering a deployment rollout. That's not a 200ms tool call — it could take minutes. The Tasks extension gives you async polling: tasks/get to check status, tasks/update for progress. This is how agents handle long-running Kubernetes operations."

**MCP Apps:**
> "Server-rendered UIs through MCP. An MCP server can now push a UI component back to the client. Think Grafana dashboards surfaced directly inside your agent conversation, without leaving the tool. Early but interesting."

**Authorization Hardening:**
> "CIMD replaces Dynamic Client Registration. If you're integrating MCP with Keycloak or your OIDC provider, this is the path forward. DCR still works for 12 months, so you have time to migrate."

**Extensions Framework:**
> "The community can now extend MCP without touching the core spec, using reverse-DNS identifiers like io.modelcontextprotocol/tasks. This is how they want to avoid spec bloat going forward."

**Deprecations:**
> "Roots, Sampling, and Logging are deprecated. If you're using those features, move to tool parameters and OpenTelemetry. The 2026 SDKs will start showing deprecation warnings."

**Duration: 2 minutes.**

---

## Slide 13 — Live Demo

Refer to `mcp_demo.md` for the full script with exact commands. Summary below.

### PRE-DEMO CHECKLIST (30 min before going on stage)
- [ ] Minikube running: `minikube status`
- [ ] MCP pods running (4 pods): `kubectl get pods -l app=mcp-stateful-server && kubectl get pods -l app=mcp-stateless-server`
- [ ] Test the curl commands at least once
- [ ] Font size large (min 18pt), notifications off, Slack/email closed

---

### DEMO FLOW (5.5 minutes)

**Part 1 — Stateful MCP: Watch It Break (3 min)**

Show 2+2 replicas, both services with sessionAffinity: None.
- Beat 1.2: `tools/list` without `initialize` → rejected
- Beat 1.3: `initialize` → get `Mcp-Session-Id` header back
- Beat 1.4: `tools/list` with session ID → ~50% fail (wrong pod)

Key line:
> "Two replicas and it's already broken. Imagine this with HPA scaling to 20 pods."

**Part 2 — Stateless MCP: Watch It Work (2 min)**

- Beat 2.1: `tools/list` directly → works, no session header in response
- Beat 2.2: Repeat 3-4 times → 100% success

Key line:
> "One HTTP POST. No handshake. No session."

**Part 3 — Punchline (30 sec)**

> "Same image. Same tools. One flag. The protocol finally caught up."

---

### ANTICIPATED Q&A — "Where's the auth?"

If someone asks about authentication during the demo:

> "Two layers. The MCP server uses a Kubernetes ServiceAccount for API access — standard RBAC, defined in the YAML. For client-to-server auth, the service is ClusterIP, internal only. In production, you'd put agentgateway in front — it handles auth, rate limiting, and routing at the edge, same way Envoy handles it for HTTP. The 2026 spec also added CIMD for OAuth/OIDC at the protocol level."

---

### FALLBACK PLAN
- **Curl pod name collision:** `kubectl delete pod mcp-test --force --grace-period=0`
- **Stateful doesn't reject without session:** Skip to Beat 1.4 (session ID fails on wrong pod)
- **Cluster dead:** show screenshot from rehearsal — it's a meetup, not production

---

## Slide 14 — References & Links

Point the audience to the demo repo first — that's where everything lives.

> "All the files I showed today — the MCP server YAMLs, the demo script with exact curl commands — are at github.com/iamgini/mcp-stateless-demo. Clone it, run it on minikube, try it yourself."

For the MCP spec:
> "The 2026-07-28 release blog is the authoritative source for everything I covered about the stateless transition. modelcontextprotocol.io is the spec home. The AAIF is at lfaidata.foundation."

For the ecosystem:
> "kagent.dev if you want to run AI agents as Kubernetes CRDs. agentgateway for MCP traffic governance. Grafana MCP at github.com/grafana/mcp-grafana."

**Keep this slide visible — people will want to photograph it.**

---

## Slide 15 — Questions & Feedback

Closing line before going to Q&A:
> "MCP went stateless in July 2026. Your Kubernetes cluster is already ready for it. The question is whether you'll be ready when AI agents start knocking on your services."

Then:
> "Happy to take questions."

**Keep this slide up throughout Q&A.**

After the talk, point people to:
- `github.com/iamgini/mcp-stateless-demo`
- `techbeatly.com` for articles and follow-up content
- `linkedin.com/in/gineesh`

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
| 13 | Live Demo | 6 min |
| 14 | References | 1 min |
| 15 | Q&A | 5 min |
| **Total** | | **~43 min** |
