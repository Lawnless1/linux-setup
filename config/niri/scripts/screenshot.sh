#!/usr/bin/env bash
# Area screenshot for the $mod+Shift+s niri binding.
# Wayland replacement for `flameshot gui -c -s`: select a region with slurp,
# capture with grim, save to ~/Pictures/Screenshots/ and copy to clipboard.
# Requires: slurp, grim, wl-clipboard. Cancelling the selection is silent.
set -u

SHOT_DIR="$HOME/Pictures/Screenshots"
mkdir -p "$SHOT_DIR"
SHOT="$SHOT_DIR/Screenshot from $(date '+%Y-%m-%d %H-%M-%S').png"

GEOM=$(slurp) || exit 0
[ -z "$GEOM" ] && exit 0

grim -g "$GEOM" "$SHOT" || exit 0
wl-copy < "$SHOT"
notify-send "Screenshot saved" "$SHOT" 2>/dev/null || true
