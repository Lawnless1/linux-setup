#!/usr/bin/env bash
# Wi-Fi manager for waybar (niri session).
# Click the waybar network (wifi) module -> fuzzel menu covering the
# day-to-day nmtui operations without leaving Wayland:
#   - change/switch network (visible APs, strongest-first, active marked ●)
#   - join new network (password prompt for WPA-PSK, open networks direct)
#   - add hidden network (SSID + optional password)
#   - disconnect current, forget (delete) saved networks
#   - rescan, toggle Wi-Fi radio, show details (IP/signal)
#   - full editors as fallback: nmtui in foot, nm-connection-editor
# Right-click the module -> radio toggle (via --toggle-wifi).
# Deps: fuzzel, nmcli (network-manager), notify-send (libnotify-bin),
# foot (for nmtui fallback; any $TERMINAL works if foot is missing).
set -u

FUZZEL="${FUZZEL:-$(command -v fuzzel)}"
[ -n "$FUZZEL" ] || { echo "fuzzel not found" >&2; exit 1; }
command -v nmcli >/dev/null 2>&1 || { echo "nmcli not found (apt: network-manager)" >&2; exit 1; }

# Dmenu theme with the option list visible from the start. The omnibar
# fuzzel.ini sets hide-before-typing=yes (bare pill until first keystroke),
# which fuzzel's CLI cannot negate — so dmenu menus use their own config.
DMENU_INI="$HOME/.config/fuzzel/fuzzel-dmenu.ini"
if [ -f "$DMENU_INI" ]; then
    MENU=( "$FUZZEL" --config "$DMENU_INI" --dmenu )
    ASK=( "$FUZZEL" --config "$DMENU_INI" --dmenu --prompt-only )
    ASKPASS=( "$FUZZEL" --config "$DMENU_INI" --dmenu --prompt-only --password )
else
    MENU=( "$FUZZEL" --dmenu )
    ASK=( "$FUZZEL" --dmenu --prompt-only )
    ASKPASS=( "$FUZZEL" --dmenu --prompt-only --password )
fi

notify() { command -v notify-send >/dev/null 2>&1 && notify-send "Wi-Fi" "$1" || true; }

wifi_iface() {
    nmcli -t -f DEVICE,TYPE device status 2>/dev/null \
        | awk -F: '$2=="wifi" {print $1; exit}'
}

wifi_enabled() { [ "$(nmcli radio wifi 2>/dev/null)" = "enabled" ]; }

toggle_wifi() {
    if wifi_enabled; then
        nmcli radio wifi off >/dev/null 2>&1
        notify "Wi-Fi off"
    else
        nmcli radio wifi on >/dev/null 2>&1
        notify "Wi-Fi on — scanning..."
        nmcli device wifi rescan >/dev/null 2>&1 || true
    fi
}

current_ssid() {
    nmcli -t -f ACTIVE,SSID device wifi list --rescan no 2>/dev/null \
        | grep '^yes:' | cut -d: -f2- | sed 's/\\:/:/g' | head -n 1
}

# Saved connection profile id matching an SSID (first match), if any.
saved_conn_for_ssid() {
    local ssid="$1"
    nmcli -t -f NAME,TYPE connection show 2>/dev/null \
        | grep ':802-11-wireless$' | cut -d: -f1 | sed 's/\\:/:/g' \
        | grep -Fx -- "$ssid" | head -n 1
}

ask_text() { "${ASK[@]}" --prompt "${1:-Input: }" 2>/dev/null || true; }
ask_pass() { "${ASKPASS[@]}" --prompt "${1:-Password: }" 2>/dev/null || true; }

connect_ssid() {
    local ssid="$1" sec="$2" saved psk
    saved="$(saved_conn_for_ssid "$ssid")"
    if [ -n "$saved" ]; then
        if nmcli connection up id "$saved" >/dev/null 2>&1; then
            notify "Connected to $ssid"
        else
            notify "Failed to bring up $ssid"
        fi
        return 0
    fi
    case "${sec:-}" in
        *802.1X*|*WPA-EAP*|*EAP*)
            notify "$ssid needs enterprise (EAP) credentials — opening nmtui to add it"
            open_nmtui
            return 0
            ;;
    esac
    if [ -z "${sec:-}" ] || [ "$sec" = "--" ]; then
        if nmcli device wifi connect "$ssid" >/dev/null 2>&1; then
            notify "Connected to $ssid"
        else
            notify "Failed to connect to $ssid"
        fi
        return 0
    fi
    psk="$(ask_pass "Password for $ssid: ")"
    [ -n "${psk:-}" ] || return 0
    if nmcli device wifi connect "$ssid" password "$psk" >/dev/null 2>&1; then
        notify "Connected to $ssid"
    else
        notify "Failed to connect to $ssid (wrong password?)"
    fi
}

disconnect_current() {
    local cur active_id
    cur="$(current_ssid)"
    active_id="$(nmcli -t -f NAME,TYPE connection show --active 2>/dev/null \
        | grep ':802-11-wireless$' | cut -d: -f1 | sed 's/\\:/:/g' | head -n 1)"
    if [ -n "$active_id" ] && nmcli connection down id "$active_id" >/dev/null 2>&1; then
        notify "Disconnected ${cur:-$active_id}"
    else
        local iface
        iface="$(wifi_iface)"
        if [ -n "${iface:-}" ] && nmcli device disconnect "$iface" >/dev/null 2>&1; then
            notify "Disconnected ${cur:-$iface}"
        else
            notify "Nothing to disconnect"
        fi
    fi
}

add_hidden() {
    local ssid psk
    ssid="$(ask_text "Hidden SSID: ")"
    [ -n "${ssid:-}" ] || return 0
    if saved_conn_for_ssid "$ssid" >/dev/null; then
        connect_ssid "$ssid" ""
        return 0
    fi
    psk="$(ask_pass "Password for $ssid (empty = open): ")"
    if [ -z "${psk:-}" ]; then
        if nmcli device wifi connect "$ssid" hidden yes >/dev/null 2>&1; then
            notify "Connected to $ssid"
        else
            notify "Failed to join $ssid"
        fi
    else
        if nmcli device wifi connect "$ssid" password "$psk" hidden yes >/dev/null 2>&1; then
            notify "Connected to $ssid"
        else
            notify "Failed to join $ssid (wrong password?)"
        fi
    fi
}

forget_menu() {
    local list choice
    list="$(nmcli -t -f NAME,TYPE connection show 2>/dev/null \
        | grep ':802-11-wireless$' | cut -d: -f1 | sed 's/\\:/:/g' | sort -f)"
    [ -n "$list" ] || { notify "No saved Wi-Fi networks"; return 0; }
    choice=$(printf '%s\n' "$list" | "${MENU[@]}" --prompt "Forget: ") || return 0
    [ -n "${choice:-}" ] || return 0
    if nmcli connection delete id "$choice" >/dev/null 2>&1; then
        notify "Forgot $choice"
    else
        notify "Failed to forget $choice"
    fi
}

saved_menu() {
    local list choice
    list="$(nmcli -t -f NAME,TYPE connection show 2>/dev/null \
        | grep ':802-11-wireless$' | cut -d: -f1 | sed 's/\\:/:/g' | sort -f)"
    [ -n "$list" ] || { notify "No saved Wi-Fi networks"; return 0; }
    choice=$(printf '%s\n' "$list" | "${MENU[@]}" --prompt "Saved: ") || return 0
    [ -n "${choice:-}" ] || return 0
    if nmcli connection up id "$choice" >/dev/null 2>&1; then
        notify "Connected to $choice"
    else
        notify "Failed to connect to $choice (out of range?)"
    fi
}

show_details() {
    local cur iface info ip sig
    cur="$(current_ssid)"
    iface="$(wifi_iface)"
    ip="$(nmcli -t -f IP4.ADDRESS device show "${iface:-wlan0}" 2>/dev/null | head -n 1 | cut -d: -f2-)"
    sig="$(nmcli -t -f ACTIVE,SIGNAL device wifi list --rescan no 2>/dev/null \
        | grep '^yes:' | cut -d: -f2 | head -n 1)"
    info="${cur:-offline}"
    [ -n "${sig:-}" ] && info="$info (${sig}% signal)"
    [ -n "${ip:-}" ] && info="$info — $ip"
    notify "$info"
}

open_nmtui() {
    local term=( foot -e )
    if ! command -v foot >/dev/null 2>&1; then
        if [ -n "${TERMINAL:-}" ]; then
            # shellcheck disable=SC2206
            term=( ${TERMINAL} )
        elif command -v x-terminal-emulator >/dev/null 2>&1; then
            term=( x-terminal-emulator -e )
        fi
    fi
    if command -v nmtui >/dev/null 2>&1; then
        "${term[@]}" nmtui >/dev/null 2>&1 &
    else
        notify "nmtui not found (apt: network-manager)"
    fi
}

open_adv_editor() {
    if command -v nm-connection-editor >/dev/null 2>&1; then
        nm-connection-editor >/dev/null 2>&1 &
    else
        notify "nm-connection-editor not found (apt: network-manager-gnome)"
    fi
}

usage() {
    cat <<'EOF'
Usage: wifi-fuzzel.sh [--toggle-wifi] [--help]
Waybar wifi-click menu (fuzzel + nmcli, covers nmtui day-to-day ops).
  (no args)      show the network picker menu
  --toggle-wifi  toggle the Wi-Fi radio (waybar on-click-right)
  --help         this text
EOF
}

# Right-click fast path: radio toggle, no menu.
if [ "${1:-}" = "--toggle-wifi" ]; then
    toggle_wifi
    exit 0
fi
if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    usage
    exit 0
fi

# Radio off: short menu, no scan (scan would fail while disabled).
if ! wifi_enabled; then
    choice=$(printf '%s\n' "Power: OFF — turn on" "Edit connections (nmtui)…" \
        | "${MENU[@]}" --prompt "Wi-Fi off: ") || exit 0
    case "${choice:-}" in
        "Power"*) toggle_wifi ;;
        "Edit"*) open_nmtui ;;
    esac
    exit 0
fi

# Kick off a background rescan so the list is fresh; show cached results now.
nmcli device wifi rescan >/dev/null 2>&1 || true

# Build AP menu: "● ssid 74% 🔒" (active) / "○ ssid 60%" rows, deduped by
# SSID keeping the strongest signal. terse ':' inside SSIDs is backslash-
# escaped by nmcli, so parse with a placeholder first.
tmpmap=$(mktemp)
tmpmenu=$(mktemp)
trap 'rm -f "$tmpmap" "$tmpmenu"' EXIT
declare -A seen_sig=()
declare -A seen_sec=()
declare -A seen_active=()
while IFS= read -r line; do
    [ -n "$line" ] || continue
    esc="${line//\\:/__COLON__}"
    active="${esc%%:*}"
    remainder="${esc#*:}"
    # remainder = "SSID:SIGNAL:SECURITY" (SECURITY has no colons; may be empty)
    sec="${remainder##*:}"
    middle="${remainder%:*}"
    sig="${middle##*:}"
    ssid_esc="${middle%:*}"
    ssid="${ssid_esc//__COLON__/":"}"
    [ -n "$ssid" ] || continue
    [[ "$sig" =~ ^[0-9]+$ ]] || continue
    prev="${seen_sig[$ssid]:-}"
    if [ -z "$prev" ] || [ "$sig" -gt "$prev" ]; then
        seen_sig["$ssid"]="$sig"
        seen_sec["$ssid"]="$sec"
    fi
    [ "$active" = "*" ] && seen_active["$ssid"]=1
done < <(nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY device wifi list --rescan no 2>/dev/null)

menu=""
cur=""
for ssid in "${!seen_sig[@]}"; do
    sig="${seen_sig[$ssid]}"
    sec="${seen_sec[$ssid]}"
    lock=""
    case "$sec" in
        *WPA*|*WEP*|*802.1X*|*EAP*|*SAE*|*OWE*) lock=" 🔒" ;;
    esac
    printf '%s\t%s\n' "$ssid" "$sec" >>"$tmpmap"
    if [ -n "${seen_active[$ssid]:-}" ]; then
        cur="$ssid"
        printf '%d\t● %s %s%%%s\n' "$sig" "$ssid" "$sig" "$lock" >>"$tmpmenu"
    else
        printf '%d\t○ %s %s%%%s\n' "$sig" "$ssid" "$sig" "$lock" >>"$tmpmenu"
    fi
done
# Strongest signal first (numeric prefix; SSIDs may contain spaces).
if [ -s "$tmpmenu" ]; then
    menu="$(sort -rn "$tmpmenu" | cut -f2-)"
    menu="$menu
"
fi

actions="＋ Join hidden network…
✓ Saved connections…
⛔ Disconnect${cur:+ ($cur)}
🗑 Forget saved network…
ℹ Details${cur:+ ($cur)}
🔄 Rescan
✎ Edit connections (nmtui)…
⚙ Advanced editor…
📡 Wi-Fi: ON — turn off"
menu="${menu}${actions}"

prompt="Wi-Fi${cur:+: $cur}: "
choice=$(printf '%s' "$menu" | "${MENU[@]}" --prompt "$prompt") || exit 0
[ -n "${choice:-}" ] || exit 0

case "$choice" in
    "＋ Join"*)
        add_hidden
        ;;
    "✓ Saved"*)
        saved_menu
        ;;
    "⛔ Disconnect"*)
        disconnect_current
        ;;
    "🗑 Forget"*)
        forget_menu
        ;;
    "ℹ Details"*)
        show_details
        ;;
    "🔄 Rescan"*)
        notify "Scanning..."
        nmcli device wifi rescan >/dev/null 2>&1 || true
        sleep 3
        exec "$0"
        ;;
    "✎ Edit"*)
        open_nmtui
        ;;
    "⚙ Advanced"*)
        open_adv_editor
        ;;
    "📡 Wi-Fi"*)
        toggle_wifi
        ;;
    "● "*|"○ "*)
        # Row: "●|○ SSID SIGNAL% [🔒]" — SSID may contain spaces, so
        # strip the leading glyph, then cut the trailing " NN%..." part.
        row="${choice#? }"
        ssid="$(printf '%s' "$row" | sed 's/ [0-9][0-9]*%.*$//')"
        [ -n "$ssid" ] || { notify "Could not parse selection"; exit 0; }
        sec="$(awk -F '\t' -v n="$ssid" '$1==n {print $2; exit}' "$tmpmap")"
        connect_ssid "$ssid" "$sec"
        ;;
esac
