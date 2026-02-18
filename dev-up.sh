#!/bin/bash
# ============================================================================
# Start Lantern from source for fast local testing.
#
# Usage:
#   bash dev-up.sh
# ============================================================================
set -euo pipefail

BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
RESET='\033[0m'

info() { echo -e "${BOLD}==>${RESET} $*"; }
ok() { echo -e "${GREEN}  ✓${RESET} $*"; }
warn() { echo -e "${YELLOW}  !${RESET} $*"; }
die() { echo -e "${RED}  ✗${RESET} $*" >&2; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DAEMON_DIR="${SCRIPT_DIR}/daemon"

is_active() {
  systemctl is-active "$1" >/dev/null 2>&1
}

ensure_caddy_mode() {
  if ! command -v systemctl >/dev/null 2>&1; then
    warn "systemctl not found; skipping Caddy/nginx checks"
    return
  fi

  if is_active caddy && ! is_active nginx; then
    ok "Caddy already active, nginx stopped"
    return
  fi

  if [[ -x "${SCRIPT_DIR}/toggle-server.sh" ]]; then
    info "Switching web stack to Lantern (Caddy)..."
    if sudo -n bash "${SCRIPT_DIR}/toggle-server.sh" lantern >/dev/null 2>&1; then
      ok "Web stack switched to Caddy"
    elif sudo bash "${SCRIPT_DIR}/toggle-server.sh" lantern; then
      ok "Web stack switched to Caddy"
    else
      warn "Could not auto-run toggle script. Run: sudo bash toggle-server.sh lantern"
    fi
  else
    warn "toggle-server.sh not found; skipping web stack switch"
  fi
}

stop_packaged_runtime() {
  info "Stopping packaged Lantern runtime..."

  if [[ -x /opt/lantern/daemon/bin/lantern ]]; then
    /opt/lantern/daemon/bin/lantern stop >/dev/null 2>&1 || true
  fi

  pkill -f '/opt/lantern/desktop/lantern-desktop' >/dev/null 2>&1 || true
  ok "Packaged runtime stopped (if it was running)"
}

graceful_shutdown_lantern() {
  # If Lantern is running, ask it to gracefully stop all managed projects
  # before we kill the process. This prevents orphan child processes (uvicorn, etc.)
  # from surviving the restart.
  if curl -sf http://127.0.0.1:4777/api/health >/dev/null 2>&1; then
    info "Gracefully stopping managed projects..."
    curl -sf -X POST http://127.0.0.1:4777/api/system/shutdown >/dev/null 2>&1 || true
    sleep 1
    ok "Managed projects stopped"
  fi
}

free_daemon_port() {
  local pids
  pids="$(lsof -tiTCP:4777 -sTCP:LISTEN 2>/dev/null || true)"

  if [[ -z "${pids}" ]]; then
    ok "Port 4777 is free"
    return
  fi

  warn "Port 4777 in use; stopping existing listener(s): ${pids//$'\n'/, }"
  for pid in $pids; do
    kill "$pid" >/dev/null 2>&1 || true
  done

  sleep 0.5
  for pid in $pids; do
    if kill -0 "$pid" >/dev/null 2>&1; then
      kill -9 "$pid" >/dev/null 2>&1 || true
    fi
  done

  ok "Port 4777 cleared"
}

if [[ $EUID -eq 0 ]]; then
  die "Run this as your normal user (not sudo)"
fi

[[ -d "${DAEMON_DIR}" ]] || die "Missing daemon directory at ${DAEMON_DIR}"
command -v mix >/dev/null 2>&1 || die "mix not found. Install Elixir and Erlang first."

ensure_caddy_mode
graceful_shutdown_lantern
stop_packaged_runtime
free_daemon_port

cd "${DAEMON_DIR}"

if [[ ! -d deps ]]; then
  info "Fetching daemon dependencies..."
  mix deps.get
fi

info "Starting Lantern daemon from source at http://127.0.0.1:4777"
info "Press Ctrl+C to stop."
exec mix phx.server
