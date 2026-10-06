# >>> ubuntu-i3-setup — shell additions (appended by install.sh) >>>
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
# <<< ubuntu-i3-setup <<<
