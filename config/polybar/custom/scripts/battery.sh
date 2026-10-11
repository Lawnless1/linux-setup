#!/bin/bash
# Battery status for polybar. Auto-detects first BAT* under /sys/class/power_supply.

shopt -s nullglob
cands=(/sys/class/power_supply/BAT*/capacity)
[ ${#cands[@]} -eq 0 ] && exit 0
BAT_PATH=$(dirname "${cands[0]}")
capacity=$(cat "$BAT_PATH/capacity" 2>/dev/null) || exit 0
status=$(cat "$BAT_PATH/status" 2>/dev/null)

if [ "$capacity" -le 10 ]; then
    icon=""
elif [ "$capacity" -le 30 ]; then
    icon=""
elif [ "$capacity" -le 59 ]; then
    icon=""
elif [ "$capacity" -le 79 ]; then
    icon=""
else
    icon=""
fi

extra=""
if [ "$status" = "Charging" ] || [ "$status" = "Full" ]; then
    extra="󱐋 "
fi

echo "$extra$icon $capacity%"
