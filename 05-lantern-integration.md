# 05 - Lantern Integration

> Reference for migrating Loom's tool/project registry to Lantern as a central hub.

---

## The Split

Today Loom owns everything: tool definitions, docs, routing, execution, state. The idea is to split responsibilities:

| Concern | Today (Loom) | Future (Lantern) |
|---------|-------------|-------------------|
| "What tools exist?" | `tools.yaml` | Lantern API |
| "What docs does a tool have?" | `docs_paths` in YAML | Lantern serves docs |
| "Is a service alive?" | `health_endpoint` (defined but unused) | Lantern runs health checks |
| "What endpoints does a service expose?" | `endpoints` in YAML | Lantern API |
| "Route this prompt to a tool" | Loom categorize + select_tools | Loom (unchanged) |
| "Execute tasks against tools" | Loom graph | Loom (unchanged) |

Lantern becomes the source of truth for **what exists**. Loom stays the brain for **what to do**.

---

## How the Registry Works Today

### Data Source

Single YAML file: `loom/registry/tools.yaml`

Each entry defines a tool with identity, routing triggers, documentation paths, service endpoints, agent bindings, and risk metadata. Full schema in `loom/registry/schema.py`.

### Loading

`loom/registry/loader.py` — `load_registry()` reads YAML once, caches globally in `_registry: dict[str, RegistryEntry]`. Only enabled tools are kept.

```
tools.yaml → yaml.safe_load → _parse_entry() per tool → RegistryEntry dataclass → cached dict
```

### Where the Registry is Consumed

1. **Routing** (`categorize_node`) — `registry_summary()` produces a lightweight text blob (id + description per tool) sent to the router agent. `search_registry(query)` scores tools by trigger keyword overlap.

2. **Tool selection** (`select_tools_node`) — Looks up matched tool IDs, collects their `docs_paths`, `agents`, `endpoints`, and determines execution mode.

3. **Hydration** (`hydrate_context_node`) — Reads files from `docs_paths` (local markdown or `chromadb://` URIs), assembles a context bundle capped at 4000 tokens.

4. **API** — `GET /registry` lists tools, `GET /registry/{id}` returns full detail, `POST /registry/test` simulates routing.

5. **Dashboard** — `GET /dashboard/data` includes registry health (name, enabled, kind per tool).

6. **Validation** — `loom registry validate` CLI checks required fields, trigger collisions, path existence.

### Key Fields per Tool

```yaml
ghostgraph:
  name: GhostGraph
  kind: service                    # project | service | capability
  description: >
    Distributed web extraction...
  triggers:                        # keywords for routing
    - scrape
    - crawl
    - extract data
  repo_path: /home/ryan/sites/GhostGraph
  docs_paths:
    - /home/ryan/sites/GhostGraph/README.md
    - /home/ryan/sites/GhostGraph/docs/API.md
  base_url: https://ghost.paidfor.net
  health_endpoint: /health
  endpoints:
    - method: POST
      path: /api/jobs/
      description: Create a new crawl job
      category: Jobs
      risk: medium
      body_hint: '{"job_type": "str", "start_url": "str"}'
  agents:
    - agent_id: main
      dispatch: cli
      timeout_seconds: 600
  risk: medium
  requires_confirmation: false
  max_concurrent: 1
  enabled: true
  tags: [data, scraping, api]
```

---

## What Lantern Needs to Provide

Loom currently reads all of this from one YAML file. To swap in Lantern, its API needs to serve equivalent data. Here's the minimum:

### API 1: List Tools

```
GET /api/tools
```

Returns all registered tools with enough data for routing:

```json
{
  "tools": [
    {
      "id": "ghostgraph",
      "name": "GhostGraph",
      "kind": "service",
      "description": "Distributed web extraction...",
      "triggers": ["scrape", "crawl", "extract data", "venues"],
      "risk": "medium",
      "enabled": true,
      "tags": ["data", "scraping", "api"],
      "base_url": "https://ghost.paidfor.net",
      "health_status": "healthy",
      "requires_confirmation": false,
      "max_concurrent": 1
    }
  ]
}
```

This replaces `load_registry()` + `tools.yaml`.

### API 2: Tool Detail

```
GET /api/tools/{tool_id}
```

Returns the full entry including endpoints and agent bindings:

```json
{
  "id": "ghostgraph",
  "name": "GhostGraph",
  "kind": "service",
  "description": "...",
  "triggers": ["scrape", "crawl"],
  "base_url": "https://ghost.paidfor.net",
  "health_endpoint": "/health",
  "health_status": "healthy",
  "endpoints": [
    {
      "method": "POST",
      "path": "/api/jobs/",
      "description": "Create a new crawl job",
      "category": "Jobs",
      "risk": "medium",
      "body_hint": "{\"job_type\": \"str\"}"
    }
  ],
  "agents": [
    {
      "agent_id": "main",
      "dispatch": "cli",
      "timeout_seconds": 600
    }
  ],
  "docs_paths": ["/home/ryan/sites/GhostGraph/README.md"],
  "repo_path": "/home/ryan/sites/GhostGraph",
  "risk": "medium",
  "tags": ["data", "scraping"]
}
```

This replaces `get_tool(tool_id)`.

### API 3: Tool Docs

```
GET /api/tools/{tool_id}/docs
```

Returns rendered/raw documentation for the tool. This replaces Loom reading files from `docs_paths` during hydration.

```json
{
  "tool_id": "ghostgraph",
  "docs": [
    {
      "path": "README.md",
      "content": "# GhostGraph\n\nDistributed web extraction..."
    },
    {
      "path": "docs/API.md",
      "content": "# API Reference\n\n## POST /api/jobs/..."
    }
  ]
}
```

This is the big one for Loom's hydration system. Today it reads local files. With Lantern, it fetches over HTTP.

### API 4: Health Status (optional, Lantern manages internally)

Lantern runs periodic health checks against each service's `health_endpoint` and exposes aggregate status. Loom doesn't need a separate endpoint for this — it comes back in the tool list (`health_status` field).

---

## What Changes in Loom

### 1. Registry Loader (`loom/registry/loader.py`)

Replace YAML loading with HTTP fetch from Lantern. The cached `_registry` dict stays the same shape — only the data source changes.

```python
# Today
def load_registry(path=None):
    raw = yaml.safe_load(open(path))
    ...

# Future
def load_registry():
    if _registry is not None:
        return _registry
    resp = httpx.get(f"{LANTERN_URL}/api/tools")
    for tool in resp.json()["tools"]:
        entry = _parse_lantern_entry(tool)
        _registry[entry.id] = entry
    return _registry
```

The `RegistryEntry` dataclass doesn't change. We just populate it from JSON instead of YAML.

`reload_registry()` clears cache and re-fetches. Hot reload still works.

### 2. Hydration (`loom/graph/nodes/hydrate.py`)

Today `_load_source()` reads local files. Add a branch for Lantern-served docs:

```python
# Today: reads local files and chromadb:// URIs
# Future: also supports lantern:// URIs or fetches from /api/tools/{id}/docs

def _load_source(source: str, trace_id: str) -> str:
    if source.startswith("chromadb://"):
        return _load_chromadb(source)
    if source.startswith("lantern://"):
        tool_id = source.split("//")[1]
        return _fetch_lantern_docs(tool_id)
    return Path(source).read_text()
```

Or simpler: Lantern's tool detail response includes `docs_paths` that are still local file paths (since Lantern and Loom run on the same machine). Hydration reads them the same way. The only difference is where the paths come from (Lantern API vs YAML).

### 3. Search/Routing (`categorize_node`)

No change needed if Lantern's tool list includes `triggers`. The `search_registry()` function scores against loaded `RegistryEntry` objects — it doesn't care where they came from.

`registry_summary()` and `registry_paths()` also work unchanged since they iterate the in-memory registry dict.

### 4. Validation

`loom registry validate` would change to validate against Lantern's API response instead of the YAML file. Or Lantern handles its own validation on registration.

### 5. API Endpoints

`GET /registry` and `GET /registry/{id}` can either:
- Proxy to Lantern (thin pass-through)
- Continue reading from Loom's cached registry (which was loaded from Lantern)

The second is simpler — no change to the API handlers.

### 6. Config

Add to `loom/config.py`:

```python
LANTERN_URL: str = "http://localhost:XXXX"  # Lantern base URL
LANTERN_TIMEOUT: int = 10                    # Fetch timeout
REGISTRY_SOURCE: str = "lantern"             # "yaml" for local, "lantern" for remote
```

`REGISTRY_SOURCE` lets you switch between local YAML (for development) and Lantern (for production).

---

## What Stays in Loom

These things are execution concerns and stay in Loom, not Lantern:

- **Routing logic** — keyword scoring, agent-based classification, intent inference
- **Context budgeting** — 4000-token cap, 3-tier summarization
- **Agent dispatch** — `send_to_agent()`, session management, timeout/retry
- **Graph execution** — LangGraph nodes, checkpointing, state management
- **Scheduling** — `schedules.yaml`, scheduler runner, overrides
- **Messaging** — inter-agent JSONL messaging
- **Audit trail** — all state files in `state/`

---

## What Moves to Lantern

- **Tool definitions** — identity, description, triggers, tags, risk
- **Service metadata** — base_url, endpoints, health_endpoint
- **Agent bindings** — which agent handles which tool, dispatch config
- **Documentation** — serving doc content (Lantern can store/index docs)
- **Health monitoring** — periodic health checks, status tracking

---

## Migration Path

1. **Phase 1: Lantern serves tool list.** Loom's `load_registry()` fetches from `GET /api/tools` instead of reading `tools.yaml`. Everything else stays the same. `tools.yaml` becomes the seed data that gets imported into Lantern.

2. **Phase 2: Lantern serves docs.** Hydration fetches from `GET /api/tools/{id}/docs` instead of reading local files. Lantern indexes docs and can serve them from any source (git, local files, S3, etc).

3. **Phase 3: Lantern manages health.** Lantern runs health checks against registered services. Tool list responses include `health_status`. Loom uses this for routing decisions (skip unhealthy services).

4. **Phase 4: Other projects connect.** Any tool/project can register itself with Lantern. Loom automatically discovers new tools on next registry reload.
