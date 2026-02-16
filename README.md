# Lantern — Local Dev + Agent Control Plane

**The [Laravel Valet](https://laravel.com/docs/valet) / [Laravel Herd](https://herd.laravel.com) local experience for Linux — plus a unified control plane for local or remote projects, tools, docs, and APIs.**

Lantern gives every project a trusted local `.glow` domain and one place to run, route, observe, and automate everything. It is intentionally **manifest-first**: `lantern scan` only imports projects that declare `lantern.yaml`/`lantern.yml`.

From that single source of truth, Lantern can:

- run and route local apps
- discover and serve docs + API metadata
- expose all context to agents through one MCP endpoint
- plug into larger orchestration frameworks (or act as the framework itself)

> **If you've ever wished Valet or Herd existed for Linux, this is it.**

<!-- TODO: Add demo video/gif here -->

## Why Lantern?

| Pain | Lantern |
|------|---------|
| Juggling `localhost:3000`, `:3001`, `:8080`... | Every project gets `https://myapp.glow` |
| Manually editing `/etc/hosts` or nginx configs | Manifest-first — add `lantern.yaml`, run scan, done |
| No Valet/Herd on Linux | Built for Linux from the ground up |
| `mkcert` + nginx + manual plumbing for local HTTPS | Automatic trusted TLS certificates via Caddy |
| CLI-only tools with no GUI | Desktop app, system tray, **and** CLI |
| PHP-only tools (MAMP, XAMPP, Herd) | Framework-agnostic: PHP, Node, Python, static, anything |
| Fragmented agent/tool configs | One MCP endpoint + project registry for everything |

## One Place for Everything

Lantern is not just a local proxy manager. It is a **single runtime + context layer** across your machine:

- **Apps:** start/stop/restart local services with domain routing and health checks
- **Docs:** project docs are indexed and made available to tools and agents
- **APIs:** manual + discovered endpoints are exposed in one consistent schema
- **Tools:** local tools become first-class entries in the same registry
- **Agents:** any MCP-compatible client can connect once and get full project context

This means you can use Lantern as:

- a single MCP server for agent clients
- a backend substrate inside a larger orchestration framework
- a replacement for fragmented per-tool integrations (including OpenClaw-style tool sprawl)

## Features

- **Manifest-first scanning** — `lantern scan` only imports folders with `lantern.yaml`/`lantern.yml`, keeping the registry clean and explicit
- **Custom local domains with HTTPS** — every project gets `project-name.glow` with a trusted TLS certificate, powered by Caddy's automatic SSL
- **Framework-agnostic** — works with any stack that runs a dev server or serves files. Not just PHP.
- **Reliable local runtime lifecycle** — Start/Stop/Restart run through one lifecycle with startup readiness checks and stronger process teardown
- **Runtime command overrides** — optional `deploy.start/stop/restart/logs/status` can override default runtime behavior while staying local-first
- **Port conflict guardrails** — proxy `run_cmd` must use `${PORT}` unless you configure a fixed `upstream_url`/runtime override
- **Shared services** — Mailpit (email testing), Redis, and PostgreSQL as toggleable services
- **System tray** — start/stop projects and services from the tray without opening anything
- **Desktop GUI** — full dashboard with real-time status, logs, settings, and one-click **Shutdown All Runtime**
- **CLI** — `lantern scan`, `lantern on myapp`, `lantern status` — everything scriptable
- **MCP-native** — expose all project/tool context over MCP at `/mcp` and bootstrap clients with `lantern mcp install`
- **Agent-ready by default** — one MCP endpoint for Cursor/Claude/OpenCode/OpenClaw-style flows, plus clean integration into multi-agent orchestration stacks
- **Runs as a systemd daemon** — always on, survives reboots, zero overhead when idle
- **Package manager detection** — automatically uses npm, pnpm, yarn, or bun based on your lockfile
- **Reset from manifest** — restore project settings from `lantern.yaml` without writing over your files

## Runtime Model

Lantern uses one local runtime model for all projects:

- **Default:** `run.cmd` + allocated `${PORT}`
- **Fixed upstream services:** set `upstream_url` (for already-running systemd/tmux/docker services)
- **Optional runtime overrides:** use `deploy.start/stop/...` commands when you need custom control

When a project has a local process command, Lantern verifies it actually binds to the expected port before marking it as running.

## MCP + Orchestration

Lantern’s MCP server (`/mcp`) gives agents access to project metadata, docs, endpoints, discovery, and runtime actions.

- Use Lantern as your **single MCP** so clients do not need per-project setup
- Or integrate Lantern into a broader orchestration layer as the local runtime/context provider
- `lantern mcp install <client>` bootstraps common clients quickly

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

Lantern runs a lightweight daemon (Elixir/Phoenix) that orchestrates:

| Component | Role |
|-----------|------|
| **Caddy** | Reverse proxy + automatic local TLS certificates |
| **dnsmasq** | Local `.glow` wildcard DNS resolution to 127.0.0.1 |
| **Process supervisor** | Starts/stops dev servers with automatic port allocation |

The CLI, desktop app, and system tray are all thin clients that talk to the daemon REST API on port `4777`.

## Supported Frameworks

Lantern supports these stacks and can infer sane defaults from your manifest:

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

Need something else? Add a `lantern.yml` or `lantern.yaml` to any project and keep behavior explicit.

You can start from `lantern.yaml.example` at the repo root, including optional auto-discovery sections:

- `docs_auto`: discover docs from globs (for example `docs/**/*.md`)
- `api_auto`: pull OpenAPI specs from local files or running services (for example FastAPI `/openapi.json`)

It also includes runtime examples for:

- `run.cmd` with `${PORT}`
- `upstream_url` for fixed-port services
- optional `deploy.start/stop/restart/logs/status` overrides

## Compared To

| Feature | Lantern | Valet | Herd | XAMPP/MAMP |
|---------|---------|-------|------|------------|
| **Platform** | Linux | macOS | macOS/Windows | All |
| **Frameworks** | Any | PHP-first | PHP-first | PHP only |
| **Local HTTPS** | Automatic | Automatic | Automatic | Manual |
| **GUI** | Desktop + Tray | No | Yes | Yes |
| **CLI** | Yes | Yes | Yes | No |
| **Dev server management** | Yes | No | No | No |
| **Service management** | Yes | Partial | Yes | Yes |
| **Config required** | Zero | Minimal | Minimal | Significant |
| **Open source** | Yes | Yes | No | Partial |

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
