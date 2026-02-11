# Lantern

**Valet for Linux.** A blazing-fast local development environment manager that gives every project its own `.glow` domain with automatic HTTPS — no more `localhost:3000`.

Lantern auto-detects your projects (Laravel, Node, Python, static sites, anything), wires up TLS certificates, reverse proxies, DNS, and shared services — then gets out of your way. Manage everything from the CLI, system tray, or a full desktop GUI.

<!-- TODO: Add demo video/gif here -->

## Features

- **Automatic project detection** — drop a project in `~/sites` and Lantern figures out what it is (Laravel, Vite, FastAPI, PHP, static, etc.)
- **`.glow` domains with HTTPS** — every project gets `project-name.glow` with a trusted TLS certificate, powered by Caddy
- **Shared services** — Mailpit, Redis, Postgres managed as toggleable services
- **System tray** — start/stop projects and services without opening anything
- **Desktop GUI** — full dashboard with real-time status, logs, and settings
- **CLI** — `lantern start myapp`, `lantern status`, `lantern services` — everything scriptable
- **Runs as a systemd daemon** — always on, survives reboots, zero overhead when idle

## Install

The installer handles everything — Caddy, dnsmasq, DNS, TLS trust, and the daemon:

```bash
git clone https://github.com/your-username/lantern.git
cd lantern
bash packaging/build-deb.sh
sudo bash install.sh
```

Or if you already have the `.deb`:

```bash
sudo bash install.sh lantern_0.1.0_amd64.deb
```

That's it. Open **Lantern** from your app menu or use the CLI:

```bash
lantern status
lantern scan         # detect projects in ~/sites
lantern start myapp  # activate a project
lantern services     # see shared services
```

## How It Works

```
 You                    Lantern                     Your Projects
─────                  ─────────                   ───────────────
lantern start myapp → daemon allocates port    → starts dev server
                       generates Caddy config  → myapp.glow:443
                       writes DNS resolution   → resolves .glow TLD
                       ✓ https://myapp.glow ready
```

Lantern runs a lightweight daemon (Elixir/Phoenix) on port `4777` that orchestrates:

| Component | Role |
|-----------|------|
| **Caddy** | Reverse proxy + automatic TLS certificates |
| **dnsmasq** | Local `.glow` DNS resolution |
| **Process supervisor** | Starts/stops dev servers with port allocation |

The CLI, desktop app, and system tray are all thin clients that talk to the daemon API.

## Architecture

```
lantern/
├── daemon/          Elixir/Phoenix API daemon (systemd service)
├── desktop/         Electron + React desktop app with system tray
├── cli/             Bash CLI (lantern command)
└── packaging/       .deb build scripts, systemd unit, icons
```

## Releases

Pre-built `.deb` packages are available on the [Releases](https://github.com/your-username/lantern/releases) page.

Each release includes the daemon, CLI, and desktop app in a single package. Currently targeting **Ubuntu/Debian x86_64**.

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
git clone https://github.com/your-username/lantern.git
cd lantern
bash packaging/build-deb.sh
```

This compiles the Elixir release, builds the Electron app, and produces a `.deb` in the project root:

```bash
sudo bash install.sh
```

### Development

Run the daemon and desktop app separately for development:

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
