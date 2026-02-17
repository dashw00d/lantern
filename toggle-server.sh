#!/bin/bash
# ============================================================================
# Toggle between Valet (nginx) and Lantern (Caddy) on ports 80/443
#
# Usage:
#   sudo bash toggle-server.sh lantern   # stop nginx, start caddy
#   sudo bash toggle-server.sh valet     # stop caddy, start nginx
#   sudo bash toggle-server.sh status    # show which is active
# ============================================================================
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
BOLD='\033[1m'
RESET='\033[0m'

info()    { echo -e "${BOLD}==>${RESET} $*"; }
success() { echo -e "${GREEN}  ✓${RESET} $*"; }
err()     { echo -e "${RED}  ✗${RESET} $*"; }

is_active() { systemctl is-active "$1" >/dev/null 2>&1; }

show_status() {
    echo ""
    if is_active nginx; then
        success "nginx is running (Valet)"
    else
        err "nginx is stopped"
    fi

    if is_active caddy; then
        success "caddy is running (Lantern)"
    else
        err "caddy is stopped"
    fi
    echo ""
}

case "${1:-status}" in
    lantern|caddy)
        [[ $EUID -eq 0 ]] || { echo "Run with sudo"; exit 1; }

        info "Switching to Lantern (Caddy)..."

        if is_active nginx; then
            systemctl stop nginx
            success "nginx stopped"
        else
            success "nginx already stopped"
        fi

        # Write correct Caddyfile (standard ports)
        cat > /etc/caddy/Caddyfile <<'EOF'
{
  local_certs
}
import /etc/caddy/sites.d/*.caddy
EOF

        # "start" is a no-op when caddy is already active but stuck in a
        # bad reload state; restart forces a clean config apply.
        systemctl reset-failed caddy >/dev/null 2>&1 || true
        systemctl restart caddy
        success "caddy restarted on ports 80/443"

        show_status
        echo "  Your .glow sites are now available at https://<name>.glow"
        echo ""
        ;;

    valet|nginx)
        [[ $EUID -eq 0 ]] || { echo "Run with sudo"; exit 1; }

        info "Switching to Valet (nginx)..."

        if is_active caddy; then
            systemctl stop caddy
            success "caddy stopped"
        else
            success "caddy already stopped"
        fi

        systemctl start nginx
        success "nginx started on ports 80/443"

        show_status
        echo "  Your .test sites are now available via Valet"
        echo ""
        ;;

    status)
        show_status
        ;;

    *)
        echo "Usage: sudo bash toggle-server.sh {lantern|valet|status}"
        exit 1
        ;;
esac
