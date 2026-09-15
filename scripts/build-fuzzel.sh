#!/bin/bash
# Build + install fuzzel from source on Ubuntu 24.04.
#
# Noble ships fuzzel 1.9.2, which lacks the omnibar options our config uses
# (placeholder, match-counter, anchor, x/y-margin, list-executables-in-path,
# prompt/input colors — all new in 1.11/1.12). This builds the newest release
# that still compiles against noble's system libraries and installs it to
# /usr/local/bin, which shadows /usr/bin/fuzzel via PATH order.
#
# Pinned to 1.12.0 on purpose: 1.13+ needs wayland-protocols >= 1.41 AND
# fcft >= 3.3.1 (noble has fcft 3.1.8), so it won't configure without also
# building those from source. Re-check on the next LTS.
#
# Usage:
#   ./scripts/build-fuzzel.sh                 # build 1.12.0 to /usr/local
#   FUZZEL_TAG=1.12.0 ./scripts/build-fuzzel.sh  # explicit tag (to retry/verify)
#   PREFIX=$HOME/.local ./scripts/build-fuzzel.sh  # user-local install
#
# Steps: apt build deps (sudo) -> clone/update sources under ~/.local/src ->
# meson setup -> ninja -> install -> validation (version + config load).
set -euo pipefail

PREFIX="${PREFIX:-/usr/local}"
SRC_DIR="${SRC_DIR:-$HOME/.local/src}"
FUZZEL_REPO="https://codeberg.org/dnkl/fuzzel.git"
FUZZEL_TAG="${FUZZEL_TAG:-1.12.0}"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

log() { printf '==> %s\n' "$*"; }

# --- 1. build dependencies -------------------------------------------------------
BUILD_DEPS="meson ninja-build scdoc pkg-config git curl wayland-protocols
    libwayland-dev libxkbcommon-dev libfcft-dev libpixman-1-dev libcairo2-dev
    libpng-dev libfontconfig-dev"
# shellcheck disable=SC2086
if ! dpkg -s $BUILD_DEPS >/dev/null 2>&1; then
    log "installing fuzzel build dependencies (sudo)..."
    # NOTE: NOT `apt update && apt install`: with `set -e`, a failed update
    # inside an &&-list silently skips the install instead of aborting.
    sudo apt update || { log "apt update FAILED — fix broken sources (see /etc/apt/sources.list.d/) and re-run"; exit 1; }
    # shellcheck disable=SC2086
    sudo apt install -y $BUILD_DEPS
else
    log "build dependencies already present"
fi

# --- 2. sources (pinned tag; 1.13+ won't configure on noble — see header) --------
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

# --- 4. install (shadows apt 1.9.2 via PATH: /usr/local/bin wins) ------------------
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
