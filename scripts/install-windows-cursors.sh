#!/bin/bash
# Install the Windows 10 cursor theme (wincursors), any distro.
#
# Upstream: https://github.com/rushiiMachine/wincursors (prebuilt xcursor +
# shape aliases, installed as ~/.local/share/icons/wincursors). Replaces the
# DMZ-White approximation with the real Windows 10 look.
#
# Why a script instead of vendored files: the theme is ~1.2MB of binary
# Xcursor files — data, not config — so install.sh-style it is fetched once
# and lives outside git (same philosophy as the wallpaper copy).
#
# Coverage (so no app falls back to a mismatched set):
#   - ~/.local/share/icons/wincursors  (the theme itself)
#   - hand -> hand2 alias (legacy name upstream omits)
#   - Inherits=Adwaita safety net in index.theme (never a broken cursor)
#   - ~/.icons/default/index.theme     (catches apps ignoring everything else)
#   - gsettings cursor-theme/size      (native Wayland GTK apps)
# The niri config (config.kdl: cursor{} + environment{} XCURSOR_* variables)
# points every client at this theme.
#
# Usage: ./scripts/install-windows-cursors.sh   (idempotent, safe to re-run)
set -euo pipefail

THEME="wincursors"
DEST="$HOME/.local/share/icons/$THEME"
ZIP_URL="https://github.com/rushiiMachine/wincursors/releases/latest/download/wincursors.zip"

log() { printf '==> %s\n' "$*"; }

command -v curl >/dev/null 2>&1 || { log "need curl"; exit 1; }
command -v unzip >/dev/null 2>&1 || { log "need unzip (install it with your package manager)"; exit 1; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
log "downloading $THEME..."
curl -fL -o "$tmp/wincursors.zip" "$ZIP_URL"

log "extracting to $DEST..."
mkdir -p "$HOME/.local/share/icons"
rm -rf "$DEST"
unzip -o -q "$tmp/wincursors.zip" -d "$tmp/extract"
mv "$tmp/extract/$THEME" "$DEST"

count=$(ls "$DEST/cursors" | wc -l)
[ "$count" -ge 130 ] || { log "refusing: only $count cursors (expected >= 130)"; exit 1; }
log "theme has $count cursors"

# Legacy alias upstream omits (old X11 apps ask for "hand", not "hand2").
if [ ! -e "$DEST/cursors/hand" ]; then
    ln -s hand2 "$DEST/cursors/hand"
    log "added hand -> hand2 alias"
fi

# Safety net: any name truly missing resolves to Adwaita, never a broken glyph.
if ! grep -q "^Inherits=" "$DEST/index.theme" 2>/dev/null; then
    printf 'Inherits=Adwaita\n' >> "$DEST/index.theme"
    log "added Inherits=Adwaita fallback"
fi

# Catch-all for apps that ignore theme settings entirely.
mkdir -p "$HOME/.icons/default"
printf '[Icon Theme]\nInherits=%s\n' "$THEME" > "$HOME/.icons/default/index.theme"
log "wrote ~/.icons/default fallback"

# Native Wayland GTK apps read the settings portal -> gsettings.
if command -v gsettings >/dev/null 2>&1; then
    gsettings set org.gnome.desktop.interface cursor-theme "$THEME" || true
    gsettings set org.gnome.desktop.interface cursor-size 32 || true
    log "gsettings cursor-theme=$THEME size=32"
else
    log "(skip: gsettings missing)"
fi

log "done. Log out/in for every running app to pick it up (cursors are cached per-process)."
