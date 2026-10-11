#!/usr/bin/env bash
# Power menu (rofi). Requires: rofi, i3lock (optional), systemctl/loginctl.
# Suspend uses doas if configured (see system/doas.conf.d/), else plain systemctl.

uptime=$(uptime -p | sed -e 's/up //g')

rofi_command="rofi -theme $HOME/.config/polybar/custom/scripts/rofi_themes/powermenu.rasi"

shutdown=" Shutdown"
reboot=" Reboot"
lock=" Lock"
suspend=" Suspend"
logout=" Logout"

chosen="$(echo -e "$shutdown\n$reboot\n$lock\n$suspend\n$logout" | $rofi_command -p "Uptime: $uptime" -dmenu -selected-row 2)"
case $chosen in
    $shutdown)
        systemctl poweroff
        ;;
    $reboot)
        systemctl reboot
        ;;
    $lock)
        if [[ -f /usr/bin/i3lock ]]; then
            i3lock
        elif [[ -f /usr/bin/betterlockscreen ]]; then
            betterlockscreen -l
        fi
        ;;
    $suspend)
        if command -v doas >/dev/null 2>&1 && doas -n true 2>/dev/null; then
            doas systemctl suspend
        else
            systemctl suspend
        fi
        ;;
    $logout)
        if [[ "${DESKTOP_SESSION:-}" == "i3" ]]; then
            i3-msg exit
        else
            loginctl terminate-user "$(whoami)"
        fi
        ;;
esac
