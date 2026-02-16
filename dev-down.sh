#!/bin/bash
# ============================================================================
# Stop Lantern dev/runtime processes used during local testing.
#
# Usage:
#   bash dev-down.sh
# ============================================================================
set -euo pipefail

BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RESET='\033[0m'

info() { echo -e "${BOLD}==>${RESET} $*"; }
ok() { echo -e "${GREEN}  ✓${RESET} $*"; }
warn() { echo -e "${YELLOW}  !${RESET} $*"; }

stop_by_port() {
  local port="$1"
  local pids
  pids="$(lsof -tiTCP:"${port}" -sTCP:LISTEN 2>/dev/null || true)"

  if [[ -z "${pids}" ]]; then
    ok "No listeners on :${port}"
    return
  fi

  info "Stopping listener(s) on :${port}: ${pids//$'\n'/, }"
  for pid in $pids; do
    kill "$pid" >/dev/null 2>&1 || true
  done
}

info "Stopping packaged Lantern runtime..."
if [[ -x /opt/lantern/daemon/bin/lantern ]]; then
  /opt/lantern/daemon/bin/lantern stop >/dev/null 2>&1 || true
fi
pkill -f '/opt/lantern/desktop/lantern-desktop' >/dev/null 2>&1 || true

stop_by_port 4777

sleep 0.3
if curl -s --max-time 1 http://127.0.0.1:4777/api/system/health >/dev/null 2>&1; then
  warn "Daemon still responding on :4777 (another process may own it)"
else
  ok "Daemon is stopped"
fi
