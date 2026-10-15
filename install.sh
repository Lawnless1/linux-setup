#!/bin/bash
# linux-setup installer — niri Wayland desktop, any systemd distro
# (packages via pacman, apt or dnf; see packages/packages.tsv).
# Idempotent: safe to re-run. Backs up anything it overwrites to
# ~/.config/linux-setup/backups/<timestamp>/.
#
# Usage:
#   ./install.sh                  # link configs, shell additions, tmux, wallpaper
#   ./install.sh --all            # everything below, in order: fresh machine
#   ./install.sh --with-pkgs      # install session packages, enable NetworkManager/bluetooth/pipewire
#   ./install.sh --with-fonts     # download Nerd Fonts (Inter, FiraCode, DroidSansM)
#   ./install.sh --with-cursors   # download the wincursors theme
#   ./install.sh --with-builds    # source builds not yet in /usr/local: niri (only if
#                                 #   the distro lacks it), fuzzel, walker+elephant, noctalia
#   ./install.sh --with-greeter   # greetd + tuigreet login into niri, only if no display
#                                 #   manager is set up yet
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/pkg.sh
. "$REPO_DIR/scripts/lib/pkg.sh"
BACKUP_DIR="$HOME/.config/linux-setup/backups/$(date +%Y%m%d-%H%M%S)"
WITH_PKGS=0; WITH_FONTS=0; WITH_CURSORS=0; WITH_BUILDS=0; WITH_GREETER=0

for arg in "$@"; do
    case "$arg" in
        --all) WITH_PKGS=1; WITH_FONTS=1; WITH_CURSORS=1; WITH_BUILDS=1; WITH_GREETER=1;;
        --with-pkgs) WITH_PKGS=1;;
        --with-fonts) WITH_FONTS=1;;
        --with-cursors) WITH_CURSORS=1;;
        --with-builds) WITH_BUILDS=1;;
        --with-greeter) WITH_GREETER=1;;
        -h|--help) sed -n '2,16p' "$0"; exit 0;;
        *) echo "Unknown arg: $arg (see --help)"; exit 1;;
    esac
done

backup() {
    # backup <path> <intended-target>: move an existing file/symlink (not
    # already pointing at the target) to $BACKUP_DIR.
    if [ -e "$1" ] || [ -L "$1" ]; then
        if [ -L "$1" ] && [ "$(readlink "$1")" = "$2" ]; then return 0; fi
        rel="${1#"$HOME"/}"
        mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
        mv "$1" "$BACKUP_DIR/$rel"
        log "backed up ~/$rel"
    fi
}
link_to() {
    # link_to <repo-relative-src> <home-relative-dest>
    src="$REPO_DIR/$1"; dest="$HOME/$2"
    mkdir -p "$(dirname "$dest")"
    backup "$dest" "$src"
    ln -sfn "$src" "$dest"
    log "linked ~/$2"
}
unit_exists() { systemctl list-unit-files "$1" 2>/dev/null | grep -q "^$1"; }

# --- 1. packages + services ---------------------------------------------------------
if [ "$WITH_PKGS" -eq 1 ]; then
    pkg_install session
fi
if [ "$WITH_PKGS" -eq 1 ] && [ "${PKG_DRY_RUN:-0}" = 1 ]; then
    log "(PKG_DRY_RUN=1: not enabling services or changing groups)"
elif [ "$WITH_PKGS" -eq 1 ]; then
    # Noctalia's network/bluetooth/audio widgets talk to these services.
    # Never start NetworkManager next to another network daemon: two
    # managers fighting over the wifi device drops the connection.
    other_net=""
    for u in systemd-networkd.service iwd.service connman.service; do
        systemctl is-enabled "$u" >/dev/null 2>&1 && other_net="$u"
    done
    if [ -n "$other_net" ] && ! systemctl is-enabled NetworkManager.service >/dev/null 2>&1; then
        log "(warn: $other_net manages the network; NetworkManager left disabled — the bar's wifi menu needs it)"
    elif unit_exists NetworkManager.service; then
        as_root systemctl enable --now NetworkManager.service
    fi
    unit_exists bluetooth.service && as_root systemctl enable --now bluetooth.service
    systemctl --user enable --now pipewire.socket pipewire-pulse.socket wireplumber.service >/dev/null 2>&1 \
        || log "(warn: could not enable pipewire user units — enable them after first login)"
    for g in video render; do
        if getent group "$g" >/dev/null && ! id -nG | tr ' ' '\n' | grep -qx "$g"; then
            as_root usermod -aG "$g" "$USER" && log "added $USER to group $g (takes effect next login)"
        fi
    done
fi
[ "$WITH_PKGS" -eq 1 ] || log "skipping packages (re-run with --with-pkgs)"

# --- 2. configs (symlinked so `git pull` updates the live setup) -------------
link_to config/niri/config.kdl          .config/niri/config.kdl
link_to config/niri/niri-portals.conf   .config/xdg-desktop-portal/niri-portals.conf
link_to config/niri/scripts             .config/niri/scripts
link_to config/noctalia                 .config/noctalia
link_to config/fuzzel/fuzzel.ini        .config/fuzzel/fuzzel.ini
link_to config/fuzzel/fuzzel-dmenu.ini  .config/fuzzel/fuzzel-dmenu.ini
link_to config/walker                   .config/walker
link_to config/elephant/desktopapplications.toml .config/elephant/desktopapplications.toml
link_to config/foot/foot.ini            .config/foot/foot.ini
link_to config/swaylock/config          .config/swaylock/config
link_to config/starship.toml            .config/starship.toml
chmod +x "$REPO_DIR"/config/niri/scripts/*.sh "$REPO_DIR"/scripts/*.sh

# --- 3. tmux: oh-my-tmux framework (upstream clone, not vendored) + our overrides ---
if [ ! -d "$HOME/.tmux/.git" ]; then
    if command -v git >/dev/null 2>&1; then
        git clone --depth 1 https://github.com/gpakosz/.tmux.git "$HOME/.tmux"
        log "cloned oh-my-tmux into ~/.tmux"
    else
        log "(warn: git missing — cannot clone oh-my-tmux; re-run after --with-pkgs)"
    fi
fi
if [ -f "$HOME/.tmux/.tmux.conf" ]; then
    backup "$HOME/.tmux.conf" "$HOME/.tmux/.tmux.conf"
    ln -sfn "$HOME/.tmux/.tmux.conf" "$HOME/.tmux.conf"
    log "linked ~/.tmux.conf -> ~/.tmux/.tmux.conf"
fi
link_to config/tmux/tmux.conf.local     .tmux.conf.local

# --- 4. wallpaper (copied: Pictures/ is data, not config) ----------------------
mkdir -p "$HOME/Pictures/wallpaper"
for wp in "$REPO_DIR"/assets/wallpapers/*; do
    name="$(basename "$wp")"
    if [ ! -e "$HOME/Pictures/wallpaper/$name" ]; then
        cp "$wp" "$HOME/Pictures/wallpaper/$name"
        log "installed wallpaper $name"
    else
        log "wallpaper $name already present, skipping"
    fi
done

# --- 5. shell additions ---------------------------------------------------------
mkdir -p "$HOME/.bashrc.d"
link_to shell/bashrc.d-10-linux-setup.bashrc .bashrc.d/10-linux-setup.bashrc
touch "$HOME/.bashrc"
# Some distros (Fedora) already source ~/.bashrc.d from their stock ~/.bashrc;
# hooking it again would load everything twice.
if grep -q "bashrc\.d" "$HOME/.bashrc"; then
    log "~/.bashrc already sources ~/.bashrc.d"
else
    mkdir -p "$BACKUP_DIR"
    cp "$HOME/.bashrc" "$BACKUP_DIR/dot_bashrc.pre-hook"
    cat >> "$HOME/.bashrc" <<'EOF'

# linux-setup (managed by install.sh; safe to keep)
if [ -d "$HOME/.bashrc.d" ]; then
    for _f in "$HOME"/.bashrc.d/*.bashrc; do
        [ -r "$_f" ] && . "$_f"
    done
    unset _f
fi
EOF
    log "hooked .bashrc.d into ~/.bashrc"
fi
if [ ! -e "$HOME/.profile" ]; then
    link_to shell/profile .profile
else
    log "~/.profile exists, leaving it (repo copy at shell/profile for reference)"
fi

# --- 6. fonts + cursors ------------------------------------------------------------
[ "$WITH_FONTS" -eq 1 ] && "$REPO_DIR/scripts/install-fonts.sh"
[ "$WITH_CURSORS" -eq 1 ] && "$REPO_DIR/scripts/install-windows-cursors.sh"

# --- 7. source builds (each skipped once its binary exists; run the script
# directly to rebuild) ----------------------------------------------------------------
if [ "$WITH_BUILDS" -eq 1 ]; then
    if command -v niri >/dev/null 2>&1; then
        log "niri present ($(command -v niri)), skipping build-niri.sh"
    else
        "$REPO_DIR/scripts/build-niri.sh"
    fi
    [ -x /usr/local/bin/fuzzel ] || "$REPO_DIR/scripts/build-fuzzel.sh"
    { [ -x /usr/local/bin/walker ] && [ -x /usr/local/bin/elephant ]; } || "$REPO_DIR/scripts/build-walker.sh"
    [ -x /usr/local/bin/noctalia ] || "$REPO_DIR/scripts/build-noctalia.sh"
else
    log "skipping source builds (re-run with --with-builds)"
fi

# --- 8. greeter (never replaces an existing display manager) -------------------------
if [ "$WITH_GREETER" -eq 1 ]; then
    if [ -e /etc/systemd/system/display-manager.service ]; then
        log "display manager already set up ($(basename "$(readlink -f /etc/systemd/system/display-manager.service)")) — pick 'Niri' in its session menu"
    else
        pkg_install greeter
        greeter_user=""
        for u in greeter _greetd greetd; do getent passwd "$u" >/dev/null && { greeter_user="$u"; break; }; done
        [ -n "$greeter_user" ] || { log "greetd installed but its system user is missing"; exit 1; }
        [ -e /etc/greetd/config.toml ] && as_root cp /etc/greetd/config.toml "/etc/greetd/config.toml.linux-setup-bak"
        as_root install -d /etc/greetd
        as_root tee /etc/greetd/config.toml >/dev/null <<EOF
# Written by linux-setup install.sh --with-greeter.
[terminal]
vt = 1

[default_session]
command = "tuigreet --time --remember --asterisks --cmd niri-session"
user = "$greeter_user"
EOF
        as_root systemctl enable greetd.service
        log "greetd enabled: reboot to log in with tuigreet -> niri"
    fi
fi

# --- 9. niri owns the bar: mask a distro-enabled waybar user unit ---------------------
# Some distros enable waybar.service globally once waybar is installed; it
# would stack a second bar over Noctalia.
systemctl --user mask waybar.service >/dev/null 2>&1 || true

# --- 10. validate ----------------------------------------------------------------------
log "validating..."
"$REPO_DIR/scripts/check.sh" || true

log "done. Log in to the Niri session (niri hot-reloads its config). Backups (if any): $BACKUP_DIR"
