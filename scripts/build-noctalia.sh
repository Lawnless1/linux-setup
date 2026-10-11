#!/bin/bash
# Build + install Noctalia from source on Ubuntu 26.04+ (release mode).
#
# Why source instead of scripts/install-noctalia.sh (stock APT package)?
# Stock Noctalia publishes ONE blur rectangle for the whole bar background
# (Bar::applyBarCompositorBlur), so a transparent bar gets a full-width
# frosted band behind it. Our bar (config/noctalia/config.toml) is three
# floating capsule groups on a transparent bar and needs per-pill blur.
# This builds the local `capsule-blur-v5.2.1` branch, which adds
# `blur_region = "bar" | "capsules"` (default "bar"; see upstream issue
# noctalia-dev/noctalia#3559). On stock builds the unknown key warns and
# "bar" applies — graceful fallback.
#
# Installs to /usr/local (shadows /usr/bin/noctalia via PATH order),
# same pattern as scripts/build-fuzzel.sh.
#
# Usage:
#   ./scripts/build-noctalia.sh   # deps (sudo) -> release build -> sudo install
set -euo pipefail

SRC="$HOME/.local/src/noctalia"
BRANCH="capsule-blur-v5.2.1"

if [ ! -d "$SRC/.git" ]; then
    echo "cloning noctalia v5.2.1..."
    git clone --branch v5.2.1 https://github.com/noctalia-dev/noctalia "$SRC"
fi

if ! git -C "$SRC" rev-parse --verify --quiet "$BRANCH" >/dev/null; then
    echo "ERROR: branch '$BRANCH' missing in $SRC." >&2
    echo "It carries the local blur_region patch (see issue #3559)." >&2
    exit 1
fi
if [ "$(git -C "$SRC" branch --show-current)" != "$BRANCH" ]; then
    echo "checking out $BRANCH..."
    git -C "$SRC" checkout "$BRANCH"
fi
if ! grep -q "blur_region" "$SRC/src/shell/bar/bar.cpp"; then
    echo "ERROR: $BRANCH does not contain the blur_region patch." >&2
    exit 1
fi

echo "installing build deps (sudo)..."
sudo apt update
sudo apt install -y just meson libwayland-dev wayland-protocols \
    libfreetype-dev libfontconfig-dev libcairo2-dev libpango1.0-dev \
    librsvg2-dev libxkbcommon-dev libepoxy-dev libgles-dev libwebp-dev \
    libcurl4-gnutls-dev libmd4c-dev nlohmann-json3-dev libsdbus-c++-dev \
    libsecret-1-dev libsodium-dev libstb-dev libtomlplusplus-dev \
    libpipewire-0.3-dev libpam0g-dev libpolkit-agent-1-dev \
    libpolkit-gobject-1-dev libqalculate-dev libwireplumber-0.5-dev \
    libxml2-dev libjemalloc-dev git libglib2.0-dev libsndfile-dev \
    libjxl-dev libical-dev

echo "release build..."
(cd "$SRC" && just configure release && just build release)

echo "installing to /usr/local (sudo)..."
(cd "$SRC" && sudo just install release)

command -v noctalia
noctalia --version
