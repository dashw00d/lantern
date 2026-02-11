#!/bin/bash
# ============================================================================
# Lantern — full nuke-and-reinstall from source
# Usage: sudo bash reinstall.sh
# ============================================================================
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
BOLD='\033[1m'
RESET='\033[0m'

info()    { echo -e "${BOLD}==>${RESET} $*"; }
success() { echo -e "${GREEN}==>${RESET} $*"; }
die()     { echo -e "${RED}Error:${RESET} $*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || die "Run with sudo: sudo bash reinstall.sh"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REAL_USER="${SUDO_USER:-$(logname 2>/dev/null || echo root)}"
REAL_HOME=$(eval echo "~${REAL_USER}")

# =========================================================================
# 1. NUKE EVERYTHING
# =========================================================================
info "Stopping services..."
systemctl stop lanternd 2>/dev/null || true
systemctl disable lanternd 2>/dev/null || true

info "Killing stale BEAM processes..."
pkill -u "$REAL_USER" -f "beam.smp.*lantern" 2>/dev/null || true
pkill -u "$REAL_USER" -f "beam.smp.*mix phx.server" 2>/dev/null || true
sleep 1

info "Removing old package..."
dpkg -r lantern 2>/dev/null || true

info "Wiping all state..."
rm -rf "${REAL_HOME}/.config/lantern"
rm -f /etc/sudoers.d/lantern
rm -f /etc/systemd/system/lanternd.service
rm -rf /etc/caddy/sites.d
rm -f /etc/caddy/Caddyfile
systemctl daemon-reload

# =========================================================================
# 2. INSTALL CADDY IF MISSING
# =========================================================================
if ! command -v caddy &>/dev/null; then
    info "Installing Caddy..."
    apt-get install -y -qq debian-keyring debian-archive-keyring apt-transport-https curl >/dev/null
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | \
        gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg 2>/dev/null
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | \
        tee /etc/apt/sources.list.d/caddy-stable.list >/dev/null
    apt-get update -qq >/dev/null
    apt-get install -y -qq caddy >/dev/null
    success "Caddy installed"
else
    success "Caddy already installed ($(caddy version))"
fi

# =========================================================================
# 3. BUILD FROM SOURCE
# =========================================================================
info "Building Elixir daemon..."
cd "$SCRIPT_DIR/daemon"
su - "$REAL_USER" -c "cd '$SCRIPT_DIR/daemon' && MIX_ENV=prod mix deps.get --only prod && mix compile && mix release --overwrite"

info "Building Electron desktop app..."
cd "$SCRIPT_DIR/desktop"
su - "$REAL_USER" -c "cd '$SCRIPT_DIR/desktop' && npm ci --ignore-scripts 2>/dev/null || npm install && npm run build"
su - "$REAL_USER" -c "cd '$SCRIPT_DIR/desktop' && npx electron-builder --linux dir --config electron-builder.yml"

# =========================================================================
# 4. ASSEMBLE AND BUILD .DEB
# =========================================================================
info "Building .deb package..."
su - "$REAL_USER" -c "cd '$SCRIPT_DIR' && bash packaging/build-deb.sh"

# =========================================================================
# 5. INSTALL THE .DEB (triggers postinst which does all system setup)
# =========================================================================
DEB_FILE=$(find "$SCRIPT_DIR" -maxdepth 1 -name "lantern_*.deb" -type f | sort -V | tail -1)
[[ -n "$DEB_FILE" ]] || die "No .deb file found after build"

info "Installing $(basename "$DEB_FILE")..."
dpkg -i "$DEB_FILE" 2>&1 | sed 's/^/  /'
apt-get install -f -y -qq >/dev/null 2>&1 || true

# =========================================================================
# 6. VERIFY
# =========================================================================
echo ""
sleep 2  # give daemon a moment to start

if curl -s http://127.0.0.1:4777/api/system/health >/dev/null 2>&1; then
    success "Daemon is running on port 4777"
else
    info "Daemon starting up... (check: systemctl status lanternd)"
fi

if systemctl is-active caddy >/dev/null 2>&1; then
    success "Caddy is running"
else
    info "Starting Caddy..."
    systemctl start caddy 2>/dev/null || true
fi

echo ""
success "Lantern installed from scratch!"
echo ""
echo "  Next steps:"
echo "    lantern scan          # detect projects in ~/sites"
echo "    lantern on <name>     # activate a project → https://<name>.glow"
echo ""
