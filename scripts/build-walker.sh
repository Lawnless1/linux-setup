#!/bin/bash
# Build + install elephant + walker from source, on any distro.
#
# Walker is the Wayland-native Spotlight-style launcher (GTK4, real icons
# per app/file) behind Super+Space; elephant is its provider backend
# (desktop apps, files, clipboard). Built from source everywhere because
# walker carries scripts/walker-preview-size.patch and elephant's provider
# plugins must be compiled with the same Go toolchain as elephant itself.
#   1. gtk4-layer-shell (meson) .......... only when the distro lacks it
#   2. elephant + providers (Go) ......... PREFIX/bin + ~/.config/elephant
#   3. walker (cargo, GTK4 UI) ........... PREFIX/bin
#
# Pinned tags: gtk4-layer-shell v1.3.0, elephant v2.22.0, walker v2.17.0.
# Elephant needs Go >= 1.25 (fetched to ~/.local/go when the distro's is older).
#
# Usage:
#   ./scripts/build-walker.sh                 # everything to /usr/local
#   PREFIX=$HOME/.local ./scripts/build-walker.sh  # user-local binaries
#   GO_VERSION=go1.25.4 ./scripts/build-walker.sh  # pin Go explicitly
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/pkg.sh
. "$REPO_DIR/scripts/lib/pkg.sh"

PREFIX="${PREFIX:-/usr/local}"
SRC_DIR="${SRC_DIR:-$HOME/.local/src}"
LAYER_SHELL_REPO="https://github.com/wmww/gtk4-layer-shell.git"
LAYER_SHELL_TAG="${LAYER_SHELL_TAG:-v1.3.0}"
ELEPHANT_REPO="https://github.com/abenz1267/elephant.git"
ELEPHANT_TAG="${ELEPHANT_TAG:-v2.22.0}"
WALKER_REPO="https://github.com/abenz1267/walker.git"
WALKER_TAG="${WALKER_TAG:-v2.17.0}"
# Providers compiled as .so plugins (must match what config enables).
ELEPHANT_PROVIDERS="${ELEPHANT_PROVIDERS:-desktopapplications files clipboard}"

# --- 0. toolchains + system build dependencies ---------------------------------------
pkg_install build-base build-walker
ensure_go
ensure_rust
export_local_pkgconfig
if [ -w "$(dirname "$PREFIX/bin")" ]; then SUDO=; else SUDO=sudo; log "need sudo for $PREFIX"; fi

# --- 1. gtk4-layer-shell (only when not packaged) ---------------------------------------
mkdir -p "$SRC_DIR"
if pkg-config --exists gtk4-layer-shell-0; then
    log "gtk4-layer-shell present: $(pkg-config --modversion gtk4-layer-shell-0)"
else
    log "building gtk4-layer-shell $LAYER_SHELL_TAG..."
    git_checkout "$LAYER_SHELL_REPO" "$SRC_DIR/gtk4-layer-shell" "$LAYER_SHELL_TAG"
    if [ -d "$SRC_DIR/gtk4-layer-shell/build" ]; then
        meson setup --wipe "$SRC_DIR/gtk4-layer-shell/build" "$SRC_DIR/gtk4-layer-shell"
    else
        meson setup "$SRC_DIR/gtk4-layer-shell/build" "$SRC_DIR/gtk4-layer-shell"
    fi
    ninja -C "$SRC_DIR/gtk4-layer-shell/build"
    $SUDO ninja -C "$SRC_DIR/gtk4-layer-shell/build" install
    $SUDO ldconfig 2>/dev/null || true
fi

# --- 2. elephant (+ provider plugins) -----------------------------------------------
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

# --- 3. walker (GTK4 UI) ---------------------------------------------------------------
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
# linux-setup: pin preview panels to the fixed 770px omnibar box
# (images/PDFs render at 380px, tall content scrolls at 300px).
if [ -f "$REPO_DIR/scripts/walker-preview-size.patch" ]; then
    log "applying walker-preview-size.patch..."
    git -C "$SRC_DIR/walker" apply --check "$REPO_DIR/scripts/walker-preview-size.patch" \
        && git -C "$SRC_DIR/walker" apply "$REPO_DIR/scripts/walker-preview-size.patch" \
        || log "(warn: preview patch did not apply cleanly — see scripts/walker-preview-size.patch)"
fi
log "building walker $WALKER_TAG (release; takes a while, ~10 min)..."
cargo build --release --manifest-path "$SRC_DIR/walker/Cargo.toml"
$SUDO install -m 0755 "$SRC_DIR/walker/target/release/walker" "$PREFIX/bin/walker"

# --- 4. validate --------------------------------------------------------------------------
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
