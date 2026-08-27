# MehhsTMUXZSHSetup

My portable terminal — a uniform **zsh + [starship](https://starship.rs) + tmux**
shell that looks and feels the same on every device. One repo holds every file
needed; one script installs it top to bottom.

Seeded from my box **slippy** (Debian 13) and generalised so it runs on any of my
machines.

## Quick start

```sh
git clone git@github.com:hiimzackjones/MehhsTMUXZSHSetup.git ~/.mehh-shell
cd ~/.mehh-shell
./install.sh
exec zsh          # or just re-SSH
```

To update a device later:

```sh
cd ~/.mehh-shell && git pull && ./install.sh
```

## What you get

- **zsh** with shared history, completion, and a **starship** prompt
  (`user@host  dir  git` → `❯`).
- **tmux** that **auto-starts on login** (over SSH, or on the physical console
  `tty1–6`) into a session named `main`, with a status bar showing
  `user@host`, active SSH count, battery, ETH/WiFi IPs, Tailscale IP, and a clock.
- A **login greeting**: date, battery (if present), and current weather.

Battery/weather/SSH-count lines are all self-guarding — on a desktop or VM with no
battery they simply go quiet. Hostname is read live, so the prompt and bar adapt
per machine automatically.

## What's in here

| Path | Installed to | What it is |
|---|---|---|
| `dotfiles/zshenv` | `~/.zshenv` | PATH |
| `dotfiles/zshrc` | `~/.zshrc` | history, completion, starship init, tmux auto-wrap, greeting |
| `dotfiles/starship.toml` | `~/.config/starship.toml` | prompt definition |
| `dotfiles/tmux.conf` | `~/.tmux.conf` | status bar, colours, mouse |
| `bin/mehh-statusbar` | `/usr/local/bin/mehh-statusbar` | tmux status-right (SSH/battery/net/TS) |
| `bin/mehh-screensaver` | `/usr/local/bin/mehh-screensaver` | optional idle screensaver (disabled by default) |

Dotfiles are **symlinked** back to this repo, so editing a file here and running
`git pull` on each box keeps every device in sync.

## The installer

`./install.sh` is idempotent and self-checking:

1. **Preflight** — refuses root, detects the package manager (apt/brew/dnf/pacman).
2. **Dependencies** — installs `zsh tmux starship` (+ optional `curl acpi`);
   falls back to starship's official installer if it isn't in your repos.
3. **Dotfiles** — symlinks them into place, backing up anything real it replaces
   to `~/.mehh-dotfiles-backup/`.
4. **Helpers** — installs the status-bar/screensaver scripts to `/usr/local/bin`.
5. **Login shell** — switches you to zsh (`chsh`).
6. **Verify** — confirms the tools resolve, zsh loads starship, and the status bar runs.

Flags:

- `./install.sh --check` — verify-only; reports what's present/missing, changes nothing.
- `./install.sh --no-chsh` — do everything except change the login shell.

## Opting out of auto-tmux

Set `MEHH_NO_TMUX=1` in the environment to get a plain zsh login without the tmux wrap.

## Undo

```sh
chsh -s /bin/bash                       # restore bash login
# dotfiles are symlinks; delete them and restore from ~/.mehh-dotfiles-backup/ if needed
```

## Enabling the tmux screensaver

Disabled by default (it's process-heavy on weak hardware). To enable, install one of
`cmatrix` / `cbonsai` / `hollywood`, then uncomment the two `lock-*` lines at the
bottom of `dotfiles/tmux.conf`.
