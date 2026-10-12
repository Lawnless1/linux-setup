# >>> linux-setup — shell additions (appended by install.sh) >>>
# Kept separate from Ubuntu's default ~/.bashrc so updates stay mergeable.
# Source order: interactive shells read ~/.bashrc, which sources
# ~/.bashrc.d/*.bashrc when present.

# --- compact two-level prompt: parent/current ---
__i3s_prompt_dir() {
    local pwd_clean="${PWD%/}"
    local parent current
    parent="$(dirname "$pwd_clean")"
    current="$(basename "$pwd_clean")"
    if [[ "$PWD" == "$HOME" ]]; then
        printf '~'
    elif [[ "$PWD" == "/" ]]; then
        printf '/'
    elif [[ "$parent" == "/" ]]; then
        printf '/%s' "$current"
    elif [[ "$parent" == "$HOME" ]]; then
        printf '~/\%s' "$current"
    else
        printf '%s/%s' "$(basename "$parent")" "$current"
    fi
}

# --- git helpers (namespaced to avoid clobbering coreutils) ---
git_soft_reset_pull() {
    local n="${1:-1}"
    git reset --soft "HEAD~$n" && git stash && git pull
}
git_stash_pull_pop() {
    git stash push -m "current work" && git pull && git stash pop
}

# --- tmux hygiene: every foot window is its own session, so closing windows
# orphans detached sessions holding idle shells. Reap those; attached
# sessions and anything running real commands (background agents) survive.
tmux-clean() {
    local s attached cmds
    tmux ls -F '#{session_name} #{session_attached}' 2>/dev/null | while read -r s attached; do
        [ "${attached:-0}" -gt 0 ] 2>/dev/null && continue
        cmds="$(tmux list-panes -t "$s" -F '#{pane_current_command}' 2>/dev/null)"
        [ -z "$cmds" ] && continue
        if printf '%s\n' "$cmds" | grep -qvE '^(bash|sh|zsh|fish|dash)$'; then
            continue
        fi
        echo "killing detached idle session: $s"
        tmux kill-session -t "$s"
    done
}

# Fuzzy kill-picker for panes across all sessions (re-run until Esc).
# Complements prefix+w (navigate) and tmux-clean (bulk reap): point at a
# pane, Enter kills it. Killing a window's last pane closes the window;
# an emptied session exits on its own.
tmux-pick-kill() {
    command -v fzf >/dev/null 2>&1 || { echo "fzf not installed"; return 1; }
    tmux ls >/dev/null 2>&1 || { echo "no tmux server running"; return 1; }
    local target id
    while target="$(tmux list-panes -a -F '#{session_name}:#{window_index}.#{pane_index} #{pane_current_command} #{pane_current_path}' 2>/dev/null | fzf --prompt='kill pane> ' --header='Enter kills, Esc quits')"; do
        [ -n "$target" ] || return 0
        id="${target%% *}"
        echo "killing pane: $id"
        tmux kill-pane -t "$id" 2>/dev/null
    done
}

# --- comfort aliases ---
alias bashrc="${EDITOR:-nvim} ~/.bashrc"
alias reload="source ~/.bashrc"
alias i3config="${EDITOR:-nvim} ~/.config/i3/config"
alias m="micromamba"

notes() {
    if [ $# -eq 0 ]; then
        ls ~/Documents/notes
    else
        "${EDITOR:-nvim}" ~/Documents/"$1"
    fi
}

# --- prompt (only if starship is not taking over) ---
if ! command -v starship >/dev/null 2>&1; then
    export PS1='\[\e[32m\]λ:\[\e[34m\]$(__i3s_prompt_dir)\[\e[0m\]\$ '
fi

# --- tool init: guarded so a fresh machine without them still opens a shell ---
if command -v zoxide >/dev/null 2>&1; then
    eval "$(zoxide init bash)"
fi
if command -v micromamba >/dev/null 2>&1; then
    eval "$(micromamba shell hook --shell bash)"
fi
if command -v fzf >/dev/null 2>&1; then
    eval "$(fzf --bash)"  # Ctrl+R history, Ctrl+T files, Alt+C dirs
fi
# Uncomment to prefer starship over the fallback PS1 above:
# if command -v starship >/dev/null 2>&1; then
#     eval "$(starship init bash)"
# fi

# --- GTK_MODULES hygiene: appmenu-gtk-module segfaults blueman-manager ---
# /etc/profile.d/vala-panel-appmenu.sh (orphan config from removed
# vala-panel-appmenu-common) appends `appmenu-gtk-module` on every login
# shell, and even a single copy crashes blueman-manager with SIGSEGV
# (infinite recursion in libgtk-3). Neither i3 nor niri uses a global menu,
# so strip it user-wide and disable the proxy.
if [ -n "${GTK_MODULES:-}" ]; then
    _i3s_gtk=""; _i3s_sep=""; _i3s_oifs="$IFS"; IFS=":"
    for _i3s_m in $GTK_MODULES; do
        case "$_i3s_m" in ""|appmenu-gtk-module) continue;; esac
        case ":$_i3s_gtk:" in *":$_i3s_m:"*) continue;; esac
        _i3s_gtk="$_i3s_gtk$_i3s_sep$_i3s_m"; _i3s_sep=":"
    done
    IFS="$_i3s_oifs"; unset _i3s_oifs _i3s_m _i3s_sep
    export GTK_MODULES="$_i3s_gtk"; unset _i3s_gtk
fi
export UBUNTU_MENUPROXY=0
# <<< linux-setup <<<
