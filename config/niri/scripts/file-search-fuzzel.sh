#!/usr/bin/env bash
# Unified Spotlight search for the niri session (Super+F): apps rank above
# folders above files. Companion to the $mod+d / $mod+space app omnibar.
# Apps come from .desktop entries, folders/files from fd under
# $FILE_SEARCH_ROOTS (default $HOME); selection opens via the desktop entry,
# xdg-open, or the terminal for Terminal=true apps.
# Requires: fd, fuzzel >= 1.12 (scripts/build-fuzzel.sh), xdg-open, foot.
# Usage: file-search-fuzzel.sh
#   FILE_SEARCH_ROOTS="$HOME/Documents:$HOME/Pictures" file-search-fuzzel.sh
set -u

FUZZEL="$(command -v fuzzel)"
command -v fd >/dev/null 2>&1 || { echo "need fd" >&2; exit 1; }

# Nerd Font glyphs (ASCII-safe $'' quoting): app grid, folder, file.
APP_GLYPH=$'\uf00a'
DIR_GLYPH=$'\uf07b'
FILE_GLYPH=$'\uf15b'

ROOTS="${FILE_SEARCH_ROOTS:-$HOME}"
APP_DIRS="${FILE_SEARCH_APP_DIRS:-$HOME/.local/share/applications:/usr/share/applications}"
# Junk that should never surface in results (tweak freely).
EXCLUDES=(.cache .git node_modules snap __pycache__ .mozilla
    .local/share/Trash .conda .vscode/extensions '*.pyc')

declare -A APP_EXEC=() APP_TERM=()

load_apps() {
    # load_apps: Name -> (exec, terminal) for launchable .desktop entries.
    # ~/.local first so user overrides win on duplicate names.
    old_ifs="$IFS"; IFS=':'
    # shellcheck disable=SC2206
    dirs=($APP_DIRS)
    IFS="$old_ifs"
    for d in "${dirs[@]}"; do
        [ -d "$d" ] || continue
        for f in "$d"/*.desktop; do
            [ -f "$f" ] || continue
            grep -q '^Hidden=true' "$f" && continue
            grep -q '^NoDisplay=true' "$f" && continue
            name="$(grep -m1 '^Name=' "$f" | cut -d= -f2-)"
            [ -n "${name:-}" ] || continue
            [ -n "${APP_EXEC[$name]:-}" ] && continue
            tryexec="$(grep -m1 '^TryExec=' "$f" | cut -d= -f2-)"
            if [ -n "${tryexec:-}" ]; then
                command -v "$tryexec" >/dev/null 2>&1 || continue
            fi
            exec_line="$(grep -m1 '^Exec=' "$f" | cut -d= -f2-)"
            [ -n "${exec_line:-}" ] || continue
            # Strip % field codes (%f %F %u %U ...); first token is argv.
            # shellcheck disable=SC2206
            argv=(${exec_line// %[fFuUdDnNickvm]/})
            [ -n "${argv[0]:-}" ] || continue
            APP_EXEC["$name"]="${argv[*]}"
            grep -q '^Terminal=true' "$f" \
                && APP_TERM["$name"]=1 || APP_TERM["$name"]=0
        done
    done
}

list_root() {
    # list_root <dir>: folders first, then files, ~/ for $HOME paths.
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

launch_app() {
    # launch_app <name>: run the stored argv (in foot for Terminal=true).
    read -ra argv <<< "${APP_EXEC[$1]}"
    if [ "${APP_TERM[$1]}" = 1 ] && command -v foot >/dev/null 2>&1; then
        (foot -e "${argv[@]}" >/dev/null 2>&1 &) || true
    else
        ("${argv[@]}" >/dev/null 2>&1 &) || true
    fi
}

load_apps

old_ifs="$IFS"; IFS=':'
# shellcheck disable=SC2206
roots=($ROOTS)
IFS="$old_ifs"

{
    # Priority order: apps, then folders, then files. fuzzel ranks by
    # match score; input order breaks ties, so apps win equal matches.
    for name in "${!APP_EXEC[@]}"; do printf '%s %s\n' "$APP_GLYPH" "$name"; done
    for r in "${roots[@]}"; do list_root "$r"; done
} | "$FUZZEL" --dmenu --prompt "❯ " --placeholder "Search apps, files and folders" \
    | {
        IFS= read -r sel || exit 0
        [ -n "${sel:-}" ] || exit 0
        item="${sel#* }"                 # strip leading glyph
        case "$item" in
            */*|~*)
                # A path (files/folders always display with one).
                path="$item"
                case "$path" in "~"*) path="$HOME${path#\~}";; esac
                [ -e "$path" ] || exit 0
                xdg-open "$path" >/dev/null 2>&1 &
                ;;
            *)
                # A bare name: app entry, with path/exec fallback.
                if [ -n "${APP_EXEC[$item]:-}" ]; then
                    launch_app "$item"
                elif [ -e "$item" ]; then
                    xdg-open "$item" >/dev/null 2>&1 &
                fi
                ;;
        esac
    }
