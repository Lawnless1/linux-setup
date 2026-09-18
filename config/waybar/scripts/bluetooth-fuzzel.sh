#!/usr/bin/env bash
# Bluetooth quick connect/disconnect/pair for waybar (niri session).
# Click the waybar bluetooth module -> fuzzel menu listing known devices
# with connection state. Pick one to toggle connect/disconnect, or pick
# "Pair new device..." to discover + pair + trust + connect.
# Right-click the module -> power toggle (via --toggle-power).
# Deps: fuzzel, bluetoothctl, notify-send (libnotify-bin), rfkill, timeout.
set -u

FUZZEL="${FUZZEL:-$(command -v fuzzel)}"
[ -n "$FUZZEL" ] || { echo "fuzzel not found" >&2; exit 1; }
command -v bluetoothctl >/dev/null 2>&1 || { notify-send "Bluetooth" "bluetoothctl not found (apt: bluez)" 2>/dev/null; exit 1; }

# Dmenu theme with the option list visible from the start. The omnibar
# fuzzel.ini sets hide-before-typing=yes (bare pill until first keystroke),
# which fuzzel's CLI cannot negate — so dmenu menus use their own config.
DMENU_INI="$HOME/.config/fuzzel/fuzzel-dmenu.ini"
if [ -f "$DMENU_INI" ]; then
    MENU=( "$FUZZEL" --config "$DMENU_INI" --dmenu )
else
    MENU=( "$FUZZEL" --dmenu )
fi

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
device_paired() { bluetoothctl info "$1" 2>/dev/null | grep -q "Paired: yes"; }

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

pair_new_device() {
    notify "Put the device in pairing mode — scanning 10s..."
    bluetoothctl --timeout 10 scan on >/dev/null 2>&1
    local tmpmap menu line mac name choice
    tmpmap=$(mktemp)
    menu=""
    while IFS= read -r line; do
        # line: "Device MAC Name..."
        mac=$(printf '%s' "$line" | awk '{print $2}')
        name=$(printf '%s' "$line" | cut -d ' ' -f 3-)
        [ -n "$mac" ] || continue
        device_paired "$mac" && continue
        printf '%s\t%s\n' "$name" "$mac" >>"$tmpmap"
        menu="${menu}＋ ${name}
"
    done < <(bluetoothctl devices 2>/dev/null | grep "^Device ")
    if [ -z "$menu" ]; then
        rm -f "$tmpmap"
        notify "No new devices found — keep it in pairing mode and retry"
        return 0
    fi
    choice=$("${MENU[@]}" --prompt "Pair: " <<<"$menu") || { rm -f "$tmpmap"; return 0; }
    [ -n "${choice:-}" ] || { rm -f "$tmpmap"; return 0; }
    name="${choice#＋ }"
    mac=$(awk -F '\t' -v n="$name" '$1==n {print $2; exit}' "$tmpmap")
    if [ -z "$mac" ]; then
        mac=$(bluetoothctl devices 2>/dev/null | grep -F " $name" | awk '{print $2}' | head -n 1)
    fi
    rm -f "$tmpmap"
    [ -n "$mac" ] || { notify "Could not resolve $name"; return 0; }
    notify "Pairing $name..."
    if timeout 30 bluetoothctl pair "$mac" >/dev/null 2>&1; then
        bluetoothctl trust "$mac" >/dev/null 2>&1
        if bluetoothctl connect "$mac" >/dev/null 2>&1; then
            notify "Paired + connected $name"
        else
            notify "Paired $name (connect failed — pick it from the menu)"
        fi
    else
        notify "Pairing $name failed — retry, or pair interactively via bluetoothctl"
    fi
}

# Right-click fast path: power toggle, no menu.
if [ "${1:-}" = "--toggle-power" ]; then
    toggle_power
    exit 0
fi

if ! power_on; then
    choice=$(printf '%s\n' "Power: OFF — turn on" | "${MENU[@]}" --prompt "Bluetooth: ") || exit 0
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

menu="${menu}＋ Pair new device...
Rescan (5s)
Power: ON — turn off"

choice=$(printf '%s' "$menu" | "${MENU[@]}" --prompt "Bluetooth: ") || exit 0
[ -n "${choice:-}" ] || exit 0

case "$choice" in
    "＋ Pair"*)
        pair_new_device
        exec "$0"
        ;;
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
