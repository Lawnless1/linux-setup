# >>> linux-setup — shell additions (appended by install.sh) >>>
# Kept separate from the distro's default ~/.bashrc so updates stay mergeable.
# Source order: interactive shells read ~/.bashrc, which sources
# ~/.bashrc.d/*.bashrc when present.

# --- compact two-level prompt: parent/current ---
__ls_prompt_dir() {
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
alias niriconfig="${EDITOR:-nvim} ~/.config/niri/config.kdl"
alias m="micromamba"

notes() {
    if [ $# -eq 0 ]; then
        ls ~/Documents/notes
    else
        "${EDITOR:-nvim}" ~/Documents/"$1"
    fi
}

# --- prompt: starship is opt-in (LINUX_SETUP_STARSHIP=1 before sourcing);
# the fallback PS1 only applies where starship is not installed at all.
if [ -n "${LINUX_SETUP_STARSHIP:-}" ] && command -v starship >/dev/null 2>&1; then
    eval "$(starship init bash)"
elif ! command -v starship >/dev/null 2>&1; then
    export PS1='\[\e[32m\]λ:\[\e[34m\]$(__ls_prompt_dir)\[\e[0m\]\$ '
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

# --- GTK_MODULES hygiene: appmenu-gtk-module segfaults blueman-manager ---
# Global-menu packages append `appmenu-gtk-module` from /etc/profile.d, and
# even a single copy crashes blueman-manager with SIGSEGV (infinite
# recursion in libgtk-3). niri has no global menu, so strip it user-wide.
if [ -n "${GTK_MODULES:-}" ]; then
    _ls_gtk=""; _ls_sep=""; _ls_oifs="$IFS"; IFS=":"
    for _ls_m in $GTK_MODULES; do
        case "$_ls_m" in ""|appmenu-gtk-module) continue;; esac
        case ":$_ls_gtk:" in *":$_ls_m:"*) continue;; esac
        _ls_gtk="$_ls_gtk$_ls_sep$_ls_m"; _ls_sep=":"
    done
    IFS="$_ls_oifs"; unset _ls_oifs _ls_m _ls_sep
    export GTK_MODULES="$_ls_gtk"; unset _ls_gtk
fi
# <<< linux-setup <<<
