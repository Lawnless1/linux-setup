# AGENTS — ubuntu-i3-setup sync rule (READ THIS FIRST)

This machine's desktop setup is versioned. Live config and this repo must stay in sync.

- Repo: `~/ubuntu-i3-setup` → `git@github.com:Lawnless1/ubuntu-i3-setup.git` (private, branch `main`)
- Deploy method: symlinks via `./install.sh` (idempotent, backs up to `~/.config/ubuntu-i3-setup/backups/<ts>/`)

## Hard rule

If you make a **meaningful change** to the user's setup, you MUST also update this repo, commit, and push to `origin/main` in the same session. Do not leave the repo behind live config.

**Meaningful** = anything that should survive a reboot / fresh install:
- `~/.config/i3/config`, `~/.config/input/pointer.sh`, `~/.xprofile`
- `~/.config/polybar/custom/**`, `~/.config/rofi/**`, `~/.config/picom/picom.conf`
- `~/.screenlayout/**`, `~/.Xresources`, `~/.config/flameshot/*`, `~/.config/starship.toml`
- `~/.bashrc.d/10-ubuntu-i3-setup.bashrc`, `shell/profile` contents, wallpaper in `~/Pictures/wallpaper/`
- `packages/apt.txt`, `system/doas.conf.d/*`, `scripts/*`, `assets/wallpapers/*`
- niri session: `~/.config/niri/config.kdl`, `~/.config/niri/scripts/*`,
  `~/.config/xdg-desktop-portal/niri-portals.conf`, `~/.config/waybar/**`,
  `~/.config/fuzzel/fuzzel.ini`, `~/.config/swaylock/config`,
  `packages/apt-niri.txt`, `config/niri/niri.desktop`, `config/niri/systemd/*`

**Not meaningful** (skip repo update): read-only probes (`xinput list`, `i3 -C`), transient testing reverted before finishing, files outside the table in `README.md`.

## Workflow

1. Prefer editing the repo copy first, then `./install.sh` (or copy the file live for instant effect AND mirror it into the repo — never live-only).
2. Repo → live mapping is in `README.md` ("What's inside"). Key one: `config/input/pointer.sh` is the single source of truth for mouse (`0.8`) / touchpad (`0.3`) speeds — use `scripts/tune-input.sh`, never hard-code `xinput` ids.
3. Validate before commit:
   - `bash scripts/check.sh` (must end `ALL CHECKS PASSED`)
   - `i3 -C -c ~/.config/i3/config`
   - New/edited shell scripts: `bash -n` (or `sh -n`); `rofi-mixer.py`: `python3 -c "import ast; ast.parse(...)"`
4. No secrets, ever: no API keys, tokens (`ghp_`, `github_pat_`), private keys, or `~/.git-credentials` contents. Weather key goes in gitignored `~/.config/ubuntu-i3-setup/env` (see `config/env.example`); scan with `grep -rn "ghp_\|2ab04c7e\|BEGIN.*PRIVATE" . --exclude-dir=.git` plus `git grep -n "ghp_\|2ab04c7e" $(git rev-list --all)`.
5. Commit + push:
   ```bash
   git add -A && git status --short
   git commit -m "<short imperative summary>"
   GIT_SSH_COMMAND="ssh -o BatchMode=yes" git push
   GIT_SSH_COMMAND="ssh -o BatchMode=yes" git ls-remote origin HEAD  # confirm
   ```
   Keep history clean (squash `wip:`/fixup noise, one logical commit per change). Never `git push --force` without explicit user approval.
6. Leave the working tree clean (`git status --short` empty except intended untracked) and tell the user the commit hash + what synced.

`gh` CLI is NOT installed — use `git` over SSH as above. Token in `~/.git-credentials` is for the GitHub API only; do not print, commit, or paste it.
