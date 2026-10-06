#!/bin/bash
# Build + install elephant + walker from source on Ubuntu 24.04.
#
# Walker is the Wayland-native Spotlight-style launcher (GTK4, real icons
# per app/file) behind Super+Space. Neither it nor its elephant backend
# (provider service: desktop apps, files, ...) is packaged for noble, and
# walker also needs gtk4-layer-shell, which noble lacks too. So this builds:
#   1. gtk4-layer-shell (meson) .......... /usr/local (system GTK4 plugs in)
#   2. elephant + providers (Go) ......... PREFIX/bin + ~/.config/elephant
#   3. walker (cargo, GTK4 UI) ........... PREFIX/bin
#
# Pinned tags (re-check on the next LTS):
#   gtk4-layer-shell v1.3.0, elephant v2.22.0, walker v2.17.0.
#   Elephant needs Go >= 1.25 (fetched as a tarball to ~/.local, no sudo).
#
# Usage:
#   ./scripts/build-walker.sh                 # everything to /usr/local
#   PREFIX=$HOME/.local ./scripts/build-walker.sh  # user-local binaries
#   GO_VERSION=1.25.4 ./scripts/build-walker.sh    # pin Go explicitly
#
# After this: configure providers/theme (config/elephant/*, config/walker/*),
# enable the elephant service, bind Super+Space — see README ("Niri session").
set -euo pipefail

PREFIX="${PREFIX:-/usr/local}"
SRC_DIR="${SRC_DIR:-$HOME/.local/src}"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LAYER_SHELL_REPO="https://github.com/wmww/gtk4-layer-shell.git"
LAYER_SHELL_TAG="${LAYER_SHELL_TAG:-v1.3.0}"
ELEPHANT_REPO="https://github.com/abenz1267/elephant.git"
ELEPHANT_TAG="${ELEPHANT_TAG:-v2.22.0}"
WALKER_REPO="https://github.com/abenz1267/walker.git"
WALKER_TAG="${WALKER_TAG:-v2.17.0}"
# Providers compiled as .so plugins (must match what config enables).
ELEPHANT_PROVIDERS="${ELEPHANT_PROVIDERS:-desktopapplications files clipboard}"

log() { printf '==> %s\n' "$*"; }

# --- 0. Go toolchain (tarball to ~/.local, no sudo) -------------------------------
if ! command -v go >/dev/null 2>&1 || ! go version 2>/dev/null | grep -Eq 'go1\.(2[5-9]|[3-9][0-9])'; then
    GO_VERSION="${GO_VERSION:-$(curl -fsSL https://go.dev/VERSION?m=text | head -1)}"
    [ -n "$GO_VERSION" ] || { log "cannot determine Go version (set GO_VERSION=)"; exit 1; }
    log "installing $GO_VERSION to ~/.local/go..."
    rm -rf "$HOME/.local/go"
    curl -fL -o /tmp/go.tgz "https://go.dev/dl/${GO_VERSION}.linux-amd64.tar.gz"
    mkdir -p "$HOME/.local"
    tar -C "$HOME/.local" -xzf /tmp/go.tgz
    rm -f /tmp/go.tgz
else
    log "go already present: $(go version)"
fi
export PATH="$HOME/.local/go/bin:$PATH"
export GOTOOLCHAIN=local

# --- 1. system build dependencies (sudo) -------------------------------------------
BUILD_DEPS="meson ninja-build pkg-config git curl cmake valac libgtk-4-dev
    libpoppler-glib-dev libwayland-dev wayland-protocols
    libgirepository1.0-dev gobject-introspection"
# shellcheck disable=SC2086
if ! dpkg -s $BUILD_DEPS >/dev/null 2>&1; then
    log "installing walker build dependencies (sudo)..."
    # NOTE: NOT `apt update && apt install`: with `set -e`, a failed update
    # inside an &&-list silently skips the install instead of aborting.
    sudo apt update || { log "apt update FAILED — fix broken sources (see /etc/apt/sources.list.d/) and re-run"; exit 1; }
    # shellcheck disable=SC2086
    sudo apt install -y $BUILD_DEPS
else
    log "build dependencies already present"
fi
export PKG_CONFIG_PATH="/usr/local/lib/x86_64-linux-gnu/pkgconfig:/usr/local/lib/pkgconfig:${PKG_CONFIG_PATH:-}"

# --- 2. gtk4-layer-shell (not packaged for noble) -----------------------------------
mkdir -p "$SRC_DIR"
if [ -d "$SRC_DIR/gtk4-layer-shell/.git" ]; then
    log "updating gtk4-layer-shell sources..."
    git -C "$SRC_DIR/gtk4-layer-shell" fetch --tags origin
else
    log "cloning gtk4-layer-shell sources..."
    git clone "$LAYER_SHELL_REPO" "$SRC_DIR/gtk4-layer-shell"
    git -C "$SRC_DIR/gtk4-layer-shell" fetch --tags origin
fi
log "checking out gtk4-layer-shell $LAYER_SHELL_TAG"
git -C "$SRC_DIR/gtk4-layer-shell" checkout -q "$LAYER_SHELL_TAG"
if [ -d "$SRC_DIR/gtk4-layer-shell/build" ]; then
    meson setup --wipe "$SRC_DIR/gtk4-layer-shell/build" "$SRC_DIR/gtk4-layer-shell"
else
    meson setup "$SRC_DIR/gtk4-layer-shell/build" "$SRC_DIR/gtk4-layer-shell"
fi
ninja -C "$SRC_DIR/gtk4-layer-shell/build"
if [ -w "$(dirname "$PREFIX/bin")" ]; then SUDO=; else SUDO=sudo; log "need sudo for $PREFIX"; fi
# shellcheck disable=SC2086
$SUDO ninja -C "$SRC_DIR/gtk4-layer-shell/build" install
$SUDO ldconfig 2>/dev/null || true

# --- 3. elephant (+ provider plugins) -----------------------------------------------
if [ -d "$SRC_DIR/elephant/.git" ]; then
    log "updating elephant sources..."
    git -C "$SRC_DIR/elephant" fetch --tags origin
else
    log "cloning elephant sources..."
    git clone "$ELEPHANT_REPO" "$SRC_DIR/elephant"
    git -C "$SRC_DIR/elephant" fetch --tags origin
fi
log "checking out elephant $ELEPHANT_TAG"
git -C "$SRC_DIR/elephant" checkout -q "$ELEPHANT_TAG"
log "building elephant $ELEPHANT_TAG..."
go -C "$SRC_DIR/elephant" build -o "$SRC_DIR/elephant/elephant" ./cmd/elephant
$SUDO install -m 0755 "$SRC_DIR/elephant/elephant" "$PREFIX/bin/elephant"
mkdir -p "$HOME/.config/elephant/providers"
# shellcheck disable=SC2086
for p in $ELEPHANT_PROVIDERS; do
    log "building elephant provider: $p..."
    go -C "$SRC_DIR/elephant" build -buildmode=plugin \
        -o "$HOME/.config/elephant/providers/$p.so" "./internal/providers/$p"
done

# --- 4. walker (GTK4 UI) ---------------------------------------------------------------
if [ -d "$SRC_DIR/walker/.git" ]; then
    log "updating walker sources..."
    git -C "$SRC_DIR/walker" fetch --tags origin
else
    log "cloning walker sources..."
    git clone "$WALKER_REPO" "$SRC_DIR/walker"
    git -C "$SRC_DIR/walker" fetch --tags origin
fi
log "checking out walker $WALKER_TAG"
git -C "$SRC_DIR/walker" checkout -q "$WALKER_TAG"
# ubuntu-i3-setup: pin preview panels to the fixed 770px omnibar box
# (images/PDFs render at 380px, tall content scrolls at 300px).
if [ -f "$REPO_DIR/scripts/walker-preview-size.patch" ]; then
    log "applying walker-preview-size.patch..."
    git -C "$SRC_DIR/walker" apply --check "$REPO_DIR/scripts/walker-preview-size.patch" \
        && git -C "$SRC_DIR/walker" apply "$REPO_DIR/scripts/walker-preview-size.patch" \
        || log "(warn: preview patch did not apply cleanly — see scripts/walker-preview-size.patch)"
fi
export PATH="$HOME/.cargo/bin:$PATH"
log "building walker $WALKER_TAG (release; takes a while, ~10 min)..."
cargo build --release --manifest-path "$SRC_DIR/walker/Cargo.toml"
$SUDO install -m 0755 "$SRC_DIR/walker/target/release/walker" "$PREFIX/bin/walker"

# --- 5. validate --------------------------------------------------------------------------
log "validating..."
"$PREFIX/bin/elephant" version 2>&1 | head -1 || true
"$PREFIX/bin/walker" --version 2>&1 | head -1 || true
ls "$HOME/.config/elephant/providers/"
log "done. Sources: $SRC_DIR/{gtk4-layer-shell,elephant,walker}."
log "next: configure elephant+walker (config/elephant, config/walker), then ./install.sh"
log "note: if elephant/walker were already running (e.g. you added a provider"
log "or edited a theme), restart them now so the new files load:"
log "pkill -x elephant walker; then relaunch elephant +"
log "'walker --gapplication-service' (niri does this at next login)."
