# Gemini Slides Prompt — MCP Goes Stateless

Copy everything below into Gemini and ask it to generate/refine your Google Slides.

---

## PROMPT START

Create a 15-slide presentation in Google Slides for a CNCF meetup talk. The talk is technical but accessible — the audience is Kubernetes platform engineers and SREs who may not know MCP yet.

### Talk Details
- **Title:** MCP Goes Stateless: How the AI Agent Protocol Finally Became Cloud Native
- **Speaker:** Gineesh Madapparambath
- **Event:** Cloud Native and HUG Singapore August Meetup, 02 Aug 2026
- **Duration:** ~40 minutes + Q&A
- **Speaker bio:** AI, Automation and Containerization Learner. Author of "Ansible for Real Life Automation". Co-author of "The Kubernetes Bible – Second Edition". Editor at techbeatly.com. Videos at youtube.com/techbeatly. Architect at Red Hat, Singapore. Pronouns: He/Him.
- **LinkedIn:** linkedin.com/in/gineesh
- **Website:** gineesh.com

### Design Guidelines
- Professional, clean, modern tech conference style
- Use a dark or neutral background for the title slide (code-themed background works well)
- Content slides: white/light background with clear hierarchy
- Accent colors: use blues, greens, and oranges for emphasis and categorization
- No clip art. Minimal icons only where they add clarity.
- Large readable fonts — this will be projected in a conference room
- The demo slide (13) and Q&A slide (14) can use illustration-style visuals
- References slide (15) should have a light blue background for visibility/photographing

### Slide-by-Slide Content

---

#### Slide 1 — Title
- **Title:** MCP Goes Stateless: How the AI Agent Protocol Finally Became Cloud Native
- **Subtitle:** Gineesh Madapparambath
- **Footer:** Cloud Native and HUG Singapore August Meetup, 02 Aug 2026
- Dark background with subtle code/terminal imagery

---

#### Slide 2 — About the Speaker
- Show a terminal-style "whoami" layout on the left:
  ```
  $ whoami
  > Gineesh Madapparambath

  $ cat ~/about.txt
  > AI, Automation and Containerization Learner
  > Author of "Ansible for Real Life Automation"
  > Co-author of "The Kubernetes Bible – Second Edition"
  > Editor at "techbeatly.com"
  > Videos: "youtube.com/techbeatly"

  $ echo $INTERESTS
  ansible, openshift, kubernetes, IaC, "open source"
  Write at techbeatly.com, Red Hat Blog and The New Stack
  ```
- Right side: LinkedIn profile card showing photo, title "Architect at Red Hat", location Singapore, website gineesh.com

---

#### Slide 3 — What we'll discuss today
- Simple bullet list, no icons needed:
  - The Tool Integration Problem
  - What is MCP
  - API vs MCP
  - MCP Architecture and How It Works
  - Stateful MCP: The Kubernetes Problem
  - Stateless MCP: The 2026 Fix
  - Stateful vs Stateless Tradeoffs
  - MCP in the CNCF Ecosystem
  - What's New in MCP 2026
  - Live Demo
  - Q&A

---

#### Slide 4 — The Tool Integration Problem
- Show 5 boxes in a row, each with a framework name and its tool format:
  - **LangGraph** — LangChain tools directly
  - **CrewAI** — Own tool format
  - **AutoGen** — Python function wrappers
  - **OpenAI** — Function calling spec
  - **Anthropic** — Tool use spec
- Below the boxes, highlighted text: "Same Kubernetes API - 5 different tool formats - no reuse, no standards"
- Bottom callout box: "MCP is ending this fragmentation - all major frameworks adopting MCP in 2026"
- Source footnote: "AI Agent Frameworks Comparison 2026 - fungies.io"

---

#### Slide 5 — What is MCP?
- Subtitle: "Model Context Protocol - open standard connecting AI agents to tools and data"
- **Timeline** with 3 colored bars:
  - Nov 2024 (blue): Launched by Anthropic
  - Dec 2025 (purple): Donated to Linux Foundation AAIF
  - Jul 2026 (green): Spec 2026-07-28 - goes stateless
- **Three primitives** in outlined boxes:
  - Tools — Functions agents can call
  - Resources — Data agents can read
  - Prompts — Reusable templates
- **Scale numbers** in 4 highlighted boxes:
  - 20,000+ MCP servers indexed
  - 400M+ monthly SDK downloads
  - 1B+ TypeScript + Python downloads
  - 247+ AAIF member orgs
- Footer: "Backed by: Anthropic, OpenAI, Google, Microsoft, AWS, Block, Cloudflare, Bloomberg"

---

#### Slide 6 — API vs MCP
- Comparison table with columns: [Category] | REST API | MCP
  - **Designed for:** Human developers writing code | AI agents discovering tools dynamically
  - **Discovery:** Read docs, write custom integration | Auto-discovered via tools/list - zero code
  - **Schema:** OpenAPI, manually maintained | Self-describing, dynamic
  - **Versioning:** Breaking changes = client updates | Version negotiated per request
  - **Auth:** Per-API credentials per integration | Single gateway, scoped per tool
- MCP column highlighted in light purple
- Bottom callout: "MCP does not replace REST APIs - most MCP servers wrap existing REST APIs - MCP adds the discovery layer agents need"

---

#### Slide 7 — MCP Architecture
- Three-column layout:
  - **MCP Client** (blue border): AI Agent, Claude / Cursor, kagent, VS Code
  - Center connector: "JSON-RPC Streamable HTTP"
  - **MCP Server** (purple border): Exposes tools, resources, prompts / tools/list - discovery / tools/call - execution / Structured results
  - **New in 2026** (green border): Mcp-Method header (route without body inspection) / Mcp-Name header / ttlMs + cacheScope (HTTP-style caching) / W3C Trace Context in _meta

---

#### Slide 8 — Stateful MCP - The Kubernetes Problem
- Subtitle: "How MCP worked before spec 2026-07-28:"
- Flow diagram: Client sends initialize → Server creates Mcp-Session-Id → All requests pinned to that instance
- 4 numbered problem cards (orange numbered circles):
  1. **Load Balancing** — Needed sessionAffinity: ClientIP on every Kubernetes Service
  2. **HPA** — New pods added but sessions cannot migrate - sessions break
  3. **Rolling Updates** — Pod replaced = session lost mid-task - agent gets an error
  4. **Session Store** — Must run Redis alongside every MCP server deployment
- Bottom callout (dark red): "Bottom line: MCP servers had to be treated like stateful databases - not cloud native microservices"
- Footnote: "Spec reference: blog.modelcontextprotocol.io/posts/2026-07-28"

---

#### Slide 9 — Stateless MCP - The 2026 Fix
- Subtitle: "Spec 2026-07-28 · Released July 28 2026 · Largest revision since launch · Six SEPs"
- 4 change boxes in 2x2 grid:
  - **initialize handshake removed** (green left border) — SEP-2575 - no more session setup round-trip
  - **Mcp-Session-Id header removed** (green left border) — SEP-2567 - no session pinning
  - **_meta carries everything** (blue left border) — Protocol version + client info on every request
  - **server/discover RPC** (purple left border) — Optional for clients - mandatory for servers to implement
- Before/After comparison:
  - Before (red X): sessionAffinity: ClientIP / Redis session store / HPA breaks sessions / Rolling update drops connections
  - After (green checkmark): No session affinity needed / No session store needed / HPA works transparently / Safe rolling updates
- Bottom callout (green): "MCP servers now deploy like any other Kubernetes microservice"

---

#### Slide 10 — Stateful vs Stateless - Honest Trade-offs
- Comparison table: [Dimension] | Stateful (old) | Stateless (2026)
  - **Load balancing:** Sticky sessions only | **Any algorithm** (green)
  - **HPA scaling:** Breaks active sessions | **Transparent** (green)
  - **Rolling updates:** Drops connections | **Safe** (green)
  - **Session store:** Redis required | **Not needed** (green)
  - **Long-running ops:** Natural over session (green) | Needs Tasks extension
  - **Streaming:** Native SSE (green) | Needs subscriptions/listen
  - **Migration:** — | Breaking changes - client updates needed (orange)
- Stateless column header highlighted in blue
- Bottom verdict: "Verdict: Stateless wins for Kubernetes - migration effort is real but one-time"

---

#### Slide 11 — MCP in the CNCF Ecosystem
- 4 project cards in 2x2 grid:
  - **kagent** (purple, badge: "CNCF Sandbox"):
    - RemoteMCPServer CRD - MCP servers as K8s objects
    - 21 Kubernetes tools via STREAMABLE_HTTP
    - kubectl get remotemcpservers -n kagent
  - **Grafana MCP** (orange, badge: "Official"):
    - github.com/grafana/mcp-grafana
    - 3k+ GitHub stars - Grafana Labs maintained
    - Query dashboards, metrics, alerts via MCP
  - **agentgateway** (purple, badge: "AAIF"):
    - Governs MCP traffic - auth, filtering, routing
    - Envoy - but for MCP
    - Per-tool policy at the edge
  - **OpenTelemetry** (green, badge: "CNCF Graduated"):
    - W3C Trace Context in _meta (new in 2026 spec)
    - Distributed tracing across SDKs and gateways
    - Recommended for MCP server observability

---

#### Slide 12 — What's New in MCP 2026
- 6 feature cards in 2x3 grid, each with a colored top border:
  - **Stateless Core** (green): Spec 2026-07-28 - largest revision since launch. Removes initialize handshake and Mcp-Session-Id.
  - **Tasks Extension** (blue): io.modelcontextprotocol/tasks - async ops via tasks/get and tasks/update. Trigger K8s rollout, poll for completion.
  - **MCP Apps** (purple): Server-rendered UIs through MCP. Grafana dashboards inside agent conversations.
  - **Authorization Hardening** (orange): CIMD replaces Dynamic Client Registration. Aligns with OIDC and Keycloak. DCR deprecated - 12-month window.
  - **Extensions Framework** (blue): Reverse-DNS identifiers. Community extends protocol without touching the core spec.
  - **Deprecations** (gray): Roots, Sampling, Logging deprecated. Use tool parameters and OpenTelemetry instead.

---

#### Slide 13 — Let us see them in Action
- Large heading: "Let us see them in Action"
- Subtext: github.com/iamgini/mcp-stateless-demo
- Light blue/lavender background
- Illustration: people collaborating around a laptop (friendly, inclusive)

---

#### Slide 14 — References & Links
- Light blue background for easy photographing
- 4 reference cards in 2x2 grid:
  - **MCP:**
    - MCP Spec: modelcontextprotocol.io
    - MCP 2026-07-28: blog.modelcontextprotocol.io/posts/2026-07-28
    - AAIF: lfaidata.foundation/projects/aaif
  - **kagent:**
    - Docs: kagent.dev
    - CNCF: cncf.io/projects/kagent
  - **Ecosystem:**
    - agentregistry: github.com/agentregistry-dev/agentregistry
    - agentgateway: github.com/agentgateway/agentgateway
    - Grafana MCP: github.com/grafana/mcp-grafana
  - **Demo & Speaker:**
    - Demo: github.com/iamgini/mcp-stateless-demo
    - techbeatly.com
    - gineesh.com

---

#### Slide 15 — Questions & Feedback
- Large heading: "Questions & Feedback"
- Lavender/purple background
- Illustration: diverse group of people with thought bubbles containing question marks

---

### Key facts for accuracy (do not change these)
- MCP spec 2026-07-28 released July 28, 2026
- SEP-2575 removed the initialize handshake
- SEP-2567 removed the Mcp-Session-Id header
- SEP-2243 added Mcp-Method and Mcp-Name headers
- SEP-2549 added ttlMs + cacheScope
- kagent is a CNCF Sandbox project
- agentgateway is an AAIF project
- OpenTelemetry is CNCF Graduated
- MCP was launched by Anthropic in Nov 2024, donated to Linux Foundation AAIF in Dec 2025
- CIMD replaces DCR (Dynamic Client Registration) for OAuth/OIDC
- Roots, Sampling, and Logging are deprecated in the 2026 spec

## PROMPT END
