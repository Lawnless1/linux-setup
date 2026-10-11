#!/bin/bash
# ubuntu-i3-setup installer — Ubuntu 24.04 + i3.
# Idempotent: safe to re-run. Backs up anything it overwrites to
# ~/.config/ubuntu-i3-setup/backups/<timestamp>/.
#
# Usage:
#   ./install.sh                 # link configs, shell additions, wallpaper, input
#   ./install.sh --with-apt      # also sudo apt install packages/apt.txt (i3 session)
#   ./install.sh --with-niri     # also sudo apt install packages/apt-niri.txt (Wayland set;
#                                #   niri binary itself comes from scripts/build-niri.sh)
#   ./install.sh --with-doas     # also install /etc/doas.conf.d/10-power.conf (needs doas/sudo)
#   ./install.sh --with-fonts    # also download Nerd Fonts (Inter, FiraCode, DroidSansM)
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.config/ubuntu-i3-setup/backups/$(date +%Y%m%d-%H%M%S)"
WITH_APT=0; WITH_DOAS=0; WITH_FONTS=0; WITH_NIRI=0

for arg in "$@"; do
    case "$arg" in
        --with-apt) WITH_APT=1;;
        --with-niri) WITH_NIRI=1;;
        --with-doas) WITH_DOAS=1;;
        --with-fonts) WITH_FONTS=1;;
        -h|--help) sed -n '2,12p' "$0"; exit 0;;
        *) echo "Unknown arg: $arg (see --help)"; exit 1;;
    esac
done

log() { printf '==> %s\n' "$*"; }
backup() {
    # backup <path>: move existing file/symlink (not already ours) to $BACKUP_DIR.
    if [ -e "$1" ] || [ -L "$1" ]; then
        if [ -L "$1" ] && [ "$(readlink "$1")" = "$2" ]; then return 0; fi
        mkdir -p "$BACKUP_DIR"
        rel="${1#$HOME/}"
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

# --- 1. optional: system packages -------------------------------------------
if [ "$WITH_APT" -eq 1 ]; then
    log "installing apt packages..."
    # NOTE: NOT `apt update && apt install`: with `set -e`, a failed update
    # inside an &&-list silently skips the install instead of aborting.
    sudo apt update || { log "apt update FAILED — fix broken sources (see /etc/apt/sources.list.d/) and re-run"; exit 1; }
    # shellcheck disable=SC2046
    sudo apt install -y $(grep -v '^\s*#' "$REPO_DIR/packages/apt.txt" | grep -v '^\s*$' | xargs)
else
    log "skipping apt (re-run with --with-apt to install packages/apt.txt)"
fi

# --- 2. configs (symlinked so `git pull` updates the live setup) -------------
link_to config/i3/config               .config/i3/config
link_to config/picom/picom.conf        .config/picom/picom.conf
link_to config/polybar/custom          .config/polybar/custom
link_to config/rofi/config.rasi        .config/rofi/config.rasi
link_to config/rofi/powermenu.sh       .config/rofi/powermenu.sh
link_to config/rofi/themes             .config/rofi/themes
link_to config/flameshot/flameshot.ini .config/flameshot/flameshot.ini
link_to config/starship.toml           .config/starship.toml
link_to config/input                   .config/input
# --- niri (Wayland) session: keybindings mirror config/i3/config (see README) ---
link_to config/niri/config.kdl          .config/niri/config.kdl
link_to config/niri/niri-portals.conf   .config/xdg-desktop-portal/niri-portals.conf
link_to config/niri/scripts             .config/niri/scripts
link_to config/waybar                   .config/waybar
link_to config/fuzzel/fuzzel.ini        .config/fuzzel/fuzzel.ini
link_to config/fuzzel/fuzzel-dmenu.ini  .config/fuzzel/fuzzel-dmenu.ini
link_to config/walker                   .config/walker
link_to config/noctalia                 .config/noctalia
link_to config/dunst/dunstrc            .config/dunst/dunstrc
link_to config/foot/foot.ini            .config/foot/foot.ini
link_to config/swaylock/config          .config/swaylock/config

# --- 3. home files ------------------------------------------------------------
link_to home/.Xresources            .Xresources
# --- 3b. GNOME Terminal prefs (i3-sensible-terminal default; idempotent) -----------
if command -v gsettings >/dev/null 2>&1 && command -v gnome-terminal >/dev/null 2>&1; then
    chmod +x "$REPO_DIR/scripts/gnome-terminal-prefs.sh"  # runs before the chmod section below
    "$REPO_DIR/scripts/gnome-terminal-prefs.sh" || log "(warn: gnome-terminal prefs failed)"
else
    log "(skip: gnome-terminal prefs — gsettings/gnome-terminal missing)"
fi
link_to home/.xprofile              .xprofile
mkdir -p "$HOME/.screenlayout"
for f in laptop.sh layout.sh triple.sh; do
    link_to "home/.screenlayout/$f" ".screenlayout/$f"
done
chmod +x "$REPO_DIR"/home/.screenlayout/*.sh \
         "$REPO_DIR"/config/polybar/custom/launch.sh \
         "$REPO_DIR"/config/polybar/custom/scripts/*.sh \
         "$REPO_DIR"/config/rofi/powermenu.sh \
         "$REPO_DIR"/config/niri/scripts/*.sh \
         "$REPO_DIR"/config/waybar/launch.sh \
         "$REPO_DIR"/config/waybar/scripts/*.sh \
         "$REPO_DIR"/scripts/*.sh

# --- 4. wallpaper (copied: Pictures/ is data, not config) ----------------------
mkdir -p "$HOME/Pictures/wallpaper"
if [ ! -e "$HOME/Pictures/wallpaper/dark.jpg" ]; then
    cp "$REPO_DIR/assets/wallpapers/dark.jpg" "$HOME/Pictures/wallpaper/dark.jpg"
    log "installed wallpaper"
else
    log "wallpaper already present, skipping"
fi

# --- 5. shell additions ---------------------------------------------------------
mkdir -p "$HOME/.bashrc.d"
link_to shell/bashrc.d-10-ubuntu-i3-setup.bashrc .bashrc.d/10-ubuntu-i3-setup.bashrc
HOOK_MARKER="ubuntu-i3-setup (managed by install.sh"
if ! grep -q "$HOOK_MARKER" "$HOME/.bashrc" 2>/dev/null; then
    touch "$HOME/.bashrc"
    mkdir -p "$BACKUP_DIR"
    cp "$HOME/.bashrc" "$BACKUP_DIR/dot_bashrc.pre-hook"
    cat >> "$HOME/.bashrc" <<'EOF'

# ubuntu-i3-setup (managed by install.sh; safe to keep)
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

# --- 6. secrets skeleton ----------------------------------------------------------
mkdir -p "$HOME/.config/ubuntu-i3-setup"
if [ ! -e "$HOME/.config/ubuntu-i3-setup/env" ]; then
    cp "$REPO_DIR/config/env.example" "$HOME/.config/ubuntu-i3-setup/env"
    chmod 600 "$HOME/.config/ubuntu-i3-setup/env"
    log "created ~/.config/ubuntu-i3-setup/env — add your OPENWEATHER_API_KEY"
fi

# --- 7. optional: doas power rule ---------------------------------------------------
if [ "$WITH_DOAS" -eq 1 ]; then
    if command -v doas >/dev/null 2>&1; then
        sudo mkdir -p /etc/doas.conf.d
        sudo install -m 0444 -o root -g root /dev/null /etc/doas.conf.d/10-power.conf
        sed "s/__DOTFILES_USER__/$USER/g" "$REPO_DIR/system/doas.conf.d/10-power.conf.template" \
            | sudo tee /etc/doas.conf.d/10-power.conf >/dev/null
        if doas -C /etc/doas.conf.d/10-power.conf 2>&1 | grep -qi "parse error"; then
            log "WARNING: doas config failed to parse — inspect /etc/doas.conf.d/10-power.conf"
        else
            log "installed /etc/doas.conf.d/10-power.conf"
        fi
    else
        log "doas not installed; skipping (--with-apt includes opendoas as optional)"
    fi
fi

# --- 8. optional: nerd fonts ---------------------------------------------------------
if [ "$WITH_FONTS" -eq 1 ]; then
    "$REPO_DIR/scripts/install-fonts.sh"
fi

# --- 8b. optional: niri (Wayland) apt set ---------------------------------------------
if [ "$WITH_NIRI" -eq 1 ]; then
    log "installing apt packages for the niri session..."
    # NOTE: see --with-apt above: no &&-list here, a failed update must abort.
    sudo apt update || { log "apt update FAILED — fix broken sources (see /etc/apt/sources.list.d/) and re-run"; exit 1; }
    # shellcheck disable=SC2046
    sudo apt install -y $(grep -v '^\s*#' "$REPO_DIR/packages/apt-niri.txt" | grep -v '^\s*$' | xargs)
    log "niri binary still needed (not in Ubuntu repos): run ./scripts/build-niri.sh"
    # Noctalia bar (third-party APT repo; no-op if already installed).
    "$REPO_DIR/scripts/install-noctalia.sh"
else
    log "skipping niri apt set (re-run with --with-niri; then scripts/build-niri.sh)"
fi

# --- 8c. niri owns waybar: mask distro user unit so only launch.sh spawns it ---
# waybar.service is globally enabled on Ubuntu; left enabled it stacks a second
# bar under the one niri spawns via config/waybar/launch.sh.
if command -v systemctl >/dev/null 2>&1; then
    systemctl --user mask waybar.service >/dev/null 2>&1 || log "(warn: could not mask waybar.service)"
    systemctl --user disable --now waybar.service >/dev/null 2>&1 || true
else
    log "(skip: mask waybar.service — systemctl missing)"
fi

# --- 9. validate ----------------------------------------------------------------------
log "validating..."
bash -n "$REPO_DIR/scripts/tune-input.sh"
"$REPO_DIR/scripts/check.sh" || true

log "done. Reload i3 (Super+Shift+c) or log out/in. Backups (if any): $BACKUP_DIR"
