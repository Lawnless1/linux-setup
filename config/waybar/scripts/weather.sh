#!/bin/sh
# Weather module for waybar (custom/weather).
# Same data source as the polybar module: OPENWEATHER_API_KEY and
# OPENWEATHER_CITY in ~/.config/ubuntu-i3-setup/env (see config/env.example).
# Shows "icon temp°"; blank output (module hidden) when no key is set.
# Deps: curl, jq
set -u

ENV_FILE="$HOME/.config/ubuntu-i3-setup/env"
[ -f "$ENV_FILE" ] && . "$ENV_FILE"

get_icon() {
    case $1 in
        01d) icon="";;
        01n) icon="";;
        02d) icon="";;
        02n) icon="";;
        03*) icon="";;
        04*) icon="";;
        09d) icon="";;
        09n) icon="";;
        10d) icon="";;
        10n) icon="";;
        11d) icon="";;
        11n) icon="";;
        13d) icon="";;
        13n) icon="";;
        50d) icon="";;
        50n) icon="";;
        *) icon="";
    esac
    echo "$icon"
}

KEY="${OPENWEATHER_API_KEY:-}"
CITY="${OPENWEATHER_CITY:-6077243}"
UNITS="${OPENWEATHER_UNITS:-metric}"
API="https://api.openweathermap.org/data/2.5"

[ -z "$KEY" ] && { echo '{"text":"","tooltip":"no OPENWEATHER_API_KEY"}'; exit 0; }

if [ "$CITY" -eq "$CITY" ] 2>/dev/null; then
    CITY_PARAM="id=$CITY"
else
    CITY_PARAM="q=$CITY"
fi
weather=$(curl -sf --max-time 10 "$API/weather?appid=$KEY&$CITY_PARAM&units=$UNITS") \
    || { echo '{"text":"","tooltip":"weather fetch failed"}'; exit 0; }

icon=$(get_icon "$(echo "$weather" | jq -r '.weather[0].icon')")
temp=$(echo "$weather" | jq -r '.main.temp | round')
desc=$(echo "$weather" | jq -r '.weather[0].description // ""')

text=$(echo "$icon $temp°" | sed 's/^ //')
tooltip=$(echo "$desc, $temp°" | sed 's/^, //')

# Minimal JSON escaping (\ and " only; API text is short and plain).
text=$(echo "$text" | sed 's/\\/\\\\/g; s/"/\\"/g')
tooltip=$(echo "$tooltip" | sed 's/\\/\\\\/g; s/"/\\"/g')
printf '{"text":"%s","tooltip":"%s"}\n' "$text" "$tooltip"
