# linux-setup

Private, replicable [niri](https://github.com/YaLTeR/niri) Wayland desktop
for any systemd Linux distro: symlinked configs, one installer, and source
builds for the patched pieces. Packages come from the distro's own package
manager (pacman, apt or dnf), resolved through `packages/packages.tsv`.

The old X11 i3 session (i3, polybar, rofi, picom, flameshot, dunst) and the
retired waybar bar live on the `legacy-x11` branch.

## Fresh machine

Needs: a systemd distro, a user with `sudo`, `git`, and access to this
private repo (SSH key on GitHub, or clone over HTTPS with a token).

```bash
git clone git@github.com:Lawnless1/linux-setup.git ~/linux-setup
cd ~/linux-setup
./install.sh --all     # packages, configs, fonts, cursors, source builds, greeter
reboot                 # log in at tuigreet (or your display manager's "Niri" entry)
```

`--all` runs these steps in order (each is also its own flag):

| Flag | Does |
|---|---|
| `--with-pkgs` | installs the `session` group from `packages/packages.tsv`, enables NetworkManager + bluetooth + pipewire, adds you to `video`/`render` |
| `--with-fonts` | Nerd Fonts (Inter, FiraCode, DroidSansM) into `~/.local/share/fonts` |
| `--with-cursors` | `wincursors` (Windows 10) cursor theme |
| `--with-builds` | source builds, each skipped once its binary exists: niri + xwayland-satellite (only where the distro lacks them), fuzzel 1.12 + pill patch, walker + elephant, Noctalia + capsule-blur patch |
| `--with-greeter` | greetd + tuigreet launching `niri-session`, **only** if no display manager is set up yet |

The builds take about 30 minutes on 8 cores (Rust via rustup, Go via go.dev
when the distro's is older than 1.25). Run a `scripts/build-*.sh` directly to
force a rebuild.

### Distro support

| Distro family | Package manager | niri |
|---|---|---|
| Arch, EndeavourOS, Manjaro | pacman | from `extra` |
| Fedora | dnf | from Fedora repos |
| Debian, Ubuntu, Mint, Pop!_OS | apt | built from source (`scripts/build-niri.sh`) |
| anything else | — | the installer prints the dependency list (with Arch names as a reference); install the equivalents, then re-run with `PKG_SKIP=1` |

Every package name in the manifest is checked against Arch, Debian stable
and Fedora repos. `PKG_DRY_RUN=1 ./install.sh --with-pkgs` shows what would
be installed without changing anything.

## What's inside

| Path | Deploys to | Notes |
|---|---|---|
| `config/niri/config.kdl` | `~/.config/niri/config.kdl` | compositor, i3-style keybindings (see below), blur, window rules |
| `config/niri/scripts/` | `~/.config/niri/scripts/` | fuzzel power menu, frosted swaylock wrapper, file search, grim/slurp screenshot, clipboard paste |
| `config/niri/niri-portals.conf` | `~/.config/xdg-desktop-portal/niri-portals.conf` | GNOME screencast/screenshot portals |
| `config/niri/niri.desktop`, `config/niri/systemd/` | `/usr/share/wayland-sessions/`, `~/.config/systemd/user/` | session entry + units, installed by `scripts/build-niri.sh` only (distro niri packages ship their own) |
| `config/noctalia/` | `~/.config/noctalia/` | Noctalia bar, notifications and polkit agent; NavyGlass palette; per-pill blur needs `scripts/build-noctalia.sh` |
| `config/fuzzel/` | `~/.config/fuzzel/` | Spotlight-like pill (`$mod+d`, `$mod+F`, power menu; needs `scripts/build-fuzzel.sh`) |
| `config/walker/` | `~/.config/walker/` | walker omnibar + clipboard themes (`$mod+space`, `$mod+V`) |
| `config/elephant/desktopapplications.toml` | `~/.config/elephant/desktopapplications.toml` | `history_when_empty` so empty `$mod+space` ranks MRU/MFU |
| `config/foot/foot.ini` | `~/.config/foot/foot.ini` | terminal (`$mod+Return`, runs a fresh tmux session per window) |
| `config/tmux/tmux.conf.local` | `~/.tmux.conf.local` | overrides for [oh-my-tmux](https://github.com/gpakosz/.tmux) (installer clones it to `~/.tmux`, links `~/.tmux.conf`): `C-b` prefix + `C-a` secondary, mouse, OS clipboard, extended keys, `prefix+X` kill session, `prefix+Backspace` fuzzy pane killer |
| `config/swaylock/config` | `~/.config/swaylock/config` | screen locker (`Super+Alt+L`, idle, power menu; launched via `lock.sh`) |
| `config/starship.toml` | `~/.config/starship.toml` | prompt theme (opt-in: `export LINUX_SETUP_STARSHIP=1`) |
| `shell/bashrc.d-10-linux-setup.bashrc` | `~/.bashrc.d/` | prompt, git helpers, `tmux-clean` / `tmux-pick-kill`, guarded tool init (zoxide, micromamba, fzf) |
| `shell/profile` | `~/.profile` (only if absent) | PATH for the whole session (`~/.local/bin`, micromamba, opencode) |
| `assets/wallpapers/` | `~/Pictures/wallpaper/` | `dark.jpg` (desktop), `sunset-peaks.jpg` (lock screen); copied, not linked |
| `packages/packages.tsv` | — | one row per dependency, columns for pacman / apt / dnf |
| `scripts/lib/pkg.sh` | — | package-manager detection, install, rustup/Go helpers |
| `patches/`, `scripts/*.patch` | — | Noctalia capsule blur, fuzzel pill, walker preview size |

## Daily use

```bash
bash scripts/check.sh            # binaries, config links, niri/noctalia/tmux validation
./install.sh                     # re-link after pulling (idempotent)
```

Pointer speeds live in `config/niri/config.kdl` (`input` block: touchpad
`0.3`, mouse `0.5`); niri hot-reloads the file on save.

## Keybindings (`Mod` = Super)

| Keys | Action |
|---|---|
| `Mod+Return` | foot + fresh tmux session |
| `Mod+D` | fuzzel app grid |
| `Mod+Space` | walker omnibar (apps rank above folders above files; `:` queries clipboard) |
| `Mod+F` | fuzzel file search (fd) |
| `Mod+V` | clipboard history, pastes on select (pin `Ctrl+p`, clear `Ctrl+Shift+d`) |
| `Ctrl+Delete` | close window |
| `Mod+J/K/L/;` + arrows | focus (`Mod+Up` is fullscreen, not focus-up) |
| `Mod+Shift+J/K/L/;` + arrows | move (left/right jump monitors at the edge) |
| `Mod+H` | join/split column to the left |
| `Mod+S` / `Mod+W` / `Mod+E` | tabbed column / maximize column / center column |
| `Mod+Shift+Space` | toggle floating |
| `Mod+1..0`, `Mod+Shift+1..0` | focus / move to workspace 1..10 (`Mod+Ctrl+Shift+1..6` also moves) |
| `Mod+R` / `Mod+Shift+R` | cycle preset column widths |
| `Mod+Minus/Equal`, `Mod+Shift+Minus/Equal` | column width / window height ±10% |
| `Mod+Shift+S` | region screenshot (saved to `~/Pictures/Screenshots/` + copied) |
| `Print` / `Ctrl+Print` / `Alt+Print` | niri screenshot UI / screen / window |
| `Ctrl+Alt+Delete` | power menu (lock, logout, suspend, reboot, poweroff) |
| `Super+Alt+L` | lock (also after 5 min idle and before sleep) |
| `Mod+O` / `Mod+Shift+/` | overview / hotkey overlay |
| `Mod+Shift+E` | quit niri (asks first) |
| media keys | volume (pactl) / brightness (brightnessctl) |

The Noctalia bar shows workspaces, cpu/mem, clock, network, bluetooth,
sound, battery and power as floating capsule groups with per-pill blur
(ext-background-effect). Network/bluetooth clicks open Noctalia's
control-center tabs.
