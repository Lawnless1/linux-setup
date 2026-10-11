#!/bin/bash
# Install Noctalia (bar shell) on Ubuntu 26.04+ via the upstream APT repo.
#
# Noctalia has no Ubuntu 24.04 build (upstream ships Debian trixie/sid and
# Ubuntu 26.04 "resolute" only), so this script refuses on older releases —
# on noble, stay on waybar (config/waybar, dormant-ready) instead.
#
# Idempotent: skips everything if `noctalia` is already on PATH.
#
# Usage:
#   ./scripts/install-noctalia.sh   # called by ./install.sh --with-niri
set -euo pipefail

CODENAME="$(lsb_release -cs 2>/dev/null || echo unknown)"

if command -v noctalia >/dev/null 2>&1; then
    echo "noctalia already installed ($(noctalia --version 2>/dev/null || echo unknown)) — skipping"
    exit 0
fi

case "$CODENAME" in
    resolute|trixie|sid|forky)
        REPO="$CODENAME"
        ;;
    *)
        echo "ERROR: no Noctalia APT repo for '$CODENAME' (need Ubuntu 26.04+/Debian trixie+)." >&2
        echo "Stay on waybar until you upgrade." >&2
        exit 1
        ;;
esac

echo "installing noctalia APT repo (noctalia-$REPO)..."
wget -q https://pkg.noctalia.dev/deb/nickh-archive-keyring.deb -O /tmp/nickh-archive-keyring.deb
sudo dpkg -i /tmp/nickh-archive-keyring.deb
sudo wget -q -O /etc/apt/sources.list.d/noctalia-"$REPO".sources \
    https://pkg.noctalia.dev/deb/noctalia-"$REPO".sources
sudo apt update
sudo apt install -y noctalia
command -v noctalia
noctalia --version
