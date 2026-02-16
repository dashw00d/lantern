# 06 - Lantern: Central Hub Spec

> What Lantern should do as the single source of truth for all tools and projects.

---

## Core Idea

Lantern is the answer to "what do I have running, where is it, how do I start it, and what can it do?" Every project registers with Lantern. Lantern knows their directory, port, status, docs, and how to deploy them. Other systems (Loom, agents, humans) query Lantern instead of maintaining their own copies of this information.

---

## 1. Project Registry

The foundation. Every project/tool gets an entry.

### Data Model

```
project:
  id:           "ghostgraph"                          # unique slug
  name:         "GhostGraph"                          # display name
  description:  "Distributed web extraction system"   # one paragraph
  kind:         "service"                             # service | project | capability
  directory:    "/home/ryan/sites/GhostGraph"         # absolute path on disk
  port:         null                                  # port it runs on (null if not a service)
  base_url:     "https://ghost.paidfor.net"           # where to reach it
  health_endpoint: "/health"                          # path to hit for liveness
  repo_url:     "github.com/user/ghostgraph"          # optional remote
  tags:         ["data", "scraping", "api"]
  enabled:      true
  registered_at: "2026-02-15T..."
```

### API

```
GET    /api/projects                     # list all projects
GET    /api/projects/{id}                # full detail for one project
POST   /api/projects                     # register a new project
PATCH  /api/projects/{id}                # update fields
DELETE /api/projects/{id}                # deregister
```

### What "Register" Means

A project tells Lantern about itself. This can happen:
- **Manually** via API call or CLI (`lantern register --dir /home/ryan/sites/GhostGraph`)
- **Auto-discovery** — Lantern scans known directories for projects with a `lantern.yaml` manifest
- **Self-registration** — a project calls `POST /api/projects` on startup

A minimal `lantern.yaml` in a project root:
```yaml
id: ghostgraph
name: GhostGraph
kind: service
description: Distributed web extraction system
port: null
base_url: https://ghost.paidfor.net
health_endpoint: /health
tags: [data, scraping, api]
```

Lantern reads this and stores the entry. The directory is inferred from where the file was found.

---

## 2. Deploy Commands

Each project can define how to start, stop, and restart itself. Lantern stores these and can execute them.

### Data Model

```
project.deploy:
  install:  "cd {dir} && ./install.sh"
  start:    "systemctl --user start ghostgraph"
  stop:     "systemctl --user stop ghostgraph"
  restart:  "systemctl --user restart ghostgraph"
  logs:     "journalctl --user -u ghostgraph -f"
  status:   "systemctl --user is-active ghostgraph"
  env_file: ".env"                                    # relative to directory
```

Or defined in `lantern.yaml`:
```yaml
deploy:
  start: "systemctl --user start ghostgraph"
  stop: "systemctl --user stop ghostgraph"
  restart: "systemctl --user restart ghostgraph"
  logs: "journalctl --user -u ghostgraph --no-pager -n 50"
  status: "systemctl --user is-active ghostgraph"
```

### API

```
POST /api/projects/{id}/start            # run the start command
POST /api/projects/{id}/stop             # run the stop command
POST /api/projects/{id}/restart          # run the restart command
GET  /api/projects/{id}/logs             # tail recent logs
GET  /api/projects/{id}/status           # run status command, return result
```

These are thin wrappers — Lantern executes the configured shell command and returns the output. No orchestration logic, just "run the thing the project said to run."

### Current Ecosystem Deploy Commands

For reference, here's what exists today:

| Project | Start | Stop | Managed By |
|---------|-------|------|------------|
| Loom API | `systemctl --user start loom` | `systemctl --user stop loom` | systemd user service |
| Loom Scheduler | `systemctl --user start loom-scheduler` | `systemctl --user stop loom-scheduler` | systemd user service |
| Social Autopilot | `systemctl --user start social-autopilot` | `systemctl --user stop social-autopilot` | systemd user service |
| GhostGraph | remote (deployed separately) | remote | deployed on server |
| Orchestrator V5 | `cd dir && npm run start` | kill process | manual |
| Ollama | `systemctl start ollama` | `systemctl stop ollama` | system service |
| ChromaDB | `chroma run --path data/chromadb` | kill process | manual |
| Skill Starter | `systemctl --user start skill-starter` | `systemctl --user stop skill-starter` | systemd user service |

---

## 3. Documentation Serving

Lantern knows where a project's docs are and serves them via API. This is what Loom's hydrator will fetch from instead of reading local files.

### Data Model

```
project.docs:
  - path: "README.md"                    # relative to project directory
    kind: "readme"
  - path: "docs/API.md"
    kind: "api"
  - path: "BRAIN.md"
    kind: "context"                      # agent memory / project context
  - path: "SKILL.md"
    kind: "skill"
  - path: "CLAUDE.md"
    kind: "instructions"
```

Or in `lantern.yaml`:
```yaml
docs:
  - README.md
  - docs/API.md
  - BRAIN.md
```

Lantern resolves these relative to the project's `directory`.

### API

```
GET /api/projects/{id}/docs              # list available docs with metadata
GET /api/projects/{id}/docs/{filename}   # serve raw doc content
```

**List response:**
```json
{
  "project_id": "ghostgraph",
  "docs": [
    {"path": "README.md", "kind": "readme", "size_bytes": 4200, "updated_at": "2026-02-14T..."},
    {"path": "docs/API.md", "kind": "api", "size_bytes": 12800, "updated_at": "2026-02-10T..."}
  ]
}
```

**Content response:**
```json
{
  "path": "docs/API.md",
  "content": "# API Reference\n\n## POST /api/jobs/\n...",
  "size_bytes": 12800,
  "updated_at": "2026-02-10T..."
}
```

### Current Docs Map

| Project | Docs |
|---------|------|
| GhostGraph | `README.md`, `docs/API.md`, OpenClaw `BRAIN.md` |
| Social Autopilot | `SKILL.md`, `README.md` |
| OpenClaw | `OPENCLAW_FEATURES.md`, `AGENTS.md`, `TOOLS.md` |
| Orchestrator V5 | `docs/ORCHESTRATION-V5.md` |
| Skill Starter | `README.md` |
| Loom | `README.md`, `CLAUDE.md`, `SKILL.md`, `architecture/*.md` |

---

## 4. API Endpoint Discovery

For services that expose HTTP APIs, Lantern stores their endpoint catalog. Agents and humans can look up "what can GhostGraph do?" without reading source code.

### Data Model

```
project.endpoints:
  - method: "POST"
    path: "/api/jobs/"
    description: "Create a new crawl job"
    category: "Jobs"
    risk: "medium"
    body_hint: '{"job_type": "string", "start_url": "string"}'
  - method: "GET"
    path: "/api/jobs/"
    description: "List all jobs"
    category: "Jobs"
    params: "job_type, status, limit, offset"
```

### API

```
GET /api/projects/{id}/endpoints                   # list all endpoints
GET /api/projects/{id}/endpoints?category=Jobs      # filter by category
```

Response:
```json
{
  "project_id": "ghostgraph",
  "base_url": "https://ghost.paidfor.net",
  "endpoints": [
    {
      "method": "POST",
      "path": "/api/jobs/",
      "description": "Create a new crawl job",
      "category": "Jobs",
      "risk": "medium",
      "body_hint": "{\"job_type\": \"string\"}"
    }
  ]
}
```

This replaces the `endpoints` field in Loom's `tools.yaml`. Projects maintain their own endpoint list in `lantern.yaml`, and Lantern serves it.

---

## 5. Health Monitoring

Lantern periodically pings each service's health endpoint and tracks status.

### Behavior

- Check interval: configurable per project (default: 60 seconds)
- Timeout: 5 seconds
- Status values: `healthy`, `unhealthy`, `unknown`, `disabled`
- Store last N check results for history
- A service that hasn't been checked yet is `unknown`

### API

```
GET /api/health                          # all projects with current health status
GET /api/projects/{id}/health            # health detail for one project
POST /api/projects/{id}/health/check     # trigger an immediate health check
```

**Aggregate response:**
```json
{
  "projects": [
    {"id": "ghostgraph", "status": "healthy", "latency_ms": 45, "checked_at": "2026-02-15T..."},
    {"id": "social-autopilot", "status": "healthy", "latency_ms": 12, "checked_at": "2026-02-15T..."},
    {"id": "ollama", "status": "unhealthy", "error": "connection refused", "checked_at": "2026-02-15T..."}
  ]
}
```

### Current Ecosystem Health Endpoints

| Project | Health Endpoint | Method |
|---------|----------------|--------|
| Loom | `/health` | GET |
| GhostGraph | `/health` | GET |
| Social Autopilot | `/health` | GET |
| Orchestrator V5 | `/api/help` | GET |
| Skill Starter | `/health` | GET |
| Ollama | `/` (root) | GET |
| ChromaDB | `/api/v1/heartbeat` | GET |

---

## 6. Port Registry

Lantern tracks which ports are assigned to which projects. Prevents collisions and makes it easy to find where something is running.

### Data Model

Stored as part of the project entry (`port` field). Lantern enforces uniqueness — no two active projects on the same port.

### API

```
GET /api/ports                           # map of port -> project
```

Response:
```json
{
  "ports": {
    "8410": {"project": "loom", "status": "healthy"},
    "8420": {"project": "social-autopilot", "status": "healthy"},
    "4173": {"project": "orchestrator-v5", "status": "unknown"},
    "8100": {"project": "chromadb", "status": "healthy"},
    "11434": {"project": "ollama", "status": "healthy"},
    "18789": {"project": "openclaw", "status": "unknown"},
    "8400": {"project": "skill-starter", "status": "unknown"}
  }
}
```

When a new project registers with a port that's taken, Lantern warns but doesn't block (the port might be available if the other project is stopped).

---

## 7. Routing Metadata (for Loom)

Loom needs `triggers` and `agents` to route prompts to the right tool. These stay in the project registry as optional fields that Loom consumes.

### Data Model

```yaml
# In lantern.yaml (optional, only needed if project is used by Loom)
routing:
  triggers:
    - scrape
    - crawl
    - extract data
    - ghostgraph
  risk: medium
  requires_confirmation: false
  max_concurrent: 1
  agents:
    - agent_id: main
      dispatch: cli
      timeout_seconds: 600
```

### API

Served as part of `GET /api/projects/{id}`. Loom reads these fields when building its routing registry. Projects that don't have routing config are invisible to Loom but still visible in Lantern.

---

## 8. Dependency Graph

Track which projects depend on which. Useful for startup ordering and understanding blast radius.

### Data Model

```yaml
# In lantern.yaml
depends_on:
  - ollama        # needs embeddings
  - chromadb      # needs vector storage
```

### API

```
GET /api/dependencies                    # full dependency graph
GET /api/projects/{id}/dependencies      # what this project needs
GET /api/projects/{id}/dependents        # what depends on this project
```

### Current Dependencies

```
loom → openclaw, chromadb, ollama
chromadb → ollama
social-autopilot → openclaw
orchestrator-v5 → openclaw
skill-starter → chromadb, ollama
```

This helps with questions like "if I stop Ollama, what breaks?" (Answer: ChromaDB embeddings, Loom hydration, Skill Starter).

---

## Complete API Summary

```
# Projects
GET    /api/projects                              List all projects
GET    /api/projects/{id}                         Full project detail
POST   /api/projects                              Register a project
PATCH  /api/projects/{id}                         Update a project
DELETE /api/projects/{id}                          Deregister a project

# Deploy
POST   /api/projects/{id}/start                   Start the service
POST   /api/projects/{id}/stop                    Stop the service
POST   /api/projects/{id}/restart                 Restart the service
GET    /api/projects/{id}/logs                    Tail recent logs
GET    /api/projects/{id}/status                  Check if running

# Docs
GET    /api/projects/{id}/docs                    List available docs
GET    /api/projects/{id}/docs/{filename}         Serve doc content

# Endpoints
GET    /api/projects/{id}/endpoints               List API endpoints

# Health
GET    /api/health                                All project health
GET    /api/projects/{id}/health                  Health detail
POST   /api/projects/{id}/health/check            Force health check

# Infrastructure
GET    /api/ports                                 Port assignment map
GET    /api/dependencies                          Full dependency graph
```

**17 endpoints total.** Clean REST around one resource type (projects) with sub-resources for docs, endpoints, health, and deploy actions.

---

## `lantern.yaml` Full Example

This is what a project puts in its root directory to register with Lantern:

```yaml
id: ghostgraph
name: GhostGraph
kind: service
description: >
  Distributed web extraction system. Creates crawl jobs that deploy
  ephemeral workers to scrape and extract structured data from websites.

port: null
base_url: https://ghost.paidfor.net
health_endpoint: /health

tags: [data, scraping, api, infrastructure]

deploy:
  start: "systemctl --user start ghostgraph"
  stop: "systemctl --user stop ghostgraph"
  restart: "systemctl --user restart ghostgraph"
  logs: "journalctl --user -u ghostgraph --no-pager -n 100"
  status: "systemctl --user is-active ghostgraph"

docs:
  - README.md
  - docs/API.md

endpoints:
  - { method: POST, path: "/api/jobs/", description: "Create crawl job", category: Jobs, risk: medium }
  - { method: GET, path: "/api/jobs/", description: "List jobs", category: Jobs }
  - { method: GET, path: "/api/jobs/{id}", description: "Get job detail", category: Jobs }
  - { method: POST, path: "/api/fleet/deploy", description: "Deploy workers", category: Fleet, risk: critical }
  - { method: DELETE, path: "/api/fleet/destroy", description: "Destroy workers", category: Fleet, risk: critical }

depends_on:
  - ollama

# Loom routing (optional)
routing:
  triggers: [scrape, crawl, extract data, ghostgraph, entities, fleet, workers, venues]
  risk: medium
  requires_confirmation: false
  agents:
    - agent_id: main
      dispatch: cli
      timeout_seconds: 600
```

---

## What Lantern Does NOT Do

- **No task orchestration** — that's Loom
- **No agent dispatch** — that's Loom via OpenClaw
- **No prompt routing** — that's Loom's categorize/select_tools
- **No state management** — no audit logs, no checkpoints, no messaging
- **No scheduling** — Loom handles scheduled tasks
- **No UI beyond its own dashboard** — each project can have its own UI

Lantern answers "what exists?" Everything else is someone else's job.
