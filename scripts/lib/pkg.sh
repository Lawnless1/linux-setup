# Shared helpers for install.sh and scripts/build-*.sh (source, don't run).
# Package names live in packages/packages.tsv; this file only knows how to
# talk to each package manager.

LIB_REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PKG_MANIFEST="$LIB_REPO_DIR/packages/packages.tsv"

log() { printf '==> %s\n' "$*"; }

as_root() {
    if [ "$(id -u)" -eq 0 ]; then "$@"; else sudo "$@"; fi
}

pkg_manager() {
    if command -v pacman >/dev/null 2>&1; then echo pacman
    elif command -v apt-get >/dev/null 2>&1; then echo apt
    elif command -v dnf >/dev/null 2>&1; then echo dnf
    else echo none
    fi
}

# pkg_column <group...>: manifest cells for the current package manager,
# one name per line, deduped.
pkg_column() {
    local pm col
    pm="$(pkg_manager)"
    case "$pm" in pacman) col=3;; apt) col=4;; dnf) col=5;; *) return 1;; esac
    awk -F'\t' -v col="$col" -v groups=" $* " '
        /^#/ || NF < 5 { next }
        index(groups, " " $1 " ") {
            n = split($col, names, " ")
            for (i = 1; i <= n; i++) if (names[i] != "-" && !seen[names[i]]++) print names[i]
        }' "$PKG_MANIFEST"
}

_pkg_refreshed=0
pkg_refresh() {
    [ "$_pkg_refreshed" -eq 1 ] || [ "${PKG_DRY_RUN:-0}" = 1 ] && return 0
    case "$(pkg_manager)" in
        # Arch forbids partial upgrades: sync AND upgrade before installing.
        pacman) as_root pacman -Syu --noconfirm;;
        # NOT `apt-get update && ...`: under `set -e` a failed update inside
        # an &&-list is ignored instead of aborting.
        apt) as_root apt-get update;;
        dnf) as_root dnf makecache -y;;
    esac
    _pkg_refreshed=1
}

pkg_available() {
    case "$(pkg_manager)" in
        pacman) pacman -Si "$1" >/dev/null 2>&1;;
        apt) [ -n "$(apt-cache policy "$1" 2>/dev/null | awk '/Candidate:/ && $2 != "(none)"')" ];;
        dnf) dnf -q info "$1" >/dev/null 2>&1;;
        *) return 1;;
    esac
}

# pkg_install <group...>: install every package of the given manifest groups.
# PKG_DRY_RUN=1 prints what would be installed without touching the system;
# PKG_SKIP=1 skips installing (deps provided by hand on other distros).
pkg_install() {
    local pm name want=()
    pm="$(pkg_manager)"
    if [ "${PKG_SKIP:-0}" = 1 ]; then log "PKG_SKIP=1: assuming packages for '$*' are installed"; return 0; fi
    if [ "$pm" = none ]; then
        log "no supported package manager (pacman/apt/dnf). Install the equivalents of"
        log "these yourself (Arch package names shown as reference):"
        awk -F'\t' -v groups=" $* " '!/^#/ && NF == 5 && index(groups, " " $1 " ") {
            printf "      %-20s %s\n", $2, $3 }' "$PKG_MANIFEST"
        log "then re-run with PKG_SKIP=1."
        return 1
    fi
    pkg_refresh
    while IFS= read -r name; do
        case "$name" in
            *\?) name="${name%\?}"
                 if pkg_available "$name"; then want+=("$name")
                 else log "($name not packaged here — built from source instead)"; fi;;
            *) want+=("$name");;
        esac
    done < <(pkg_column "$@")
    [ "${#want[@]}" -gt 0 ] || return 0
    log "installing ($pm): ${want[*]}"
    if [ "${PKG_DRY_RUN:-0}" = 1 ]; then log "(PKG_DRY_RUN=1: not installing)"; return 0; fi
    case "$pm" in
        pacman) as_root pacman -S --needed --noconfirm "${want[@]}";;
        apt) as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y "${want[@]}";;
        dnf) as_root dnf install -y "${want[@]}";;
    esac
}

# Rust via rustup, not the distro: walker/niri track recent stable Rust.
ensure_rust() {
    export PATH="$HOME/.cargo/bin:$PATH"
    if ! command -v cargo >/dev/null 2>&1; then
        log "installing Rust via rustup (stable)..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal
    fi
    log "cargo: $(cargo --version)"
}

# ensure_go: Go >= 1.25 (elephant), from go.dev into ~/.local/go when the
# distro's is missing or too old. GO_VERSION= pins it.
ensure_go() {
    export PATH="$HOME/.local/go/bin:$PATH"
    export GOTOOLCHAIN=local
    if command -v go >/dev/null 2>&1 && go version | grep -Eq 'go1\.(2[5-9]|[3-9][0-9])'; then
        log "go: $(go version)"
        return 0
    fi
    local arch tmp
    case "$(uname -m)" in
        x86_64) arch=amd64;; aarch64|arm64) arch=arm64;; *) log "unsupported arch for Go: $(uname -m)"; return 1;;
    esac
    GO_VERSION="${GO_VERSION:-$(curl -fsSL 'https://go.dev/VERSION?m=text' | head -1)}"
    [ -n "$GO_VERSION" ] || { log "cannot determine Go version (set GO_VERSION=)"; return 1; }
    log "installing $GO_VERSION to ~/.local/go..."
    tmp="$(mktemp -d)"
    curl -fL -o "$tmp/go.tgz" "https://go.dev/dl/${GO_VERSION}.linux-${arch}.tar.gz"
    rm -rf "$HOME/.local/go"
    mkdir -p "$HOME/.local"
    tar -C "$HOME/.local" -xzf "$tmp/go.tgz"
    rm -rf "$tmp"
    log "go: $(go version)"
}

# Libraries installed under /usr/local by earlier builds (gtk4-layer-shell),
# across lib/, lib64/ (Fedora) and multiarch dirs (Debian).
export_local_pkgconfig() {
    local triplet
    triplet="$(gcc -dumpmachine 2>/dev/null || true)"
    export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:/usr/local/lib64/pkgconfig:/usr/local/share/pkgconfig${triplet:+:/usr/local/lib/$triplet/pkgconfig}${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
}

# git_checkout <url> <dir> <ref>: clone once, then fetch tags and check out.
git_checkout() {
    if [ -d "$2/.git" ]; then
        git -C "$2" fetch --tags -q origin
    else
        git clone -q "$1" "$2"
        git -C "$2" fetch --tags -q origin
    fi
    git -C "$2" checkout -q "$3"
}
