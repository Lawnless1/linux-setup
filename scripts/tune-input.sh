#!/bin/bash
# Tune pointer speeds live AND persist them for X login + i3 restarts.
# Usage:
#   tune-input.sh                  # show current speeds
#   tune-input.sh --mouse 0.8 --touchpad 0.3
#   tune-input.sh --touchpad 0.5   # adjust one device
set -u

POINTER_FILE="$HOME/.config/input/pointer.sh"

current_of() {
    xinput list-props "$1" 2>/dev/null | awk -F': ' '/libinput Accel Speed \(/ {print $2; exit}'
}

show_current() {
    echo "Current libinput Accel Speed (-1..1, higher = faster):"
    xinput list --name-only 2>/dev/null | grep -i -E "mouse|touchpad|pointer|trackpoint" | while read -r d; do
        printf '  %-45s %s\n' "$d" "$(current_of "$d")"
    done
    echo "Persisted defaults: $POINTER_FILE"
}

MOUSE=""; TOUCHPAD=""
while [ $# -gt 0 ]; do
    case "$1" in
        --mouse) MOUSE="$2"; shift 2;;
        --touchpad) TOUCHPAD="$2"; shift 2;;
        -h|--help) sed -n '2,7p' "$0"; exit 0;;
        *) echo "Unknown arg: $1 (see --help)"; exit 1;;
    esac
done

if [ -z "$MOUSE" ] && [ -z "$TOUCHPAD" ]; then
    show_current
    exit 0
fi

valid() { awk -v v="$1" 'BEGIN{exit !(v+0>=-1 && v+0<=1)}'; }
if [ -n "$MOUSE" ] && ! valid "$MOUSE"; then echo "Mouse speed must be -1..1"; exit 1; fi
if [ -n "$TOUCHPAD" ] && ! valid "$TOUCHPAD"; then echo "Touchpad speed must be -1..1"; exit 1; fi

# Apply live by name (stable across reboots; never hard-code xinput ids).
apply_named() {
    _pattern="$1"; _speed="$2"
    _dev=$(xinput list --name-only 2>/dev/null | grep -i -m1 -E "$_pattern")
    if [ -n "$_dev" ]; then
        xinput --set-prop "$_dev" "libinput Accel Speed" "$_speed" && echo "live: $_dev -> $_speed"
    else
        echo "note: no device matching /$_pattern/ found; value still persisted"
    fi
}
[ -n "$MOUSE" ] && apply_named "mouse" "$MOUSE"
[ -n "$TOUCHPAD" ] && apply_named "touchpad" "$TOUCHPAD"

# Persist by rewriting the defaults in pointer.sh (keeps device names intact).
persist() {
    _var="$1"; _val="$2"
    if grep -q "^${_var}=" "$POINTER_FILE" 2>/dev/null; then
        sed -i "s|^${_var}=.*|${_var}=\"${_val}\"|" "$POINTER_FILE"
    else
        printf '\n%s="%s"\n' "$_var" "$_val" >> "$POINTER_FILE"
    fi
}
# shellcheck disable=SC2034
[ -n "$MOUSE" ] && persist "POINTER_MOUSE_SPEED" "$MOUSE"
[ -n "$TOUCHPAD" ] && persist "POINTER_TOUCHPAD_SPEED" "$TOUCHPAD"
echo "persisted to $POINTER_FILE"

# Keep ~/.xprofile as a thin loader (it sources pointer.sh on X login).
if ! grep -q "config/input/pointer.sh" "$HOME/.xprofile" 2>/dev/null; then
    cat >> "$HOME/.xprofile" <<'EOF'

# ubuntu-i3-setup: pointer sensitivity (tune with scripts/tune-input.sh)
if [ -f "$HOME/.config/input/pointer.sh" ]; then
    . "$HOME/.config/input/pointer.sh"
fi
EOF
    echo "hooked pointer.sh into ~/.xprofile"
fi
