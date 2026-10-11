#!/bin/bash

# Function to get volume and mute status from the default sink
get_volume_info() {
    # Get the default sink information
    SINK_INFO=$(pactl get-sink-volume @DEFAULT_SINK@ | grep 'Volume:' | head -n1)
    IS_MUTED=$(pactl get-sink-mute @DEFAULT_SINK@)

    # Check if the sink is muted
    if echo "$IS_MUTED" | grep -q "yes"; then
        echo "muted"
    else
        # If not muted, parse the volume percentage
        echo "$SINK_INFO" | grep -o '[0-9]*%' | head -1 | tr -d '%'
    fi
}

icon_muted=""
icon_low=""
icon_med=""
icon_high=""

case "$1" in
    # These actions are now handled by i3/pactl, but kept for script compatibility
    up)
        pactl set-sink-volume @DEFAULT_SINK@ +5%
        ;;
    down)
        pactl set-sink-volume @DEFAULT_SINK@ -5%
        ;;
    *)
        volume=$(get_volume_info)

        if [ "$volume" = "muted" ]; then
            icon=$icon_muted
            text="Muted"
        else
            if [ "$volume" -ge 70 ]; then
                icon=$icon_high
            elif [ "$volume" -ge 30 ]; then
                icon=$icon_med
            else
                icon=$icon_low
            fi
            text="$volume%"
        fi

        echo "$icon $text"
        ;;
esac