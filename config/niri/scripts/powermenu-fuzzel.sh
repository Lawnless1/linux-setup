#!/usr/bin/env bash
# Power menu for the Ctrl+Alt+Delete niri binding (fuzzel equivalent of the
# i3/rofi powermenu.sh). Requires: fuzzel, loginctl. doas is optional
# (poweroff/reboot/suspend fall back to plain systemctl, which works for an
# active local session).
set -u

FUZZEL="/usr/bin/fuzzel"
LOGINCTL="/usr/bin/loginctl"
SYSTEMCTL="/usr/bin/systemctl"

choice=$(printf '%s\n' "Lock" "Logout" "Suspend" "Reboot" "Poweroff" \
    | "$FUZZEL" --dmenu --prompt "Power: ")

run_power() {
    if command -v doas >/dev/null 2>&1 && doas -n true 2>/dev/null; then
        doas "$SYSTEMCTL" "$1"
    else
        "$SYSTEMCTL" "$1"
    fi
}

case "${choice:-}" in
    "Lock")
        command -v swaylock >/dev/null 2>&1 && exec swaylock
        ;;
    "Logout")
        "$LOGINCTL" terminate-user "$(whoami)"
        ;;
    "Suspend")
        run_power suspend
        ;;
    "Reboot")
        run_power reboot
        ;;
    "Poweroff")
        run_power poweroff
        ;;
esac
