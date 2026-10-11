#!/bin/bash
# Battery detail menu. Uses sysfs (no acpi dep); falls back to `acpi -b` if present.

theme=$HOME/.config/polybar/custom/scripts/rofi_themes/battery.rasi

shopt -s nullglob
cands=(/sys/class/power_supply/BAT*/capacity)
if [ ${#cands[@]} -gt 0 ]; then
    BAT_PATH=$(dirname "${cands[0]}")
    percentage="$(cat "$BAT_PATH/capacity" 2>/dev/null)%"
    status="$(cat "$BAT_PATH/status" 2>/dev/null)"
else
    acpi_output=$(acpi -b 2>/dev/null)
    [ -z "$acpi_output" ] && exit 0
    status=$(echo "$acpi_output" | awk -F', ' '{print $1}' | awk '{print $3}')
    percentage=$(echo "$acpi_output" | awk -F', ' '{print $2}')
fi

# Prepare time info if discharging (via acpi when available)
time_output=""
if [[ "$status" == "Discharging" ]] && command -v acpi >/dev/null 2>&1; then
    raw_time=$(acpi -b | awk -F', ' '{print $3}')
    hours=$(echo "$raw_time" | cut -d: -f1 | sed 's/^0*//')
    minutes=$(echo "$raw_time" | cut -d: -f2 | sed 's/^0*//')
    hours=${hours:-0}
    minutes=${minutes:-0}
    time_output=" Remaining: ${hours} hours, ${minutes} minutes"
elif [[ "$status" != "Discharging" ]]; then
    theme=$HOME/.config/polybar/custom/scripts/rofi_themes/battery_charging.rasi
fi

options="$(~/.config/polybar/custom/scripts/battery.sh) $percentage ($status)"
if [[ -n "$time_output" ]]; then
    options="$options\n$time_output"
fi

echo -e "$options" | rofi -dmenu -p "Battery" -theme "$theme"
