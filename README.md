# ubuntu-i3-setup

Private, replicable i3 desktop for Ubuntu 26.04. Symlinked configs + one installer.

![stack](https://img.shields.io/badge/Ubuntu-26.04-E95420) ![wm](https://img.shields.io/badge/i3-4.23-blue) ![bar](https://img.shields.io/badge/polybar-3.7-yellow)

## What's inside

| Path | Deploys to | Notes |
|---|---|---|
| `config/i3/config` | `~/.config/i3/config` | cleaned keybindings, gaps, volume/brightness keys |
| `config/input/pointer.sh` | `~/.config/input/pointer.sh` | **single source of truth** for mouse + touchpad speed |
| `config/niri/config.kdl` | `~/.config/niri/config.kdl` | niri Wayland session; keybindings mirror i3 (see below) |
| `config/niri/scripts/` | `~/.config/niri/scripts/` | fuzzel power menu (`Ctrl+Alt+Del`), grim/slurp screenshot (`$mod+Shift+s`) |
| `config/niri/niri-portals.conf` | `~/.config/xdg-desktop-portal/niri-portals.conf` | GNOME screencast/screenshot portals for niri |
| `config/waybar/` | `~/.config/waybar/` | retired waybar bar + scripts (dormant since the Noctalia switch; keep for revert) |
| `config/noctalia/config.toml` | `~/.config/noctalia/config.toml` | Noctalia 3-pill bar (niri session; needs `scripts/install-noctalia.sh` on 26.04+, plus `scripts/build-noctalia.sh` for the per-pill `blur_region` feature) |
| `config/fuzzel/fuzzel.ini` | `~/.config/fuzzel/fuzzel.ini` | Spotlight-like pill theme for the app grid (`$mod+d`) and text search (`$mod+F`; needs 1.12 from `scripts/build-fuzzel.sh`) |
| `config/walker/` | `~/.config/walker/` | walker omnibar theme + config (`$mod+space`; apps + indexed files with icons; needs `scripts/build-walker.sh`) |
| `config/elephant/desktopapplications.toml` | `~/.config/elephant/desktopapplications.toml` | elephant apps provider: `history_when_empty` so empty `$mod+space` ranks MRU/MFU, not alphabetical |
| `config/dunst/dunstrc` | `~/.config/dunst/dunstrc` | minimal notifications for the i3 session (niri uses the Noctalia daemon) |
| `config/swaylock/config` | `~/.config/swaylock/config` | screen locker (`Super+Alt+L`, idle, power menu) |
| `config/polybar/custom/` | `~/.config/polybar/custom/` | single `center` bar + curated scripts (wifi, sound, battery, bluetooth, weather, calendar, powermenu) |
| `config/rofi/` | `~/.config/rofi/` | drun config + Ctrl+Alt+Del power menu |
| `config/picom/picom.conf` | `~/.config/picom/picom.conf` | glx backend, rounded corners, blur |
| `config/flameshot/` | `~/.config/flameshot/` | screenshot tool (`$mod+Shift+s`) |
| `config/starship.toml` | `~/.config/starship.toml` | prompt theme (opt-in, see shell) |
| `home/.xprofile` | `~/.xprofile` | X-login loader for pointer speeds |
| `home/.screenlayout/` | `~/.screenlayout/` | laptop / docked-dual layouts, auto-selected |
| `home/.Xresources` | `~/.Xresources` | cursor theme (`wincursors` via `scripts/install-windows-cursors.sh`) |
| `shell/` | `~/.bashrc.d/` | prompt, git helpers, guarded tool init (zoxide, micromamba) |
| `assets/wallpapers/` | `~/Pictures/wallpaper/` | `dark.jpg` (the active one) |
| `system/doas.conf.d/` | `/etc/doas.conf.d/` | optional passwordless power actions |

Dropped from the original machine state (deliberately): 90MB of unused
polybar example themes, `config_old`/`config_mate` backups, VPN/Telegram/player
scripts referencing uninstalled apps, the committed OpenWeatherMap key
(now in `~/.config/ubuntu-i3-setup/env`, gitignored).

## Fresh machine

```bash
git clone <this-repo> ~/ubuntu-i3-setup && cd ~/ubuntu-i3-setup
./install.sh --with-apt --with-fonts   # add --with-doas for passwordless power menu
# log out/in, or: i3-msg restart
```
`install.sh` is idempotent — anything it overwrites is backed up to
`~/.config/ubuntu-i3-setup/backups/<timestamp>/`, and configs are symlinked
so `git pull` updates the live setup.

Weather module needs a free key (stays out of git):

```bash
cp config/env.example ~/.config/ubuntu-i3-setup/env
$EDITOR ~/.config/ubuntu-i3-setup/env   # set OPENWEATHER_API_KEY
```

## Daily use

```bash
scripts/tune-input.sh                       # show current pointer speeds
scripts/tune-input.sh --touchpad 0.4        # live-tune + persist
scripts/check.sh                            # validate binaries + configs
```

Pointer speeds persist in `config/input/pointer.sh` (`POINTER_MOUSE_SPEED`,
`POINTER_TOUCHPAD_SPEED`, default `0.8` / `0.3`), applied on X login
(`~/.xprofile`) and every `i3 restart`.

## Keybindings (see `config/i3/config` for all)

| Keys | Action |
|---|---|
| `$mod+Return` | terminal (fresh tmux session per window) |
| `$mod+d` / `$mod+space` | dmenu / rofi drun |
| `$mod+Shift+s` | flameshot screenshot |
| `$mod+j/k/l/;` + arrows | focus / move with Shift |
| `$mod+1..0` | workspaces |
| `$mod+r` | resize mode |
| `Ctrl+Alt+Del` | rofi power menu |
| media keys | volume / brightness via pactl / brightnessctl |

## Niri session (Wayland, side-by-side with i3)

Niri is a scrollable-tiling Wayland compositor: windows form a horizontal
strip of columns you scroll through, instead of i3's tree. It is **not** in
Ubuntu 24.04's repos, so the binary is compiled from source; everything else
(bar, launcher, locker) comes from apt. i3 stays untouched — pick
**Niri** vs **i3** at the login screen.

```bash
./install.sh --with-niri        # links niri/noctalia/fuzzel configs + apt Wayland set + Noctalia repo
./scripts/build-niri.sh         # sudo: build deps, rustup, compile niri + xwayland-satellite,
                                # install to /usr/local, add GDM session entry + systemd units
./scripts/build-fuzzel.sh       # sudo: build deps, compile fuzzel 1.12 (noble ships
                                # 1.9.2, which lacks the omnibar keys) to /usr/local
./scripts/build-walker.sh       # sudo: GTK4 deps, gtk4-layer-shell + elephant +
                                # walker (none packaged for noble) to /usr/local
bash scripts/check.sh           # must end ALL CHECKS PASSED
# log out, choose "Niri" at the login screen
```

`scripts/build-niri.sh` env knobs: `PREFIX=$HOME/.local` (user-local install),
`SKIP_XSATELLITE=1` (no X11 backend — Zoom/Steam/old toolkits won't run),
`SRC_DIR=` (where git sources live, default `~/.local/src`).
Intel/AMD GPUs need `video`+`render` group membership
(`sudo usermod -aG render $USER` if `check.sh`/build warns).

### i3 → niri keybinding map (`$mod` = Super in both)

Identical unless noted:

| i3 bind | niri bind | Notes |
|---|---|---|
| `$mod+Return` terminal | same key → **foot** running `tmux new-session` | Wayland-native instead of `gnome-terminal`; fresh tmux session per window |
| `Ctrl+Delete` kill | same | `close-window` |
| `$mod+d` dmenu / `$mod+space` rofi | `$mod+d` → **fuzzel** app grid; `$mod+space` → **walker** omnibar (apps + files, real icons); `$mod+F` → fuzzel text search | dmenu/rofi are X11-only |
| `$mod+j/k/l/;` + arrows focus | same | incl. i3 quirk: `$mod+Up` is fullscreen, **not** focus-up |
| `$mod+Shift+j/k/l/;` + arrows move | same (left/right use `move-column-*-or-to-monitor-*`) | left/right reorder on-screen, jump screens at edge |
| `$mod+h` / `$mod+v` split | `$mod+h` → consume/expel column; `$mod+v` → **clipboard history** (walker) | split-v bind yielded to Win+V parity; expel-right dropped |
| `$mod+Up` fullscreen | same (`Ctrl+F` left for apps/find) | `fullscreen-window` |
| `$mod+s` stacking / `$mod+w` tabbed / `$mod+e` toggle-split | same keys → tabbed display / maximize-column / center-column | approximations, niri has no i3 layouts |
| `$mod+Shift+space` floating | same | `toggle-window-floating` |
| `$mod+1..0` / `$mod+Shift+1..0` workspaces | same | workspaces 1..10 pre-created |
| `$mod+Ctrl+Shift+1..6` move to ws | same | kept for muscle memory |
| `$mod+Shift+e` exit nagbar | same keys → `quit` | niri's own confirm dialog |
| `$mod+r` resize mode | same key → cycle column widths | niri has no modal resize; `Minus/Equal` fine-tune size |
| `$mod+Shift+s` flameshot | same keys → grim+slurp script | flameshot is broken on Wayland; shot saved + copied |
| `Ctrl+Alt+Del` rofi powermenu | same keys → fuzzel powermenu | Lock uses swaylock, logout uses loginctl like i3 |
| media keys | same | identical pactl/brightnessctl commands |
| `$mod+a` focus parent | — | dropped: columns have no parent container |
| `$mod+Shift+c` reload / `$mod+Shift+r` restart | — | dropped: niri hot-reloads `config.kdl` on save |
| scratchpad (`$mod±minus`) | — | dropped: no niri equivalent; `Minus/Equal` resize instead |

Niri-native extras: `$mod+O` overview, `$mod+Shift+/` hotkey overlay,
`Super+Alt+L` lock, `Print`/`Ctrl+Print`/`Alt+Print` screenshots,
`$mod+V` clipboard history (walker + elephant provider: text + images,
pin with `Ctrl+p`, clear with `Ctrl+Shift+d`; `:` prefix inside
`$mod+space` queries it too),
`$mod+space`/`$mod+F` unified search (apps rank above folders above files; opens via entry/xdg-open),
auto-lock after 5 min idle (swayidle+swaylock).

Noctalia bar mirrors the polybar modules (workspaces/cpu/mem left, clock
center, network/bluetooth/sound/battery/powermenu right) as three floating
capsule groups with per-pill blur (ext-background-effect) — the forced
waybar blur smeared the whole bar width, which is why waybar was retired
(`config/waybar/` stays dormant). Network/bluetooth clicks open Noctalia's
native control-center tabs; wifi and bluetooth clicks used to open fuzzel
menus (`config/waybar/scripts/wifi-fuzzel.sh` — switch/join hidden/forget/
rescan/toggle plus nmtui fallback; `bluetooth-fuzzel.sh` — connect/pair),
kept as fallback.
