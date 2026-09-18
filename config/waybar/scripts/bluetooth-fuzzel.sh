#!/usr/bin/env bash
# Bluetooth quick connect/disconnect for waybar (niri session).
# Click the waybar bluetooth module -> fuzzel menu listing paired/known
# devices with connection state. Pick one to toggle connect/disconnect.
# Right-click the module -> power toggle (via --toggle-power).
# Deps: fuzzel, bluetoothctl, notify-send (libnotify-bin), rfkill.
set -u

FUZZEL="${FUZZEL:-$(command -v fuzzel)}"
[ -n "$FUZZEL" ] || { echo "fuzzel not found" >&2; exit 1; }
command -v bluetoothctl >/dev/null 2>&1 || { notify-send "Bluetooth" "bluetoothctl not found (apt: bluez)" 2>/dev/null; exit 1; }

notify() { command -v notify-send >/dev/null 2>&1 && notify-send "Bluetooth" "$1" || true; }

power_on() { bluetoothctl show 2>/dev/null | grep -q "Powered: yes"; }

toggle_power() {
    if power_on; then
        bluetoothctl power off >/dev/null 2>&1
        notify "Bluetooth off"
    else
        rfkill list bluetooth 2>/dev/null | grep -q 'blocked: yes' && rfkill unblock bluetooth 2>/dev/null && sleep 1
        bluetoothctl power on >/dev/null 2>&1
        notify "Bluetooth on"
    fi
}

device_connected() { bluetoothctl info "$1" 2>/dev/null | grep -q "Connected: yes"; }

toggle_connection() {
    mac="$1"
    name="$2"
    if device_connected "$mac"; then
        if bluetoothctl disconnect "$mac" >/dev/null 2>&1; then
            notify "Disconnected $name"
        else
            notify "Failed to disconnect $name"
        fi
    else
        if bluetoothctl connect "$mac" >/dev/null 2>&1; then
            notify "Connected $name"
        else
            notify "Failed to connect $name (device may be off)"
        fi
    fi
}

# Right-click fast path: power toggle, no menu.
if [ "${1:-}" = "--toggle-power" ]; then
    toggle_power
    exit 0
fi

if ! power_on; then
    choice=$(printf '%s\n' "Power: OFF — turn on" | "$FUZZEL" --dmenu --prompt "Bluetooth: ") || exit 0
    case "$choice" in
        "Power"*) toggle_power ;;
    esac
    exit 0
fi

# Build menu: "● name" (connected) / "○ name" (disconnected), plus actions.
# MACs kept in a parallel lookup via bluetoothctl output.
tmpmap=$(mktemp)
trap 'rm -f "$tmpmap"' EXIT

menu=""
while IFS= read -r line; do
    # line: "Device MAC Name..."
    mac=$(printf '%s' "$line" | awk '{print $2}')
    name=$(printf '%s' "$line" | cut -d ' ' -f 3-)
    [ -n "$mac" ] || continue
    printf '%s\t%s\n' "$name" "$mac" >>"$tmpmap"
    if device_connected "$mac"; then
        menu="${menu}● ${name}
"
    else
        menu="${menu}○ ${name}
"
    fi
done < <(bluetoothctl devices 2>/dev/null | grep "^Device ")

menu="${menu}Rescan (5s)
Power: ON — turn off"

choice=$(printf '%s' "$menu" | "$FUZZEL" --dmenu --prompt "Bluetooth: ") || exit 0
[ -n "${choice:-}" ] || exit 0

case "$choice" in
    "Rescan"*)
        notify "Scanning for 5s..."
        bluetoothctl --timeout 5 scan on >/dev/null 2>&1
        exec "$0"
        ;;
    "Power"*)
        toggle_power
        ;;
    "● "*|"○ "*)
        name="${choice#? }"
        mac=$(awk -F '\t' -v n="$name" '$1==n {print $2; exit}' "$tmpmap")
        if [ -z "$mac" ]; then
            # Fallback: resolve by exact device line match.
            mac=$(bluetoothctl devices 2>/dev/null | grep -F " $name" | awk '{print $2}' | head -n 1)
        fi
        [ -n "$mac" ] && toggle_connection "$mac" "$name" || notify "Could not resolve $name"
        ;;
esac
