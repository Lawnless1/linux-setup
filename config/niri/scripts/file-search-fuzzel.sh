#!/usr/bin/env bash
# Spotlight-style file search for the niri session: Super+F fuzzy-finds
# files and folders under $HOME via fd, picks via fuzzel dmenu, opens via
# xdg-open. Companion to the $mod+d / $mod+space app omnibar (which keeps
# its icons; fuzzel's icon grid can't take a file list, hence the split).
# Requires: fd, fuzzel >= 1.12 (scripts/build-fuzzel.sh), xdg-open.
# Usage: file-search-fuzzel.sh
#   FILE_SEARCH_ROOTS="$HOME/Documents:$HOME/Pictures" file-search-fuzzel.sh
set -u

FUZZEL="$(command -v fuzzel)"
command -v fd >/dev/null 2>&1 || { echo "need fd" >&2; exit 1; }

# Nerd Font glyphs (ASCII-safe $'' quoting): folder, file.
DIR_GLYPH=$'\uf07b'
FILE_GLYPH=$'\uf15b'

ROOTS="${FILE_SEARCH_ROOTS:-$HOME}"
# Junk that should never surface in results (tweak freely).
EXCLUDES=(.cache .git node_modules snap __pycache__ .mozilla
    .local/share/Trash .conda .vscode/extensions '*.pyc')

list_root() {
    # list_root <dir>: folders first (grouped, Spotlight-ish), then files,
    # displayed with ~/ for $HOME paths.
    root="$1"
    [ -d "$root" ] || return 0
    fd_args=()
    for e in "${EXCLUDES[@]}"; do fd_args+=(--exclude "$e"); done
    disp="$root"
    case "$root" in "$HOME"*) disp="~${root#$HOME}";; esac
    fd --hidden --type d "${fd_args[@]}" . "$root" 2>/dev/null \
        | sed "s|^|$DIR_GLYPH |; s|^$DIR_GLYPH $root|$DIR_GLYPH $disp|"
    fd --hidden --type f "${fd_args[@]}" . "$root" 2>/dev/null \
        | sed "s|^|$FILE_GLYPH |; s|^$FILE_GLYPH $root|$FILE_GLYPH $disp|"
}

old_ifs="$IFS"; IFS=':'
set -- $ROOTS
IFS="$old_ifs"
{
    for r in "$@"; do list_root "$r"; done
} | "$FUZZEL" --dmenu --prompt "❯ " --placeholder "Search files and folders" \
    | {
        IFS= read -r sel || exit 0
        [ -n "${sel:-}" ] || exit 0
        path="${sel#* }"                 # strip leading glyph
        case "$path" in "~"*) path="$HOME${path#\~}";; esac
        [ -e "$path" ] || exit 0
        xdg-open "$path" >/dev/null 2>&1 &
    }
