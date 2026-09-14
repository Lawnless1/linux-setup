#!/bin/sh
# polybar launcher — kills stale bars, then starts the single center bar.
# Config: ~/.config/polybar/custom/config.ini :: [bar/center]

# Terminate already running bar instances
killall -q polybar

# Wait until the processes have been shut down
while pgrep -x polybar >/dev/null; do sleep 1; done

# Launch the bar (unquoted ~ would NOT expand; use $HOME)
polybar -q center -c "$HOME/.config/polybar/custom/config.ini" &
