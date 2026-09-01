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

> "We'll start with the problem that MCP was created to solve, then look at how MCP works architecturally, then spend the most time on the stateful-to-stateless transition because that's the heart of today's talk. We'll look at what it means concretely for Kubernetes — load balancing, HPA, rolling updates. Then we'll see it live in a demo. Total time about 35 minutes."

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

The scale numbers hit hard:
> "19,831 MCP servers. 97 million downloads a month. TypeScript and Python SDKs have each crossed 1 billion total downloads. This is not a niche protocol."

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
> "kagent is how you run AI agents as Kubernetes-native CRDs. The agent's tools are exposed via RemoteMCPServer resources — Kubernetes objects that describe MCP servers running inside your cluster. Show the audience: kubectl get remotemcpservers -n kagent — you'll see kagent-tool-server and kagent-grafana-mcp, both speaking STREAMABLE_HTTP, both ACCEPTED. That's the MCP ecosystem running natively in Kubernetes."

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

### PRE-DEMO CHECKLIST (30 min before going on stage)
- [ ] kind cluster running: `kubectl cluster-info`
- [ ] kagent pods running: `kubectl get pods -n kagent`
- [ ] broken-app deployed and showing ImagePullBackOff: `kubectl get pods -n default`
- [ ] Port-forward running: `kubectl port-forward -n kagent service/kagent-ui 8082:8080`
- [ ] Browser open on kagent dashboard, k8s-troubleshooter agent selected
- [ ] Font size large (min 18pt), notifications off, Slack/email closed

---

### DEMO FLOW

**Beat 1 — Terminal: Show the broken pod**

```bash
kubectl get pods -n default
```
→ broken-app in ImagePullBackOff

Say:
> "Before kagent: I'd be running kubectl describe, kubectl logs, googling the error, patching the YAML. 45 minutes minimum at 3am."

**Beat 2 — Terminal: Show MCP servers as K8s objects**

```bash
kubectl get agent -n kagent
kubectl get remotemcpservers -n kagent
```

Point out:
> "Both MCP servers speak STREAMABLE_HTTP. These are stateless HTTP endpoints since the 2026-07-28 spec. No sticky sessions. No session store. Just plain HTTP behind a Kubernetes Service."

**Beat 3 — Browser dashboard: Ask the agent**

Type:
> "Why is broken-app failing in the default namespace?"

Narrate tool calls as they happen:
> "Calling k8s_get_resources via MCP... calling k8s_get_events via MCP... calling k8s_describe_resource via MCP..."

Expected response: root cause ImagePullBackOff, bad image tag, fix: change to nginx:latest

**Beat 4 — Browser dashboard: Ask agent to fix it**

Type:
> "patch the deployment with nginx:latest"

→ Agent calls k8s_patch_resource → deployment updates → pods go Running.

Closing line:
> "MCP. Stateless. Cloud native. That's it."

---

### FALLBACK PLAN
- **Dashboard 502:** `kubectl port-forward -n kagent service/kagent-ui 8082:8080`
- **Rate limit error:** switch to gpt-4o-mini via `kubectl patch modelconfig openai-model-config -n kagent --type='json' -p='[{"op":"replace","path":"/spec/model","value":"gpt-4o-mini"}]'`
- **Cluster dead:** show screenshot from rehearsal — it's a meetup, not production

---

## Slide 14 — References & Links

Point the audience to the demo repo first — that's where everything lives.

> "All the files I showed today — the Agent CRD, the broken-app deployment, the ModelConfig, the demo script with exact commands — are at github.com/iamgini/agentic-ai-k8s-kagent-demo. Clone it, run it, try it yourself."

For the MCP spec:
> "The 2026-07-28 release blog is the authoritative source for everything I covered about the stateless transition. modelcontextprotocol.io is the spec home. The AAIF is at lfaidata.foundation."

For kagent:
> "kagent.dev for docs, github.com/kagent-dev/kagent for the source. It's a CNCF Sandbox project — contributions welcome."

For the broader ecosystem:
> "agentregistry and agentgateway are both linked there. Grafana MCP is at github.com/grafana/mcp-grafana."

**Keep this slide up during Q&A so people can photograph it.**

---

## Slide 15 — Thank You

Keep this simple. Let the silence work.

Optional closing line before going to Q&A:
> "MCP went stateless in July 2026. Your Kubernetes cluster is already ready for it. The question is whether you'll be ready when AI agents start knocking on your services."

Then:
> "Happy to take questions."

**Keep this slide up throughout Q&A.**

After the talk, point people to:
- `github.com/iamgini/agentic-ai-k8s-kagent-demo`
- `techbeatly.com` for articles and follow-up content
- `linkedin.com/in/gineesh`
- CNCF Slack: `#kagent` channel

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
| 13 | Live Demo | 10 min |
| 14 | References | 1 min |
| 15 | Q&A | 5 min |
| **Total** | | **~47 min** |
