# Lantern

Local development environment manager — the hub that discovers, manages, and connects all your tools.

## What It Does

- **Project Discovery** — Scans `~/tools/` and `~/sites/` for projects, reads their `lantern.yaml` configs
- **Process Management** — Start/stop/restart projects with allocated ports from a managed range (41000-42000)
- **Health Monitoring** — Periodic health checks on all registered services with history tracking
- **Reverse Proxy** — Routes `*.glow` domains to the right service via Caddy integration
- **MCP Server** — Exposes tools, resources, and prompts via the Model Context Protocol at `/mcp`
- **API Discovery** — Auto-discovers OpenAPI specs and endpoints for registered tools
- **Doc Serving** — Serves project documentation via `/api/projects/:name/docs`
- **Templates & Profiles** — Reusable project templates and switchable configuration profiles
- **Service Management** — Controls infrastructure services (Redis, Postgres, Mailpit)

## Quick Start

```bash
# Development (from source)
bash ~/tools/Lantern/dev-up.sh

# Or manually
cd ~/tools/Lantern/daemon
mix phx.server
```

Runs on **port 4777** by default (`LANTERN_PORT` env var to override).

## API

Base URL: `http://127.0.0.1:4777`

| Endpoint | Description |
|----------|-------------|
| `GET /` | API discovery — lists all endpoints |
| `GET /api/projects` | List all registered projects |
| `GET /api/projects/:name` | Project details |
| `POST /api/projects/:name/activate` | Start a project |
| `POST /api/projects/:name/deactivate` | Stop a project |
| `POST /api/projects/:name/restart` | Restart a project |
| `GET /api/projects/:name/logs` | Project logs |
| `GET /api/projects/:name/discovery` | Auto-discovered project metadata |
| `GET /api/projects/:name/endpoints` | Project API endpoints |
| `GET /api/projects/:name/docs` | Project documentation index |
| `GET /api/tools` | List all tools across projects |
| `GET /api/health` | Health status for all monitored services |
| `GET /api/services` | List infrastructure services |
| `GET /api/ports` | Port allocation map |
| `GET /api/dependencies` | Cross-project dependency graph |
| `GET /api/system/health` | Lantern system health |
| `GET /api/system/settings` | Current settings |
| `GET /api/templates` | Project templates |
| `GET /api/profiles` | Configuration profiles |

MCP endpoint: `POST /mcp` (Streamable HTTP transport)

## Configuration

Environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `LANTERN_PORT` | `4777` | HTTP port |
| `LANTERN_WORKSPACES` | `~/sites:~/tools` | Colon-separated scan roots |
| `LANTERN_TLD` | `.glow` | Local TLD for reverse proxy |
| `LANTERN_STATE_DIR` | `~/.config/lantern` | Persistent state directory |
| `LANTERN_PORT_RANGE_START` | `41000` | Start of managed port range |
| `LANTERN_PORT_RANGE_END` | `42000` | End of managed port range |

## Project Registration

Projects are discovered by scanning workspace roots for `lantern.yaml` files. See any tool in `~/tools/` for examples (e.g., `~/tools/browser/lantern.yaml`).

Key `lantern.yaml` fields:
- `id` — Unique identifier
- `name` — Display name
- `kind` — `service`, `library`, etc.
- `type` — `proxy` (Caddy-routed) or `static`
- `domain` — Local domain (e.g., `browser.glow`)
- `run.cmd` — Start command (`${PORT}` is substituted)
- `health_endpoint` — Path for health checks
- `endpoints` — API endpoint documentation
- `routing.triggers` — Keywords for intent-based routing
- `depends_on` — Service dependencies

## Architecture

Phoenix 1.8 app (Elixir/OTP) with:
- **Bandit** HTTP server
- **Finch** HTTP client (for health checks, API discovery)
- **Hermes MCP** server (Model Context Protocol)
- **Caddy** reverse proxy integration (`.glow` domains)
- **PubSub** for real-time WebSocket updates

## Development

```bash
mix deps.get      # Install dependencies
mix test           # Run tests
mix phx.server     # Start dev server (port 4777)
```

Dev mode enables:
- Code reloading
- LiveDashboard at `/dev/dashboard`
- Debug error pages
