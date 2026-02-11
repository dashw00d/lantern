#!/bin/bash
# ============================================================================
# Lantern installer — one command, fully automated
#
# Usage:
#   sudo bash install.sh              # install from built .deb in this dir
#   sudo bash install.sh lantern.deb  # install a specific .deb file
# ============================================================================
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
BOLD='\033[1m'
RESET='\033[0m'

info()    { echo -e "${BOLD}==>${RESET} $*"; }
success() { echo -e "${GREEN}==>${RESET} $*"; }
die()     { echo -e "${RED}Error:${RESET} $*" >&2; exit 1; }

# Must be root
[[ $EUID -eq 0 ]] || die "Run with sudo: sudo bash install.sh"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------------------------------------------------------------------------
# Install Caddy if not present
# ---------------------------------------------------------------------------
if ! command -v caddy &>/dev/null; then
    info "Installing Caddy web server..."
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

# ---------------------------------------------------------------------------
# Install dnsmasq if not present
# ---------------------------------------------------------------------------
if ! command -v dnsmasq &>/dev/null; then
    info "Installing dnsmasq for .glow domain resolution..."
    apt-get install -y -qq dnsmasq >/dev/null 2>&1 || true
    success "dnsmasq installed"
fi

# ---------------------------------------------------------------------------
# Find and install the .deb
# ---------------------------------------------------------------------------
DEB_FILE="${1:-}"

if [[ -z "$DEB_FILE" ]]; then
    DEB_FILE=$(find "$SCRIPT_DIR" -maxdepth 1 -name "lantern_*.deb" -type f | sort -V | tail -1)
fi

if [[ -z "$DEB_FILE" || ! -f "$DEB_FILE" ]]; then
    die "No .deb file found. Build first with: bash packaging/build-deb.sh"
fi

info "Installing $(basename "$DEB_FILE")..."
dpkg -i "$DEB_FILE" 2>&1 | sed 's/^/  /'

# Fix any missing dependencies
apt-get install -f -y -qq >/dev/null 2>&1 || true

echo ""
success "Lantern is installed and running!"
echo ""
echo "  CLI:      lantern status"
echo "  Desktop:  find Lantern in your application menu"
echo "  Daemon:   http://localhost:4777"
echo ""
echo "  To scan your projects:  lantern scan"
echo "  To activate a project:  lantern on <name>"
echo ""
