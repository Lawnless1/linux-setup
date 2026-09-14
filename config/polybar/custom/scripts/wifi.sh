#!/bin/bash
# Wi-Fi status icon for polybar. No hard-coded interface: auto-detects wireless dev.
# Deps: iw

IFACE=$(iw dev 2>/dev/null | awk '$1=="Interface"{print $2; exit}')
[ -z "$IFACE" ] && { echo "󰤮"; exit 0; }

# Get current SSID
ssid=$(iw dev "$IFACE" link 2>/dev/null | awk -F': ' '/SSID/{print $2}')

# Get signal strength (0-100)
signal=$(iw dev "$IFACE" link 2>/dev/null | awk '/signal:/ {
s=$2;
    if (s >= -50) p=100;
    else if (s <= -100) p=0;
    else p=int((s + 100) * 2);
    print p;
}')

# Choose icon
if [ -z "$ssid" ]; then
    icon="󰤮"
else
    if (( signal > 85 )); then
        icon="󰤨"
    elif (( signal > 50 )); then
        icon="󰤥"
    elif (( signal > 25 )); then
        icon="󰤟"
    else
        icon="󰤯"
    fi
fi

echo "$icon"
