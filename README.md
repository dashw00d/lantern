# Lantern — Local Dev Environment Manager for Linux

**The [Laravel Valet](https://laravel.com/docs/valet) / [Laravel Herd](https://herd.laravel.com) experience, on Linux.** A local development environment manager that gives every project its own HTTPS domain — no more `localhost:3000`.

Lantern auto-detects your projects (Laravel, Next.js, Vite, FastAPI, Django, PHP, static sites, anything), wires up TLS certificates, a reverse proxy, DNS, and shared services — then gets out of your way. Manage everything from the CLI, system tray, or a full desktop GUI.

> **If you've ever wished Valet or Herd existed for Linux, this is it.**

<!-- TODO: Add demo video/gif here -->

## Why Lantern?

| Pain | Lantern |
|------|---------|
| Juggling `localhost:3000`, `:3001`, `:8080`... | Every project gets `https://myapp.glow` |
| Manually editing `/etc/hosts` or nginx configs | Zero-config — drop a project in `~/sites`, done |
| No Valet/Herd on Linux | Built for Linux from the ground up |
| `mkcert` + nginx + manual plumbing for local HTTPS | Automatic trusted TLS certificates via Caddy |
| CLI-only tools with no GUI | Desktop app, system tray, **and** CLI |
| PHP-only tools (MAMP, XAMPP, Herd) | Framework-agnostic: PHP, Node, Python, static, anything |

## Features

- **Automatic project detection** — drop a project in `~/sites` and Lantern detects the framework (Laravel, Symfony, Next.js, Nuxt, Remix, Vite, FastAPI, Django, Flask, PHP, static HTML)
- **Custom local domains with HTTPS** — every project gets `project-name.glow` with a trusted TLS certificate, powered by Caddy's automatic SSL
- **Framework-agnostic** — works with any stack that runs a dev server or serves files. Not just PHP.
- **Dev server management** — automatically starts your dev server (`next dev`, `vite`, `uvicorn`, etc.) with allocated ports
- **Shared services** — Mailpit (email testing), Redis, and PostgreSQL as toggleable services
- **System tray** — start/stop projects and services from the tray without opening anything
- **Desktop GUI** — full dashboard with real-time status, logs, and settings
- **CLI** — `lantern scan`, `lantern on myapp`, `lantern status` — everything scriptable
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

Lantern auto-detects these out of the box — no configuration needed:

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

Need something else? Add a `lantern.yml` to any project to configure it manually.

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
