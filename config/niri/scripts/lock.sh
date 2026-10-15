#!/usr/bin/env bash
# Lock the screen over a frosted-glass copy of the wallpaper. Upstream
# swaylock can't blur, so the film (blur + NavyGlass tint + top sheen +
# fine grain) is pre-rendered once with ImageMagick and cached; it is
# re-rendered only when the wallpaper or this script is newer than the cache.
# Arguments pass through to swaylock (swayidle uses -f).
set -u

src="${LOCK_WALLPAPER:-$HOME/Pictures/wallpaper/dark.jpg}"
cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/linux-setup"
film="$cache_dir/lock-film.png"

render_film() {
    local magick w h
    magick="$(command -v magick || command -v convert)" || return 1
    mkdir -p "$cache_dir"
    read -r w h < <("$magick" "$src" -resize '1920x1920>' -format '%w %h\n' info:) || return 1
    # Blur at 1/5 scale: a large-sigma blur at full size takes seconds,
    # too slow for before-sleep locking on a cache miss.
    "$magick" "$src" -resize "${w}x${h}!" \
        -resize 20% -blur 0x5 -resize "${w}x${h}!" \
        -fill '#010B17' -colorize 40% \
        \( -size "${w}x${h}" gradient:'#2a3550-#000000' \) -compose screen -composite \
        \( -size "${w}x${h}" xc:gray50 -attenuate 0.6 +noise Gaussian -colorspace gray \) \
        -define compose:args=6 -compose blend -composite \
        "$film.tmp.png" && mv -f "$film.tmp.png" "$film"
}

if [ -f "$src" ] && { [ ! -f "$film" ] || [ "$src" -nt "$film" ] || [ "$0" -nt "$film" ]; }; then
    render_film || rm -f "$film.tmp.png"
fi

if [ -f "$film" ]; then
    exec swaylock -i "$film" "$@"
fi
exec swaylock "$@"
