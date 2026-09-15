#!/usr/bin/env bash
# Workspace strip for waybar on niri (custom/niri-workspaces module).
# Ubuntu 24.04's waybar (0.9.24) has no native niri/workspaces module, so this
# polls `niri msg -j workspaces` once per second (waybar `interval: 1`) and
# renders workspaces 1..10, highlighting the focused one.
# Output: waybar JSON {text (pango markup), tooltip, class}. Deps: niri, jq.
# NOTE: waybar reads only the FIRST line of a custom module's output, so the
# JSON must be single-line (jq -c). Pretty-printed JSON fails every poll with
# "Missing '}' or object member name" and the module renders empty.
set -u

if ! out=$(niri msg -j workspaces 2>/dev/null); then
    printf '{"text":"niri…","tooltip":"niri IPC unavailable","class":"offline"}\n'
    exit 0
fi

focused=$(printf '%s' "$out" | jq -r '[.[] | select(.is_focused == true)][0].idx // 1')
active_list=$(printf '%s' "$out" | jq -r '[.[] | select(.active_window_id != null) | .idx] | unique | join(" ")')

text=""
i=1
while [ "$i" -le 10 ]; do
    if [ "$i" -eq "$focused" ]; then
        text="$text<b><span foreground=\"#11DAE4\">$i</span></b> "
    elif printf '%s' " $active_list " | grep -q " $i "; then
        text="$text<b>$i</b> "
    else
        text="$text<span foreground=\"#465159\">$i</span> "
    fi
    i=$((i + 1))
done

focused_name=$(printf '%s' "$out" | jq -r '[.[] | select(.is_focused == true)][0].name // empty')
tooltip="focused workspace: ${focused_name:-$focused}"

jq -c -n --arg text "$text" --arg tooltip "$tooltip" \
    '{text: $text, tooltip: $tooltip, class: "workspaces"}'
