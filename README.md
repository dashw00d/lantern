# Lantern — Infrastructure Layer for Agent Orchestration

You've got 6 MCP servers, a custom agent loop, 15 local services, and a rats nest of configs trying to glue it all together.

The orchestration problem isn't the AI — it's the infrastructure underneath it.

**Lantern manages every local service and exposes one MCP server so your agent can discover every tool, read every API, and chain them together.**

<!-- TODO: Add demo video/gif here -->

## The Problem

You're building agent workflows that need to hit multiple tools in sequence. But every tool is its own island — different port, different config, different MCP server, no shared context. Your agent can write code but can't see what's actually running on your machine.

Meanwhile:

- 15 dev servers on random ports you can't remember
- Daemons crashing silently in the background
- Every tool siloed with no way to chain operations
- A new config file for every MCP integration

## What Lantern Does

Lantern is one daemon that manages your entire local dev environment and gives agents a single point of access to all of it.

| Without Lantern | With Lantern |
|-----------------|-------------|
| `localhost:3000`, `:3001`, `:8080`, `:5173`... | Every service gets `https://myapp.glow` |
| Services crash and you find out 20 minutes later | Managed lifecycle with health checks |
| One MCP config per tool, manually wired | One MCP endpoint — every tool, doc, and API |
| Agent can't discover what's running | Agent lists tools, reads docs, calls APIs |
| Multi-tool operations require glue scripts | One prompt, three tools, zero config |

## One MCP Server. Every Tool.

Lantern isn't just a proxy manager. It's the **runtime + context layer** your agents are missing.

- **Discover** — agent calls `list_tools` and sees every registered tool with descriptions and endpoints
- **Understand** — agent reads docs and API schemas for any tool on demand
- **Use** — agent calls tool APIs directly through Lantern's routing
- **Chain** — multi-tool operations in a single prompt, no glue code

> "Check the browser for the latest deployment status, cross-reference with the database logs, and restart the failing service."
>
> One prompt. Three tools. Zero config.

Use Lantern as:

- a **single MCP server** so agent clients don't need per-tool setup
- the **infrastructure substrate** inside a larger orchestration framework
- a replacement for fragmented per-tool integrations and config sprawl

## Features

- **Manifest-first scanning** — `lantern scan` only imports folders with `lantern.yaml`/`lantern.yml`, keeping the registry clean and explicit
- **Custom local domains with HTTPS** — every project gets `project-name.glow` with a trusted TLS certificate, powered by Caddy
- **Framework-agnostic** — works with any stack that runs a dev server or serves files
- **Managed runtime lifecycle** — start/stop/restart with readiness checks and process teardown
- **Runtime command overrides** — optional `deploy.start/stop/restart/logs/status` can override default runtime behavior
- **Port conflict guardrails** — proxy `run_cmd` must use `${PORT}` unless you configure a fixed `upstream_url`/runtime override
- **Shared services** — Mailpit (email testing), Redis, and PostgreSQL as toggleable services
- **System tray** — start/stop projects and services from the tray without opening anything
- **Desktop GUI** — full dashboard with real-time status, logs, settings, and one-click shutdown
- **CLI** — `lantern scan`, `lantern on myapp`, `lantern status` — everything scriptable
- **MCP-native** — all project/tool context over MCP at `/mcp`, bootstrap clients with `lantern mcp install`
- **Runs as a systemd daemon** — always on, survives reboots, zero overhead when idle
- **Package manager detection** — automatically uses npm, pnpm, yarn, or bun based on your lockfile

## Quick Start

```bash
# Download the .deb from the latest release
sudo bash install.sh lantern_0.1.0_amd64.deb

# Scan your projects
lantern scan

# Activate a project
lantern on myapp

# Visit it
open https://myapp.glow

# Give your agent access
lantern mcp install claude
```

Or build from source:

```bash
git clone https://github.com/dashw00d/lantern.git
cd lantern
bash packaging/build-deb.sh
sudo bash install.sh
```

## How It Works

```
 You                    Lantern                     Your Projects
─────                  ─────────                   ───────────────
lantern on myapp   →   allocates port           →  starts dev server
                       generates Caddy config   →  myapp.glow:443
                       writes DNS resolution    →  resolves .glow TLD
                       ✓ https://myapp.glow ready
```

```
 Agent                  Lantern MCP                 Your Tools
───────                ─────────────               ────────────
list_tools          →  returns all tools         →  browser, db, cache...
get_endpoints       →  returns API schema        →  POST /browse, GET /query...
call_tool_api       →  proxies request           →  tool responds with data
```

Lantern runs a lightweight daemon (Elixir/Phoenix) that orchestrates:

| Component | Role |
|-----------|------|
| **Caddy** | Reverse proxy + automatic local TLS certificates |
| **dnsmasq** | Local `.glow` wildcard DNS resolution to 127.0.0.1 |
| **Process supervisor** | Starts/stops dev servers with automatic port allocation |
| **MCP server** | Single endpoint for agent discovery and tool invocation |

The CLI, desktop app, and system tray are all thin clients that talk to the daemon REST API on port `4777`.

## Runtime Model

Lantern uses one local runtime model for all projects:

- **Default:** `run.cmd` + allocated `${PORT}`
- **Fixed upstream services:** set `upstream_url` (for already-running systemd/tmux/docker services)
- **Optional runtime overrides:** use `deploy.start/stop/...` commands when you need custom control

When a project has a local process command, Lantern verifies it actually binds to the expected port before marking it as running.

## Supported Frameworks

| Framework | Type | How it's served |
|-----------|------|-----------------|
| **Laravel** | PHP | Caddy + php-fpm |
| **Symfony** | PHP | Caddy + php-fpm |
| **Generic PHP** | PHP | Caddy + php-fpm |
| **Next.js** | Node | Reverse proxy to `next dev` |
| **Nuxt** | Node | Reverse proxy to `nuxi dev` |
| **Remix** | Node | Reverse proxy to `remix dev` |
| **Vite** (React, Vue, Svelte, etc.) | Node | Reverse proxy to `vite` |
| **FastAPI** | Python | Reverse proxy to `uvicorn` |
| **Django** | Python | Reverse proxy to `manage.py runserver` |
| **Flask** | Python | Reverse proxy to `flask run` |
| **Static HTML** | Static | Caddy file server |

Need something else? Add a `lantern.yml` or `lantern.yaml` to any project.

## Architecture

```
lantern/
├── daemon/          Elixir/Phoenix API daemon (systemd service)
├── desktop/         Electron + React desktop app with system tray
├── cli/             Bash CLI (lantern command)
└── packaging/       .deb build scripts, systemd unit, icons
```

## Releases

Pre-built `.deb` packages are available on the [Releases](https://github.com/dashw00d/lantern/releases) page.

Each release includes the daemon, CLI, and desktop app in a single package. Currently targeting **Ubuntu/Debian/Linux Mint x86_64**.

### What gets installed

| Path | What |
|------|------|
| `/opt/lantern/daemon/` | Elixir release (daemon) |
| `/opt/lantern/desktop/` | Electron app |
| `/opt/lantern/cli/lantern` | CLI script |
| `/usr/local/bin/lantern` | Symlink to CLI |
| `/etc/systemd/system/lanternd.service` | Systemd unit |
| `/usr/share/applications/lantern.desktop` | App menu entry |

### Uninstall

```bash
sudo systemctl disable --now lanternd
sudo dpkg -r lantern
```

## Build from Source

### Prerequisites

- **Elixir** 1.16+ / **Erlang** 26+ (daemon)
- **Node.js** 20+ and **npm** (desktop app)
- **dpkg-deb** (packaging — included on Debian/Ubuntu)

### Build the .deb package

```bash
git clone https://github.com/dashw00d/lantern.git
cd lantern
bash packaging/build-deb.sh
```

This compiles the Elixir release, builds the Electron app, and produces a `.deb` in the project root:

```bash
sudo bash install.sh
```

### Development

Run the daemon and desktop app separately for development:

**One-time setup:**

```bash
sudo bash setup-dev.sh    # configures sudoers, Caddy, DNS
```

**Fast dev loop (no reinstall needed):**

```bash
bash dev-up.sh            # stops packaged runtime + starts source daemon
# Ctrl+C to stop daemon
bash dev-down.sh          # optional cleanup
```

**Daemon:**

```bash
cd daemon
mix deps.get
mix phx.server        # runs on http://127.0.0.1:4777
```

**Desktop app:**

```bash
cd desktop
npm install
npm run dev            # Vite dev server (renderer in browser)
```

To run the full Electron app in dev:

```bash
cd desktop
npm run build:main     # compile main process TypeScript
npm run dev:electron   # Electron + Vite dev server
```

**CLI:**

The CLI is a standalone bash script — no build step:

```bash
./cli/lantern status
```

## License

MIT
