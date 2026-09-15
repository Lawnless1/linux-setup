#!/bin/bash
# GNOME Terminal prefs for ubuntu-i3-setup (both i3 and niri spawn it via
# i3-sensible-terminal). Idempotent: safe to re-run.
# - scrollbar-policy 'never': no permanent scrollbar gutter (was 'always').
set -euo pipefail

UUID=$(gsettings get org.gnome.Terminal.ProfilesList default | tr -d "'")
BASE="org.gnome.Terminal.Legacy.Profile:/org/gnome/Terminal/Legacy/Profiles:/:$UUID/"

gsettings set "$BASE" scrollbar-policy 'never'
echo "gnome-terminal ($UUID): scrollbar-policy=$(gsettings get "$BASE" scrollbar-policy)"
