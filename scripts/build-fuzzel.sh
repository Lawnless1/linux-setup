#!/bin/bash
# Build + install fuzzel 1.12.0 with the pill patch, on any distro.
#
# Built from source everywhere (even where the distro packages fuzzel)
# because scripts/fuzzel-pill.patch targets 1.12.0: it makes the omnibar a
# true expanding pill (empty = prompt row only). Installs to /usr/local/bin,
# which shadows a distro /usr/bin/fuzzel via PATH order.
#
# Usage:
#   ./scripts/build-fuzzel.sh                 # build 1.12.0 to /usr/local
#   FUZZEL_TAG=1.12.0 ./scripts/build-fuzzel.sh  # explicit tag (to retry/verify)
#   PREFIX=$HOME/.local ./scripts/build-fuzzel.sh  # user-local install
#
# Steps: build deps (sudo) -> clone/update sources under ~/.local/src ->
# meson setup -> ninja -> install -> validation (version + config load).
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/pkg.sh
. "$REPO_DIR/scripts/lib/pkg.sh"

PREFIX="${PREFIX:-/usr/local}"
SRC_DIR="${SRC_DIR:-$HOME/.local/src}"
FUZZEL_REPO="https://codeberg.org/dnkl/fuzzel.git"
FUZZEL_TAG="${FUZZEL_TAG:-1.12.0}"

# --- 1. build dependencies -------------------------------------------------------
pkg_install build-base build-fuzzel

# --- 2. sources (pinned tag: the pill patch targets 1.12.0) ---------------------
mkdir -p "$SRC_DIR"
if [ -d "$SRC_DIR/fuzzel/.git" ]; then
    log "updating fuzzel sources..."
    git -C "$SRC_DIR/fuzzel" fetch --tags origin
else
    log "cloning fuzzel sources..."
    git clone "$FUZZEL_REPO" "$SRC_DIR/fuzzel"
    git -C "$SRC_DIR/fuzzel" fetch --tags origin
fi
log "checking out fuzzel $FUZZEL_TAG"
git -C "$SRC_DIR/fuzzel" checkout -q "$FUZZEL_TAG"

# --- 2b. pill patch: true expanding pill (empty = prompt row only).
# Upstream 1.12 reserves lines*row_height always and latches
# hide-before-typing off after the first keystroke; the patch (kept in
# git) makes the window grow/shrink with the list instead.
if [ "$FUZZEL_TAG" = "1.12.0" ]; then
    log "applying pill patch..."
    git -C "$SRC_DIR/fuzzel" checkout -q "$FUZZEL_TAG" -- render.c render.h wayland.c
    git -C "$SRC_DIR/fuzzel" apply "$REPO_DIR/scripts/fuzzel-pill.patch"
else
    log "WARNING: pill patch targets 1.12.0, skipping for $FUZZEL_TAG"
    log "         (empty state will be a fixed-height box, not a slim pill)"
fi

# --- 3. build ----------------------------------------------------------------------
log "configuring fuzzel $FUZZEL_TAG..."
# meson setup [options] <builddir> <srcdir>
if [ -d "$SRC_DIR/fuzzel/build" ]; then
    meson setup --wipe "$SRC_DIR/fuzzel/build" "$SRC_DIR/fuzzel" \
        --prefix="$PREFIX" --buildtype=release
else
    meson setup "$SRC_DIR/fuzzel/build" "$SRC_DIR/fuzzel" \
        --prefix="$PREFIX" --buildtype=release
fi
log "compiling fuzzel $FUZZEL_TAG..."
ninja -C "$SRC_DIR/fuzzel/build"

# --- 4. install (shadows a distro fuzzel via PATH: /usr/local/bin wins) ------------
log "installing fuzzel to $PREFIX/bin..."
if [ -w "$(dirname "$PREFIX/bin")" ]; then SUDO=; else SUDO=sudo; log "need sudo for $PREFIX/bin"; fi
# shellcheck disable=SC2086
$SUDO ninja -C "$SRC_DIR/fuzzel/build" install 2>/dev/null || \
    { # shellcheck disable=SC2086
      $SUDO meson install -C "$SRC_DIR/fuzzel/build"; }

# --- 5. validate ----------------------------------------------------------------------
log "validating..."
"$PREFIX/bin/fuzzel" --version
echo "resolver order: $(which -a fuzzel | tr '\n' ' ')"
[ "$(command -v fuzzel)" = "$PREFIX/bin/fuzzel" ] \
    || log "WARNING: $PREFIX/bin/fuzzel does not shadow $(command -v fuzzel) — check PATH order"
# Loading the config opens a window, so it needs a running Wayland
# session; a fresh install runs this from a TTY.
if [ -z "${WAYLAND_DISPLAY:-}" ]; then
    log "no Wayland session: skipping config load check (scripts/check.sh covers the version)"
    log "done. Sources: $SRC_DIR/fuzzel."
    exit 0
fi
log "loading repo config..."
set +e
timeout 2 "$PREFIX/bin/fuzzel" --config "$REPO_DIR/config/fuzzel/fuzzel.ini" >/dev/null 2>&1
rc=$?
set -e
if [ "$rc" -eq 124 ]; then
    log "repo config loads clean (fuzzel ran until timeout killed it)"
else
    log "CONFIG REJECTED (exit $rc)"
    exit 1
fi

log "done. Sources: $SRC_DIR/fuzzel. Super+Space picks up the new binary immediately."
