#!/usr/bin/env bash
# MehhsTMUXZSHSetup — one-shot installer for a uniform zsh + starship + tmux shell.
#
# Seeded from "slippy" (a Debian box), generalised to run on any of Zack's devices.
# It installs the dependencies, symlinks the dotfiles out of this repo into place,
# installs the tmux status-bar helper, and switches the login shell to zsh.
#
# Idempotent: safe to re-run. `git pull && ./install.sh` updates every device.
#
#   ./install.sh            full setup (installs deps, links dotfiles, sets shell)
#   ./install.sh --check    verify-only: report what's present/missing, change nothing
#   ./install.sh --no-chsh  do everything except change the login shell
#
# Dotfiles are SYMLINKED to this repo, so editing a file here + `git pull` on each
# box keeps them all in sync. Existing real files are backed up first.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP="$HOME/.mehh-dotfiles-backup"
CHECK=0; DO_CHSH=1
for a in "$@"; do
  case "$a" in
    --check)   CHECK=1 ;;
    --no-chsh) DO_CHSH=0 ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "unknown flag: $a" >&2; exit 2 ;;
  esac
done

say()  { printf '\n\033[1;36m== %s\033[0m\n' "$*"; }
ok()   { printf '   \033[32m✓\033[0m %s\n' "$*"; }
warn() { printf '   \033[33m!\033[0m %s\n' "$*"; }
err()  { printf '   \033[31m✗\033[0m %s\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }

# what maps where:  <repo path>  <destination>
DOTLINKS=(
  "dotfiles/zshenv|$HOME/.zshenv"
  "dotfiles/zshrc|$HOME/.zshrc"
  "dotfiles/starship.toml|$HOME/.config/starship.toml"
  "dotfiles/tmux.conf|$HOME/.tmux.conf"
)
BINLINKS=(
  "bin/mehh-statusbar|/usr/local/bin/mehh-statusbar"
  "bin/mehh-screensaver|/usr/local/bin/mehh-screensaver"
)
# runtime deps.  acpi is optional (battery line only); curl optional (weather line).
REQUIRED=(zsh tmux starship)
OPTIONAL=(curl acpi)

# ── package manager detection ────────────────────────────────────────────────
PM=""
detect_pm() {
  if   have apt-get; then PM="apt"
  elif have brew;    then PM="brew"
  elif have dnf;     then PM="dnf"
  elif have pacman;  then PM="pacman"
  fi
}
pkg_install() {
  local p="$1"
  case "$PM" in
    apt)    sudo apt-get install -y -qq "$p" ;;
    brew)   brew install "$p" ;;
    dnf)    sudo dnf install -y "$p" ;;
    pacman) sudo pacman -S --noconfirm "$p" ;;
    *) return 1 ;;
  esac
}

# ════════════════════════════════════════════════════════════════════════════
# --check : report only, mutate nothing
# ════════════════════════════════════════════════════════════════════════════
if [[ $CHECK -eq 1 ]]; then
  say "Checking dependencies"
  miss=0
  for c in "${REQUIRED[@]}"; do have "$c" && ok "$c ($(command -v "$c"))" || { err "$c MISSING"; miss=1; }; done
  for c in "${OPTIONAL[@]}"; do have "$c" && ok "$c (optional)" || warn "$c absent (optional — a greeting/statusbar line goes quiet)"; done
  say "Checking dotfile links"
  for pair in "${DOTLINKS[@]}" "${BINLINKS[@]}"; do
    src="$REPO/${pair%%|*}"; dst="${pair##*|}"
    if [[ "$(readlink -f "$dst" 2>/dev/null)" == "$src" ]]; then ok "$dst → repo"
    elif [[ -e "$dst" ]]; then warn "$dst exists but is NOT linked to this repo"
    else err "$dst missing"; miss=1; fi
  done
  say "Checking login shell"
  local_shell="$(getent passwd "$USER" | cut -d: -f7)"
  [[ "$local_shell" == *zsh ]] && ok "login shell is zsh ($local_shell)" || { warn "login shell is $local_shell (not zsh)"; }
  exit $miss
fi

# ════════════════════════════════════════════════════════════════════════════
# 0. preflight
# ════════════════════════════════════════════════════════════════════════════
say "Preflight"
[[ $EUID -eq 0 ]] && { err "Run as your normal user, not root — it sudos where needed."; exit 1; }
detect_pm
[[ -n "$PM" ]] && ok "package manager: $PM" || warn "no known package manager — you must install deps by hand"
ok "repo: $REPO"

# ════════════════════════════════════════════════════════════════════════════
# 1. dependencies
# ════════════════════════════════════════════════════════════════════════════
say "Dependencies"
[[ "$PM" == "apt" ]] && { sudo apt-get update -qq || warn "apt update failed — continuing"; }
for c in "${REQUIRED[@]}" "${OPTIONAL[@]}"; do
  if have "$c"; then ok "$c present"; continue; fi
  printf '   installing %s …\n' "$c"
  if pkg_install "$c" && have "$c"; then
    ok "$c installed"
  elif [[ "$c" == "starship" ]]; then
    warn "starship not in repos — using the official installer → ~/.local/bin"
    curl -fsSL https://starship.rs/install.sh | sh -s -- -y -b "$HOME/.local/bin" \
      && ok "starship installed to ~/.local/bin" || err "starship install failed"
  elif printf '%s\n' "${OPTIONAL[@]}" | grep -qx "$c"; then
    warn "$c unavailable (optional) — skipping"
  else
    err "$c could not be installed — install it by hand and re-run"; exit 1
  fi
done

# ════════════════════════════════════════════════════════════════════════════
# 2. dotfiles (symlink into place, backing up anything real that's in the way)
# ════════════════════════════════════════════════════════════════════════════
say "Dotfiles"
mkdir -p "$HOME/.config"
link_one() {                       # <src> <dst> [sudo]
  local src="$1" dst="$2" use_sudo="${3:-}" SUDO=""
  [[ "$use_sudo" == sudo ]] && SUDO="sudo"
  [[ -e "$src" ]] || { warn "source missing, skipping: $src"; return; }
  if [[ "$(readlink -f "$dst" 2>/dev/null)" == "$(readlink -f "$src")" ]]; then
    ok "linked already: $dst"; return
  fi
  if [[ -e "$dst" && ! -L "$dst" ]]; then     # back up a real file/dir
    mkdir -p "$BACKUP"
    $SUDO cp -a "$dst" "$BACKUP/$(basename "$dst").$(id -u)" 2>/dev/null || true
    warn "backed up existing $dst → $BACKUP/"
  fi
  $SUDO mkdir -p "$(dirname "$dst")"
  $SUDO ln -sfn "$src" "$dst"
  ok "linked $dst → ${src#$REPO/}"
}
for pair in "${DOTLINKS[@]}"; do link_one "$REPO/${pair%%|*}" "${pair##*|}"; done

# ════════════════════════════════════════════════════════════════════════════
# 3. bin helpers (tmux status-bar + optional screensaver) → /usr/local/bin
# ════════════════════════════════════════════════════════════════════════════
say "Helper scripts"
chmod +x "$REPO"/bin/* 2>/dev/null || true
for pair in "${BINLINKS[@]}"; do link_one "$REPO/${pair%%|*}" "${pair##*|}" sudo; done
if have tmux && tmux info >/dev/null 2>&1; then tmux source-file "$HOME/.tmux.conf" 2>/dev/null && ok "reloaded live tmux config" || true; fi

# ════════════════════════════════════════════════════════════════════════════
# 4. login shell → zsh
# ════════════════════════════════════════════════════════════════════════════
say "Login shell"
ZSH_BIN="$(command -v zsh)"
current_shell="$(getent passwd "$USER" | cut -d: -f7)"
if [[ "$current_shell" == "$ZSH_BIN" ]]; then
  ok "already zsh ($ZSH_BIN)"
elif [[ $DO_CHSH -eq 0 ]]; then
  warn "--no-chsh: leaving login shell as $current_shell (run 'chsh -s $ZSH_BIN' later)"
else
  grep -qx "$ZSH_BIN" /etc/shells || echo "$ZSH_BIN" | sudo tee -a /etc/shells >/dev/null
  if chsh -s "$ZSH_BIN" 2>/dev/null || sudo chsh -s "$ZSH_BIN" "$USER"; then
    ok "login shell set to $ZSH_BIN (takes effect on next login)"
  else
    warn "couldn't change shell automatically — run: chsh -s $ZSH_BIN"
  fi
fi

# ════════════════════════════════════════════════════════════════════════════
# 5. verify
# ════════════════════════════════════════════════════════════════════════════
say "Verify"
fail=0
for c in "${REQUIRED[@]}"; do have "$c" && ok "$c" || { err "$c missing"; fail=1; }; done
zsh -ic 'command -v starship >/dev/null && echo ok' >/dev/null 2>&1 \
  && ok "zsh loads starship cleanly" || warn "zsh/starship smoke test inconclusive"
if out="$(/usr/local/bin/mehh-statusbar 2>/dev/null)"; then ok "mehh-statusbar runs"; else warn "mehh-statusbar did not run"; fi

say "Done"
cat <<EOF

  Installed on: $(hostname)
  Next: open a NEW ssh/login session (or run 'exec zsh') to land in tmux with the
  starship prompt and status bar. Set MEHH_NO_TMUX=1 to skip the auto-tmux wrap.

  Re-run './install.sh' after a 'git pull' to update this box.
  Undo the shell change with:  chsh -s /bin/bash
EOF
