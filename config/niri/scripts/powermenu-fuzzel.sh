#!/usr/bin/env bash
# Power menu for the Ctrl+Alt+Delete niri binding. Requires: fuzzel,
# systemd (loginctl/systemctl; logind lets the active local session power
# off/reboot/suspend without a password).
set -u

FUZZEL="$(command -v fuzzel)"

# Dmenu theme with the option list visible from the start (the omnibar
# fuzzel.ini hides results until first keystroke; see fuzzel-dmenu.ini).
DMENU_INI="$HOME/.config/fuzzel/fuzzel-dmenu.ini"
if [ -f "$DMENU_INI" ]; then
    MENU=( "$FUZZEL" --config "$DMENU_INI" --dmenu )
else
    MENU=( "$FUZZEL" --dmenu )
fi

choice=$(printf '%s\n' "Lock" "Logout" "Suspend" "Reboot" "Poweroff" \
    | "${MENU[@]}" --prompt "Power: ")

case "${choice:-}" in
    "Lock")
        exec swaylock
        ;;
    "Logout")
        loginctl terminate-user "$(whoami)"
        ;;
    "Suspend")
        systemctl suspend
        ;;
    "Reboot")
        systemctl reboot
        ;;
    "Poweroff")
        systemctl poweroff
        ;;
esac
