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
# Uncomment to prefer starship over the fallback PS1 above:
# if command -v starship >/dev/null 2>&1; then
#     eval "$(starship init bash)"
# fi
# <<< ubuntu-i3-setup <<<
