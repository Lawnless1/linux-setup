#!/bin/sh
# Auto display layout.
# - Docked (both DOCK_LEFT + DOCK_RIGHT connected) -> dual external, laptop off.
# - Anything else -> laptop panel only.
# Output names differ per machine/dock; override via env:
#   DOCK_LEFT, DOCK_RIGHT, LAPTOP_OUT
DOCK_RIGHT="${DOCK_RIGHT:-DP-1-9}"
DOCK_LEFT="${DOCK_LEFT:-DP-1-8}"
LAPTOP_OUT="${LAPTOP_OUT:-eDP-1}"

if xrandr | grep -q "$DOCK_RIGHT connected" && xrandr | grep -q "$DOCK_LEFT connected"; then
    "$HOME/.screenlayout/triple.sh"
else
    "$HOME/.screenlayout/laptop.sh"
fi
