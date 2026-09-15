#!/bin/sh
# waybar launcher — kills stale bars, then starts a single instance.
# (Without this, a leftover waybar from a previous login stacks a second bar
# under the one niri spawns at startup.)
# Config: ~/.config/waybar/config.jsonc + style.css

# Terminate already running bar instances
killall -q waybar

# Wait until the processes have been shut down
while pgrep -x waybar >/dev/null; do sleep 0.2; done

# Launch the bar
exec waybar
