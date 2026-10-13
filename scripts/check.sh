#!/bin/bash
# Sanity checks for linux-setup: required binaries, config links, config
# validity, script syntax. Exit 0 = all good. Used by install.sh.
set -u
FAIL=0
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
need() { command -v "$1" >/dev/null 2>&1 || { echo "MISSING: $1 ($2)"; FAIL=1; }; }
linked() { [ -e "$HOME/$1" ] && echo "linked ~/$1" || { echo "MISSING: ~/$1 (run ./install.sh)"; FAIL=1; }; }

echo "--- binaries ---"
for b in foot tmux fzf swaylock swayidle swaybg grim slurp wl-copy wl-paste wtype \
         pactl brightnessctl jq curl xdg-open notify-send identify loginctl; do
    need "$b" "./install.sh --with-pkgs"
done
command -v fd >/dev/null 2>&1 || command -v fdfind >/dev/null 2>&1 || { echo "MISSING: fd (./install.sh --with-pkgs)"; FAIL=1; }
command -v xwayland-satellite >/dev/null 2>&1 || echo "(info: xwayland-satellite missing — X11-only apps won't start)"
need niri "./install.sh --with-pkgs, or scripts/build-niri.sh"
need elephant "scripts/build-walker.sh"
need walker "scripts/build-walker.sh"
need noctalia "scripts/build-noctalia.sh"
for p in desktopapplications files clipboard; do
    [ -f "$HOME/.config/elephant/providers/$p.so" ] && echo "elephant provider $p OK" \
        || { echo "MISSING: elephant provider $p (scripts/build-walker.sh)"; FAIL=1; }
done

echo "--- gtk env (blueman crash guard) ---"
case ":${GTK_MODULES:-}:" in
    *:appmenu-gtk-module:*)
        echo "BAD GTK_MODULES (segfaults blueman-manager): $GTK_MODULES"
        echo "remove the global-menu package that adds it, or source shell/profile"
        FAIL=1;;
    *) echo "GTK_MODULES OK (${GTK_MODULES:-(unset)})";;
esac

echo "--- config links ---"
for f in .config/niri/config.kdl .config/xdg-desktop-portal/niri-portals.conf \
         .config/noctalia/config.toml .config/fuzzel/fuzzel.ini .config/walker/config.toml \
         .config/elephant/desktopapplications.toml .config/foot/foot.ini \
         .config/swaylock/config .bashrc.d/10-linux-setup.bashrc; do
    linked "$f"
done

echo "--- niri ---"
if command -v niri >/dev/null 2>&1; then
    niri validate --config "$HOME/.config/niri/config.kdl" >/dev/null 2>&1 \
        && echo "niri config OK" || { echo "niri config INVALID (niri validate)"; FAIL=1; }
fi

echo "--- noctalia ---"
if command -v noctalia >/dev/null 2>&1; then
    noctalia config validate "$HOME/.config/noctalia/config.toml" >/dev/null 2>&1 \
        && echo "noctalia config OK" || { echo "noctalia config INVALID"; FAIL=1; }
    grep -q "blurRegion\|blur_region" "$(command -v noctalia)" 2>/dev/null \
        && echo "noctalia has capsule-blur patch" \
        || echo "(info: stock noctalia — per-pill blur needs scripts/build-noctalia.sh)"
fi

echo "--- fuzzel ---"
# The omnibar config needs fuzzel >= 1.12; the pill patch ships via
# scripts/build-fuzzel.sh into /usr/local/bin.
if command -v fuzzel >/dev/null 2>&1; then
    fuzzel --version | head -1 | grep -Eq "version: 1\.(1[2-9]|[2-9][0-9])" \
        && echo "fuzzel >= 1.12 OK ($(command -v fuzzel))" \
        || { echo "OLD FUZZEL: $(fuzzel --version | head -1) — run ./scripts/build-fuzzel.sh"; FAIL=1; }
else
    echo "MISSING: fuzzel (scripts/build-fuzzel.sh)"; FAIL=1
fi

echo "--- tmux config ---"
if command -v tmux >/dev/null 2>&1 && [ -f "$HOME/.tmux.conf.local" ]; then
    # Throwaway server on its own socket, so errors surface without touching
    # live sessions. Only our overrides: oh-my-tmux's main file needs a real
    # client and kills a bare detached server.
    tmux -L linux-setup-check -f /dev/null new-session -d \; source-file "$HOME/.tmux.conf.local" \
        && echo "tmux overrides OK" || { echo "tmux overrides INVALID"; FAIL=1; }
    tmux -L linux-setup-check kill-server >/dev/null 2>&1
fi
[ -L "$HOME/.tmux.conf.local" ] && echo "tmux overrides linked" \
    || { echo "MISSING: ~/.tmux.conf.local symlink (run ./install.sh)"; FAIL=1; }
[ -f "$HOME/.tmux/.tmux.conf" ] && echo "oh-my-tmux present" \
    || { echo "MISSING: ~/.tmux (oh-my-tmux clone; run ./install.sh)"; FAIL=1; }

echo "--- shell syntax ---"
ok=1
while IFS= read -r f; do
    case "$f" in
        *.bashrc) bash -n "$f" || { echo "SYNTAX FAIL: $f"; ok=0; };;
        *) sh -n "$f" 2>/dev/null || bash -n "$f" || { echo "SYNTAX FAIL: $f"; ok=0; };;
    esac
done < <(find "$REPO_DIR/config" "$REPO_DIR/scripts" "$REPO_DIR/shell" "$REPO_DIR/install.sh" \
             \( -name "*.sh" -o -name "*.bashrc" \) 2>/dev/null)
sh -n "$REPO_DIR/shell/profile" || { echo "SYNTAX FAIL: shell/profile"; ok=0; }
[ "$ok" -eq 1 ] && echo "shell syntax OK" || FAIL=1

echo "--- package manifest ---"
awk -F'\t' '!/^#/ && NF && NF != 5 { print "BAD ROW " NR ": " $0; bad=1 } END { exit bad }' \
    "$REPO_DIR/packages/packages.tsv" && echo "packages.tsv OK" || FAIL=1

[ "$FAIL" -eq 0 ] && echo "ALL CHECKS PASSED" || echo "CHECKS FAILED"
exit "$FAIL"
