#!/bin/sh
# Clipboard history that pastes on select (Mod+V): opens the walker
# clipboard picker; when a selection changes the clipboard, types Ctrl+V
# into the refocused window. Cancelling leaves the clipboard untouched,
# so nothing is pasted. Requires: walker, wl-clipboard, wtype.
set -u

before="$(timeout 3 wl-paste 2>/dev/null | md5sum | cut -d' ' -f1)"
walker -m clipboard -t clipboard -H -N
after="$(timeout 3 wl-paste 2>/dev/null | md5sum | cut -d' ' -f1)"

if [ "$before" != "$after" ]; then
    sleep 0.15
    wtype -M ctrl -k v -m ctrl
fi
