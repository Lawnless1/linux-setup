# ubuntu-i3-setup

Private, replicable i3 desktop for Ubuntu 24.04. Symlinked configs + one installer.

![stack](https://img.shields.io/badge/Ubuntu-24.04-E95420) ![wm](https://img.shields.io/badge/i3-4.23-blue) ![bar](https://img.shields.io/badge/polybar-3.7-yellow)

## What's inside

| Path | Deploys to | Notes |
|---|---|---|
| `config/i3/config` | `~/.config/i3/config` | cleaned keybindings, gaps, volume/brightness keys |
| `config/input/pointer.sh` | `~/.config/input/pointer.sh` | **single source of truth** for mouse + touchpad speed |
| `config/polybar/custom/` | `~/.config/polybar/custom/` | single `center` bar + curated scripts (wifi, sound, battery, bluetooth, weather, calendar, powermenu) |
| `config/rofi/` | `~/.config/rofi/` | drun config + Ctrl+Alt+Del power menu |
| `config/picom/picom.conf` | `~/.config/picom/picom.conf` | glx backend, rounded corners, blur |
| `config/flameshot/` | `~/.config/flameshot/` | screenshot tool (`$mod+Shift+s`) |
| `config/starship.toml` | `~/.config/starship.toml` | prompt theme (opt-in, see shell) |
| `home/.xprofile` | `~/.xprofile` | X-login loader for pointer speeds |
| `home/.screenlayout/` | `~/.screenlayout/` | laptop / docked-dual layouts, auto-selected |
| `home/.Xresources` | `~/.Xresources` | cursor theme |
| `shell/` | `~/.bashrc.d/` | prompt, git helpers, guarded tool init (zoxide, micromamba, atuin) |
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
| `$mod+Return` | terminal |
| `$mod+d` / `$mod+space` | dmenu / rofi drun |
| `$mod+Shift+s` | flameshot screenshot |
| `$mod+j/k/l/;` + arrows | focus / move with Shift |
| `$mod+1..0` | workspaces |
| `$mod+r` | resize mode |
| `Ctrl+Alt+Del` | rofi power menu |
| media keys | volume / brightness via pactl / brightnessctl |
