#!/bin/bash
# ============================================================================
# Build a single .deb package for Lantern
# Combines: Elixir daemon + bash CLI + Electron desktop app
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

VERSION="0.1.0"
ARCH="amd64"
PKG_NAME="lantern_${VERSION}_${ARCH}"
BUILD_DIR="$PROJECT_ROOT/build-deb"
PKG_DIR="$BUILD_DIR/$PKG_NAME"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BOLD='\033[1m'
RESET='\033[0m'

info()    { echo -e "${BOLD}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
die()     { echo -e "${RED}[ERR]${RESET}   $*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# Clean previous build
# ---------------------------------------------------------------------------

info "Cleaning previous build artifacts..."
rm -rf "$BUILD_DIR"
mkdir -p "$PKG_DIR"

# ---------------------------------------------------------------------------
# Step 1: Build the Elixir release
# ---------------------------------------------------------------------------

info "Building Elixir release..."
cd "$PROJECT_ROOT/daemon"

export MIX_ENV=prod

mix deps.get --only prod
mix compile
mix release --overwrite

RELEASE_DIR="$PROJECT_ROOT/daemon/_build/prod/rel/lantern"

if [[ ! -d "$RELEASE_DIR" ]]; then
    die "Elixir release not found at $RELEASE_DIR"
fi

success "Elixir release built"

# ---------------------------------------------------------------------------
# Step 2: Build the Electron desktop app
# ---------------------------------------------------------------------------

info "Building Electron desktop app..."
cd "$PROJECT_ROOT/desktop"

npm ci --ignore-scripts 2>/dev/null || npm install
npm run build

# Use electron-builder to produce an unpacked directory
npx electron-builder --linux dir --config electron-builder.yml

# Find the unpacked output
ELECTRON_UNPACKED="$PROJECT_ROOT/desktop/release/linux-unpacked"

if [[ ! -d "$ELECTRON_UNPACKED" ]]; then
    die "Electron unpacked build not found at $ELECTRON_UNPACKED"
fi

success "Electron desktop app built"

# ---------------------------------------------------------------------------
# Step 3: Assemble the .deb directory structure
# ---------------------------------------------------------------------------

info "Assembling .deb package structure..."

# DEBIAN control files
mkdir -p "$PKG_DIR/DEBIAN"
cp "$SCRIPT_DIR/control"  "$PKG_DIR/DEBIAN/control"
cp "$SCRIPT_DIR/postinst" "$PKG_DIR/DEBIAN/postinst"
cp "$SCRIPT_DIR/prerm"    "$PKG_DIR/DEBIAN/prerm"
cp "$SCRIPT_DIR/postrm"   "$PKG_DIR/DEBIAN/postrm"
chmod 755 "$PKG_DIR/DEBIAN/postinst" "$PKG_DIR/DEBIAN/prerm" "$PKG_DIR/DEBIAN/postrm"

# /opt/lantern/daemon — Elixir release
mkdir -p "$PKG_DIR/opt/lantern/daemon"
cp -a "$RELEASE_DIR"/. "$PKG_DIR/opt/lantern/daemon/"

# /opt/lantern/desktop — Electron app
mkdir -p "$PKG_DIR/opt/lantern/desktop"
cp -a "$ELECTRON_UNPACKED"/. "$PKG_DIR/opt/lantern/desktop/"

# Rename the electron binary to lantern-desktop
ELECTRON_BIN=$(find "$PKG_DIR/opt/lantern/desktop" -maxdepth 1 -name "lantern-desktop" -o -name "Lantern" -o -name "lantern" -type f -executable 2>/dev/null | head -1)
if [[ -n "$ELECTRON_BIN" && "$(basename "$ELECTRON_BIN")" != "lantern-desktop" ]]; then
    mv "$ELECTRON_BIN" "$PKG_DIR/opt/lantern/desktop/lantern-desktop"
fi

# /opt/lantern/cli — CLI script
mkdir -p "$PKG_DIR/opt/lantern/cli"
cp "$PROJECT_ROOT/cli/lantern" "$PKG_DIR/opt/lantern/cli/lantern"
chmod 755 "$PKG_DIR/opt/lantern/cli/lantern"

# /usr/local/bin/lantern — symlink to CLI
mkdir -p "$PKG_DIR/usr/local/bin"
ln -sf /opt/lantern/cli/lantern "$PKG_DIR/usr/local/bin/lantern"

# /usr/share/applications — .desktop file
mkdir -p "$PKG_DIR/usr/share/applications"
cp "$SCRIPT_DIR/lantern.desktop" "$PKG_DIR/usr/share/applications/lantern.desktop"

# /usr/share/icons — app icon
mkdir -p "$PKG_DIR/usr/share/icons/hicolor/256x256/apps"
cp "$SCRIPT_DIR/lantern.png" "$PKG_DIR/usr/share/icons/hicolor/256x256/apps/lantern.png"

# /etc/systemd/system — systemd service
mkdir -p "$PKG_DIR/etc/systemd/system"
cp "$SCRIPT_DIR/lanternd.service" "$PKG_DIR/etc/systemd/system/lanternd.service"

# ---------------------------------------------------------------------------
# Step 4: Calculate installed size for control file
# ---------------------------------------------------------------------------

INSTALLED_SIZE=$(du -sk "$PKG_DIR" | awk '{print $1}')
sed -i "s/^Architecture: amd64/Architecture: amd64\nInstalled-Size: ${INSTALLED_SIZE}/" "$PKG_DIR/DEBIAN/control"

success "Package structure assembled"

# ---------------------------------------------------------------------------
# Step 5: Build the .deb
# ---------------------------------------------------------------------------

info "Building .deb package..."
cd "$BUILD_DIR"

dpkg-deb --build "$PKG_NAME"

DEB_FILE="$BUILD_DIR/${PKG_NAME}.deb"

if [[ ! -f "$DEB_FILE" ]]; then
    die "Failed to build .deb package"
fi

# Move to project root for convenience
mv "$DEB_FILE" "$PROJECT_ROOT/${PKG_NAME}.deb"

echo ""
success "Package built: ${BOLD}${PKG_NAME}.deb${RESET}"
echo ""
echo "  Install:    sudo dpkg -i ${PKG_NAME}.deb"
echo "  Inspect:    dpkg-deb --info ${PKG_NAME}.deb"
echo "  Contents:   dpkg-deb --contents ${PKG_NAME}.deb"
echo "  Uninstall:  sudo dpkg -r lantern"
echo ""
