#!/bin/sh
# Weather icon for polybar (OpenWeatherMap).
# No secrets in repo: set OPENWEATHER_API_KEY and OPENWEATHER_CITY in
# ~/.config/linux-setup/env (see env.example). Falls back to $OPENWEATHER_*.
# Deps: curl, jq
set -u

WEATHER_FILE="${TMPDIR:-/tmp}/polybar-weather.json"
ENV_FILE="$HOME/.config/linux-setup/env"
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

[ -z "$KEY" ] && { echo ""; exit 0; }

if [ -n "$CITY" ]; then
    if [ "$CITY" -eq "$CITY" ] 2>/dev/null; then
        CITY_PARAM="id=$CITY"
    else
        CITY_PARAM="q=$CITY"
    fi
    weather=$(curl -sf --max-time 10 "$API/weather?appid=$KEY&$CITY_PARAM&units=$UNITS")
else
    exit 0
fi

# Output + save for the rofi detail menu
if [ -n "$weather" ]; then
    echo "$weather" > "$WEATHER_FILE"
    icon=$(get_icon "$(echo "$weather" | jq -r ".weather[0].icon")")
    echo "$icon"
fi
