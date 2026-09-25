# Pointer sensitivity (libinput Accel Speed -1 to 1, higher = faster).
# Sourced by ~/.xprofile on X login AND by the i3 config on (re)start,
# so values apply without relogging.
# Edit the two numbers below to taste, then run: scripts/tune-input.sh

# Mouse: comfortable desktop speed
POINTER_MOUSE_SPEED="${POINTER_MOUSE_SPEED:-0.5}"
# Touchpad: slightly calmer than the mouse
POINTER_TOUCHPAD_SPEED="${POINTER_TOUCHPAD_SPEED:-0.3}"

# Match by device name (stable) instead of xinput id (changes per boot).
# Falls back to substring match so small model-name changes don't break it.
set_pointer_speed() {
    _dev="$1"; _speed="$2"; _prop="libinput Accel Speed"
    if xinput list --name-only 2>/dev/null | grep -Fxq "$_dev"; then
        xinput --set-prop "$_dev" "$_prop" "$_speed" 2>/dev/null && return 0
    fi
    _match=$(xinput list --name-only 2>/dev/null | grep -i -m1 -E "$3")
    if [ -n "$_match" ]; then
        xinput --set-prop "$_match" "$_prop" "$_speed" 2>/dev/null && return 0
    fi
    return 1
}

MOUSE_NAME="${POINTER_MOUSE_NAME:-ASCP1200:00 093A:3016 Mouse}"
TOUCHPAD_NAME="${POINTER_TOUCHPAD_NAME:-ASCP1200:00 093A:3016 Touchpad}"

set_pointer_speed "$MOUSE_NAME" "$POINTER_MOUSE_SPEED" "mouse" || true
set_pointer_speed "$TOUCHPAD_NAME" "$POINTER_TOUCHPAD_SPEED" "touchpad" || true
