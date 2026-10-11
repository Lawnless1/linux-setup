#!/bin/bash
# Sanity checks for ubuntu-i3-setup: required binaries, i3 syntax, script syntax.
# Exit 0 = all good. Used by install.sh and CI-ish local runs.
set -u
FAIL=0
need() { command -v "$1" >/dev/null 2>&1 || { echo "MISSING: $1 ($2)"; FAIL=1; }; }

echo "--- binaries ---"
need i3 "apt: i3"
need polybar "apt: polybar"
need rofi "apt: rofi"
need picom "apt: picom (optional, not autostarted)"
need feh "apt: feh"
need dunst "apt: dunst"
need xinput "apt: x11-xserver-utils"
need xrdb "apt: x11-xserver-utils (package: xrdb)"
need pactl "apt: pulseaudio-utils"
need brightnessctl "apt: brightnessctl"
need jq "apt: jq"
need curl "apt: curl"
need nmcli "apt: network-manager"
need iw "apt: iw"
need bluetoothctl "apt: bluez"
need flameshot "apt: flameshot"
need dex "apt: dex"
need nm-applet "apt: network-manager-gnome"

echo "--- gtk env (blueman crash guard) ---"
case ":${GTK_MODULES:-}:" in
    *:appmenu-gtk-module:*)
        echo "BAD GTK_MODULES (segfaults blueman-manager): $GTK_MODULES"
        echo "strip appmenu-gtk-module: purge orphan vala-panel-appmenu-common + see shell/profile hygiene block"
        FAIL=1;;
    *) echo "GTK_MODULES OK (${GTK_MODULES:-(unset)})";;
esac

echo "--- i3 config ---"
if command -v i3 >/dev/null 2>&1; then
    i3 -C -c "$HOME/.config/i3/config" && echo "i3 config OK" || { echo "i3 config INVALID"; FAIL=1; }
else
    echo "(skip: i3 not installed)"
fi

echo "--- shell syntax ---"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ok=1
while IFS= read -r f; do
    case "$f" in
        *.bashrc|.xprofile) bash -n "$f" || { echo "SYNTAX FAIL: $f"; ok=0; };;
        *) sh -n "$f" 2>/dev/null || bash -n "$f" || { echo "SYNTAX FAIL: $f"; ok=0; };;
    esac
done \
    < <(find "$REPO_DIR/config" "$REPO_DIR/scripts" "$REPO_DIR/shell" "$REPO_DIR/home" \( -name "*.sh" -o -name "*.bashrc" -o -name ".xprofile" \) 2>/dev/null)
[ "$ok" -eq 1 ] && echo "shell syntax OK" || FAIL=1
python3 -c "import ast,sys; ast.parse(open(sys.argv[1]).read())" "$REPO_DIR/config/polybar/custom/scripts/rofi-mixer.py" \
    && echo "rofi-mixer.py OK" || { echo "rofi-mixer.py INVALID"; FAIL=1; }

echo "--- polybar config ---"
if command -v polybar >/dev/null 2>&1; then
    polybar --dump=modules-left -c "$HOME/.config/polybar/custom/config.ini" center >/dev/null 2>&1 \
        && echo "polybar config OK" || echo "(warn: polybar could not dump [bar/center] — check after install)"
else
    echo "(skip: polybar not installed)"
fi

echo "--- niri / waybar (Wayland session; soft checks until installed) ---"
for b in niri waybar fuzzel swaylock swayidle swaybg grim slurp wl-copy convert; do
    command -v "$b" >/dev/null 2>&1 || echo "(info: $b not installed yet — ./install.sh --with-niri + scripts/build-niri.sh)"
done
if command -v niri >/dev/null 2>&1; then
    niri validate --config "$HOME/.config/niri/config.kdl" \
        && echo "niri config OK" || { echo "niri config INVALID"; FAIL=1; }
else
    echo "(skip: niri validate — niri not installed)"
fi
# waybar config is JSON-with-comments: strip full-line // comments, then parse.
python3 - "$HOME/.config/waybar/config.jsonc" <<'EOF' \
    && echo "waybar config OK" || { echo "waybar config INVALID"; FAIL=1; }
import json, sys
lines = open(sys.argv[1]).read().splitlines()
lines = [l for l in lines if not l.lstrip().startswith("//")]
json.loads("\n".join(lines))
EOF
[ -f "$HOME/.config/fuzzel/fuzzel.ini" ] && echo "fuzzel config linked" \
    || { echo "MISSING: ~/.config/fuzzel/fuzzel.ini (run ./install.sh)"; FAIL=1; }
# The omnibar config needs fuzzel >= 1.12 (noble ships 1.9.2, which rejects
# its keys) — provided by scripts/build-fuzzel.sh in /usr/local/bin.
if command -v fuzzel >/dev/null 2>&1; then
    fuzzel --version | head -1 | grep -Eq "version: 1\.(1[2-9]|[2-9][0-9])" \
        && echo "fuzzel >= 1.12 OK ($(command -v fuzzel))" \
        || { echo "OLD FUZZEL: $(fuzzel --version | head -1) — run ./scripts/build-fuzzel.sh"; FAIL=1; }
fi
[ -f "$HOME/.config/dunst/dunstrc" ] && echo "dunst config linked" \
    || { echo "MISSING: ~/.config/dunst/dunstrc (run ./install.sh)"; FAIL=1; }
[ -f "$HOME/.config/walker/config.toml" ] && echo "walker config linked" \
    || { echo "MISSING: ~/.config/walker/config.toml (run ./install.sh)"; FAIL=1; }
for b in elephant walker; do
    command -v "$b" >/dev/null 2>&1 || echo "(info: $b not installed yet — ./scripts/build-walker.sh)"
done
for p in desktopapplications files clipboard; do
    [ -f "$HOME/.config/elephant/providers/$p.so" ] && echo "elephant provider $p OK" \
        || echo "(info: elephant provider $p missing — ./scripts/build-walker.sh)"
done
[ -f "$HOME/.config/xdg-desktop-portal/niri-portals.conf" ] && echo "niri portals linked" \
    || { echo "MISSING: niri-portals.conf (run ./install.sh)"; FAIL=1; }
# Noctalia bar (replaces waybar; needs scripts/install-noctalia.sh on 26.04+).
[ -f "$HOME/.config/noctalia/config.toml" ] && echo "noctalia config linked" \
    || { echo "MISSING: ~/.config/noctalia/config.toml (run ./install.sh)"; FAIL=1; }
if command -v noctalia >/dev/null 2>&1; then
    noctalia config validate "$HOME/.config/noctalia/config.toml" \
        && echo "noctalia config OK" || { echo "noctalia config INVALID"; FAIL=1; }
else
    echo "(info: noctalia not installed yet — ./scripts/install-noctalia.sh)"
fi

[ "$FAIL" -eq 0 ] && echo "ALL CHECKS PASSED" || echo "CHECKS FAILED"
exit "$FAIL"
