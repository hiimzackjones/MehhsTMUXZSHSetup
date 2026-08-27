# MehhsTMUXZSHSetup

My portable terminal — a uniform **zsh + [starship](https://starship.rs) + tmux**
shell that looks and feels the same on every device, with modern replacements for
the commands I use constantly. One repo holds every file needed; one script
installs it top to bottom.

Seeded from my box **slippy** (Debian 13) and generalised so it runs on any of my
machines.

<!-- SCREENSHOT: login — a fresh SSH landing in tmux: greeting, starship prompt, status bar -->

## Quick start

```sh
git clone https://github.com/hiimzackjones/MehhsTMUXZSHSetup.git ~/.mehh-shell
cd ~/.mehh-shell
./install.sh
exec zsh          # or just re-SSH
```

To update a device later:

```sh
cd ~/.mehh-shell && git pull && ./install.sh
```

The dotfiles are **symlinks into this repo**, so a plain `git pull` already changes
your live shell. You only need to re-run `install.sh` when dependencies or symlinks
change.

## Forgotten how something works?

```sh
mehh
```

`mehh` is the built-in reference for everything this setup does *differently* from a
plain shell — the aliases, the replaced commands, the keys. `mehh <section>` for one
topic, `mehh -l` for the index. The login greeting points at it, so it is always one
word away.

<!-- SCREENSHOT: `mehh` output -->

## What you get

**The shell**

- **zsh** with shared live history (10k lines, no duplicates) across every pane and
  session, plus completion and a **starship** prompt.
- **[zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions)** — greys
  in the rest of a command from your history; `→` or `End` accepts it.
- **[zsh-syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting)** —
  commands turn green when valid and red when not, *before* you press Enter.

**Replaced commands**

- **[eza](https://eza.rocks)** replaces `ls`, with `ll` (long + git), `la` (long +
  hidden — the old `ls -la`) and `lt` (tree).
- **[zoxide](https://github.com/ajeetdsouza/zoxide)** replaces `cd`. Real paths,
  `cd -` and bare `cd` behave exactly as before, but `cd <fragment>` now jumps to any
  directory you have visited, ranked by how often and how recently. `cdi` opens an
  fzf picker over them.
- **[fzf](https://github.com/junegunn/fzf)** is wired into the line editor:
  `Ctrl-R` fuzzy history, `Ctrl-T` insert a file path, `Alt-C` cd, and `**<Tab>`
  fuzzy completion for any command.

<!-- SCREENSHOT: Ctrl-R fzf history overlay -->

**tmux**

- **Auto-starts on login** — over SSH or the physical console (`tty1–6`) — attaching
  to a session named `main`, so a dropped connection loses nothing and reconnecting
  puts you back where you were.
- A **status bar** showing `user@host`, active SSH count, battery, ETH/WiFi IPs,
  Tailscale IP, and a clock.
- **[TPM](https://github.com/tmux-plugins/tpm)** for plugins — `prefix + I` installs,
  `prefix + U` updates.
- Mouse on: click panes, drag borders, scroll.

**Extras**

- **[btop](https://github.com/aristocratos/btop)** system monitor, configured to
  Dracula, transparent background, sorted by PID.
- A **login greeting**: date, uptime, battery (if present), current weather, and the
  pointer to `mehh`.

<!-- SCREENSHOT: btop running -->

Battery / weather / SSH-count lines are all self-guarding — on a desktop or VM with
no battery they simply go quiet. Hostname is read live, so the prompt and bar adapt
per machine automatically. Every tool above is optional: if one is missing, the piece
of config that uses it goes quiet rather than erroring.

## What's in here

| Path | Installed to | What it is |
|---|---|---|
| `dotfiles/zshenv` | `~/.zshenv` | PATH |
| `dotfiles/zshrc` | `~/.zshrc` | history, completion, starship, eza, zoxide, fzf, plugins, tmux auto-wrap, greeting |
| `dotfiles/starship.toml` | `~/.config/starship.toml` | prompt definition |
| `dotfiles/tmux.conf` | `~/.tmux.conf` | status bar, colours, mouse, TPM |
| `bin/mehh` | `/usr/local/bin/mehh` | the reference command |
| `bin/mehh-statusbar` | `/usr/local/bin/mehh-statusbar` | tmux status-right (SSH/battery/net/TS) |
| `bin/mehh-screensaver` | `/usr/local/bin/mehh-screensaver` | optional idle screensaver (disabled by default) |

Two things deliberately live **outside** the repo, because they are per-machine:

- `~/.config/mehh/location` — the weather location. Boxes live in different places.
- `~/.config/btop/btop.conf` — btop rewrites this file wholesale on exit, so
  symlinking it would dirty git on every launch and let a version bump on one machine
  rewrite it for all of them. `install.sh` applies only the three settings that
  matter and leaves the other ~66 alone.

## The installer

`./install.sh` is idempotent and self-checking:

1. **Preflight** — refuses root, detects the package manager (apt/brew/dnf/pacman).
2. **Dependencies** — installs `zsh tmux starship` as required; `curl acpi eza zoxide
   fzf btop zsh-autosuggestions zsh-syntax-highlighting` as optional, so an unusual
   package set still yields a working shell. Falls back to starship's official
   installer if it isn't in your repos.
3. **Dotfiles** — symlinks them into place, backing up anything real it replaces to
   `~/.mehh-dotfiles-backup/`.
4. **Helpers** — installs `mehh` and the status-bar/screensaver scripts to `/usr/local/bin`.
5. **tmux plugins** — clones TPM and installs the plugins listed in `tmux.conf`.
6. **btop** — applies the theme/background/sort settings.
7. **Weather location** — asks where this machine is (default `Cashiers NC`); stores
   it per-machine.
8. **Login shell** — switches you to zsh (`chsh`).
9. **Verify** — confirms the tools resolve, zsh loads starship, and the status bar runs.

Flags:

- `./install.sh --check` — verify-only; reports what's present/missing, changes nothing.
- `./install.sh --no-chsh` — do everything except change the login shell.
- `./install.sh --location="Asheville NC"` — set the weather location without being asked.

<!-- SCREENSHOT: ./install.sh --check output, all green -->

## Configuration

| Variable / file | Effect |
|---|---|
| `MEHH_NO_TMUX=1` | log in without the tmux wrap |
| `MEHH_WEATHER_LOCATION` | override the weather location for one session |
| `~/.config/mehh/location` | this machine's weather location (set by the installer) |

## Undo

```sh
chsh -s /bin/bash                       # restore bash login
# dotfiles are symlinks; delete them and restore from ~/.mehh-dotfiles-backup/ if needed
```

## Enabling the tmux screensaver

Disabled by default — `hollywood` in particular spawns dozens of processes and will
pin a weak box. To enable, install one of `cmatrix` / `cbonsai` / `hollywood`, then
uncomment the two `lock-*` lines at the bottom of `dotfiles/tmux.conf`.
