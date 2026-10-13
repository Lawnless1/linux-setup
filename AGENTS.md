# AGENTS — linux-setup sync rule (READ THIS FIRST)

This machine's desktop setup is versioned. Live config and this repo must stay in sync.

- Repo: `~/linux-setup` → `git@github.com:Lawnless1/linux-setup.git` (private, branch `main`)
- Deploy method: symlinks via `./install.sh` (idempotent, backs up to `~/.config/linux-setup/backups/<ts>/`)

## Hard rule

If you make a **meaningful change** to the user's setup, you MUST also update this repo, commit, and push to `origin/main` in the same session. Do not leave the repo behind live config.

**Meaningful** = anything that should survive a reboot / fresh install:
- niri session: `~/.config/niri/config.kdl`, `~/.config/niri/scripts/*`,
  `~/.config/xdg-desktop-portal/niri-portals.conf`, `~/.config/noctalia/**`,
  `~/.config/fuzzel/*.ini`, `~/.config/walker/**`, `~/.config/elephant/desktopapplications.toml`,
  `~/.config/swaylock/config`, `~/.config/foot/foot.ini`, `config/niri/niri.desktop`, `config/niri/systemd/*`
- `~/.tmux.conf.local` (repo: `config/tmux/tmux.conf.local`; `~/.tmux/` is the upstream oh-my-tmux clone — never edit it)
- `~/.bashrc.d/10-linux-setup.bashrc`, `shell/profile` contents, `~/.config/starship.toml`, wallpaper in `~/Pictures/wallpaper/`
- `packages/packages.tsv`, `scripts/**`, `patches/*`, `assets/wallpapers/*`

**Not meaningful** (skip repo update): read-only probes (`niri msg`, `niri validate`), transient testing reverted before finishing, files outside the table in `README.md`.

## Portability rule

`main` must install on any systemd Wayland distro. No distro-specific commands, paths or package names outside `packages/packages.tsv` (one row per dependency, pacman/apt/dnf columns) and `scripts/lib/pkg.sh`. A new dependency gets a row with all three names — verify each exists in Arch, Debian stable and Fedora repos. Patched components (fuzzel, walker, elephant, Noctalia) build from source everywhere. X11/i3 work goes to the `legacy-x11` branch only.

## Workflow

1. Prefer editing the repo copy first, then `./install.sh` (or copy the file live for instant effect AND mirror it into the repo — never live-only).
2. Repo → live mapping is in `README.md` ("What's inside"). Pointer speeds live in the `input` block of `config/niri/config.kdl`.
3. Validate before commit:
   - `bash scripts/check.sh` (must end `ALL CHECKS PASSED`; runs `niri validate`, `noctalia config validate`, tmux and shell syntax)
   - New/edited shell scripts: `bash -n` (or `sh -n`)
   - Package changes: `PKG_DRY_RUN=1 ./install.sh --with-pkgs`
4. No secrets, ever: no API keys, tokens (`ghp_`, `github_pat_`), private keys, or `~/.git-credentials` contents. Local-only secrets go in gitignored `~/.config/linux-setup/env`; scan with `grep -rn "ghp_\|2ab04c7e\|BEGIN.*PRIVATE" . --exclude-dir=.git` plus `git grep -n "ghp_\|2ab04c7e" $(git rev-list --all)`.
5. Commit + push:
   ```bash
   git add -A && git status --short
   git commit -m "<short imperative summary>"
   GIT_SSH_COMMAND="ssh -o BatchMode=yes" git push
   GIT_SSH_COMMAND="ssh -o BatchMode=yes" git ls-remote origin HEAD  # confirm
   ```
   Keep history clean (squash `wip:`/fixup noise, one logical commit per change). Never `git push --force` without explicit user approval.
6. Leave the working tree clean (`git status --short` empty except intended untracked) and tell the user the commit hash + what synced.

## Comments (no vestigial comments)

- Explain *why*, never restate *what* the next line already says (`# Kill window` above `kill`).
- Never commit commented-out code — delete it, git history keeps it. No dead CSS/TOML/shell lines.
- No history narration for reverted experiments ("we tried X", "old Y branch removed"). Describe what IS, not what WAS.
- Keep comments truthful when code changes: update or delete them (no "commented out, re-add to restore" when nothing is commented out).

`gh` CLI is NOT installed — use `git` over SSH as above. Token in `~/.git-credentials` is for the GitHub API only; do not print, commit, or paste it.
