#!/bin/bash
# Build + install Noctalia from source, on any distro (release mode).
#
# Why source instead of the distro package? Stock Noctalia publishes ONE blur rectangle for the whole bar background
# (Bar::applyBarCompositorBlur), so a transparent bar gets a full-width
# frosted band behind it. Our bar (config/noctalia/config.toml) is four
# floating capsule groups on a transparent bar and needs per-pill blur.
# This builds the local `capsule-blur-v5.2.1` branch, which adds
# `blur_region = "bar" | "capsules"` (default "bar"; see upstream issue
# noctalia-dev/noctalia#3559) plus a bluetooth `show_count` option, and
# re-syncs the blur region after every layout so appearing/vanishing pills
# (media, workspace peek) gain and retract their blur islands. On stock
# builds the unknown keys warn and defaults apply — graceful fallback.
# The branch content is vendored as patches/noctalia-capsule-blur.patch so
# a fresh machine can recreate it (the branch itself is never pushed
# upstream).
#
# Installs to /usr/local (shadows a distro /usr/bin/noctalia via PATH
# order), same pattern as scripts/build-fuzzel.sh.
#
# Usage:
#   ./scripts/build-noctalia.sh   # deps (sudo) -> release build -> sudo install
set -euo pipefail

SRC="$HOME/.local/src/noctalia"
BRANCH="capsule-blur-v5.2.1"

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/pkg.sh
. "$REPO_DIR/scripts/lib/pkg.sh"
PATCH="$REPO_DIR/patches/noctalia-capsule-blur.patch"

pkg_install build-base build-noctalia

if [ ! -d "$SRC/.git" ]; then
    echo "cloning noctalia v5.2.1..."
    git clone --branch v5.2.1 https://github.com/noctalia-dev/noctalia "$SRC"
fi

if ! git -C "$SRC" rev-parse --verify --quiet "$BRANCH" >/dev/null; then
    echo "recreating $BRANCH from v5.2.1 + $PATCH..."
    git -C "$SRC" checkout -b "$BRANCH" v5.2.1
    git -C "$SRC" apply "$PATCH"
    git -C "$SRC" add -A
    # Fixed identity: a fresh machine has no git user configured yet.
    git -C "$SRC" -c user.name=linux-setup -c user.email=linux-setup@localhost commit -q -m "feat(bar): per-capsule compositor blur regions (vendored)"
fi
if [ "$(git -C "$SRC" branch --show-current)" != "$BRANCH" ]; then
    echo "checking out $BRANCH..."
    git -C "$SRC" checkout "$BRANCH"
fi
if ! grep -q "blurRegion" "$SRC/src/shell/bar/bar.cpp"; then
    echo "ERROR: $BRANCH does not contain the blur_region patch." >&2
    exit 1
fi

echo "release build..."
(cd "$SRC" && just configure release && just build release)

echo "installing to /usr/local (sudo)..."
(cd "$SRC" && sudo just install release)

command -v noctalia
noctalia --version || true
