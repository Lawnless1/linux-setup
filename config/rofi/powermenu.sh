#!/usr/bin/env bash
# Power menu for the Ctrl+Alt+Delete i3 binding.
# Requires: rofi, loginctl. doas is optional (poweroff/reboot/suspend fall back
# to plain systemctl, which works for an active local session).
set -u

ROFI="/usr/bin/rofi"
LOGINCTL="/usr/bin/loginctl"
SYSTEMCTL="/usr/bin/systemctl"

powermenu_theme="$HOME/.config/rofi/themes/powermenu.rasi"

lock=""
logout=""
shutdown=""
reboot=""
sleep=""

rofi_cmd() {
    "$ROFI" -dmenu \
        -i \
        -p "Power" \
        -theme "$powermenu_theme"
}

selected_option=$(printf '%s\n' "$lock" "$logout" "$sleep" "$reboot" "$shutdown" | rofi_cmd)

run_power() {
    if command -v doas >/dev/null 2>&1 && doas -n true 2>/dev/null; then
        doas "$SYSTEMCTL" "$1"
    else
        "$SYSTEMCTL" "$1"
    fi
}

case "$selected_option" in
    "$lock" | "$logout")
        "$LOGINCTL" terminate-user "$(whoami)"
        ;;
    "$shutdown")
        run_power poweroff
        ;;
    "$reboot")
        run_power reboot
        ;;
    "$sleep")
        run_power suspend
        ;;
esac
