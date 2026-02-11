#!/bin/bash
# ============================================================================
# Development setup — run once to configure system for running Lantern
# from source (without the .deb package).
#
# Usage: sudo bash setup-dev.sh
# ============================================================================
set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "Run with sudo: sudo bash setup-dev.sh"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REAL_USER="${SUDO_USER:-$(logname 2>/dev/null || echo root)}"

echo "Setting up Lantern development environment for ${REAL_USER}..."

# Sudoers
if [[ -f "$SCRIPT_DIR/packaging/sudoers" && "$REAL_USER" != "root" ]]; then
    sed "s/__USER__/${REAL_USER}/g" "$SCRIPT_DIR/packaging/sudoers" > /etc/sudoers.d/lantern
    chmod 0440 /etc/sudoers.d/lantern
    visudo -cf /etc/sudoers.d/lantern || { rm -f /etc/sudoers.d/lantern; echo "sudoers failed!"; }
    echo "  sudoers: OK"
fi

# Caddy
if command -v caddy &>/dev/null; then
    mkdir -p /etc/caddy/sites.d
    [[ "$REAL_USER" != "root" ]] && chown "$REAL_USER" /etc/caddy/sites.d
    if [[ ! -f /etc/caddy/Caddyfile ]] || ! grep -q "import /etc/caddy/sites.d" /etc/caddy/Caddyfile; then
        cat > /etc/caddy/Caddyfile <<'EOF'
{
  local_certs
}
import /etc/caddy/sites.d/*.caddy
EOF
    fi
    systemctl restart caddy 2>/dev/null || systemctl start caddy 2>/dev/null || true
    su - "$REAL_USER" -c "caddy trust 2>/dev/null" || true
    echo "  caddy: OK"
else
    echo "  caddy: NOT INSTALLED — install with: sudo apt install caddy"
fi

# DNS (check NetworkManager first, then standalone dnsmasq — same order as postinst)
if [[ -d /etc/NetworkManager/dnsmasq.d && ! -f /etc/NetworkManager/dnsmasq.d/lantern.conf ]]; then
    echo "address=/.glow/127.0.0.1" > /etc/NetworkManager/dnsmasq.d/lantern.conf
    systemctl restart NetworkManager 2>/dev/null || true
    echo "  dns: OK (NetworkManager/dnsmasq)"
elif [[ -d /etc/dnsmasq.d && ! -f /etc/dnsmasq.d/lantern.conf ]]; then
    echo "address=/.glow/127.0.0.1" > /etc/dnsmasq.d/lantern.conf
    systemctl restart dnsmasq 2>/dev/null || true
    echo "  dns: OK (dnsmasq)"
else
    echo "  dns: already configured"
fi

echo ""
echo "Done! Start the daemon with: cd daemon && mix phx.server"
