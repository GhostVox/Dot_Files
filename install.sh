#!/usr/bin/env bash
#
# Dot_Files bootstrap — Arch Linux + Hyprland + Noctalia
#
#   ./install.sh              full run
#   ./install.sh --dry-run    print what would happen, change nothing
#   ./install.sh --no-pkgs    configs/symlinks only, skip all package installs
#   ./install.sh --help
#
# Idempotent: safe to re-run. Existing configs are backed up, never clobbered.
# Must be run from a real terminal (sudo needs a TTY to prompt).

set -euo pipefail

REPO_URL="https://github.com/GhostVox/Dot_Files.git"
TARGET="$HOME/.config/Dot_Files"
NVIM_SUBMODULE="nvim"
BACKUP_DIR="$HOME/.config/dotfiles-backup-$(date +%Y%m%d-%H%M%S)"

DRY_RUN=0
SKIP_PKGS=0

# ── Packages ────────────────────────────────────────────────────────────────
# Scoped to the Noctalia setup. Noctalia natively provides the bar, launcher,
# notifications, clipboard, wallpaper, session/power menu, lock screen,
# screenshots, screen recording, and Wi-Fi/Bluetooth/brightness/volume control —
# so waybar, rofi, swaync, wlogout, walker, cliphist, hyprpaper, hyprlock,
# hyprshot, wf-recorder, satty, blueman, pavucontrol, brightnessctl,
# network-manager-applet and qalculate-gtk are all intentionally absent.

PACMAN_PKGS=(
  # core desktop
  hypridle nautilus networkmanager wl-clipboard playerctl ddcutil
  # apps bound to keys
  ghostty firefox thunderbird zed neovim tmux lazygit
  # backend for Noctalia's screen_recorder plugin
  gpu-screen-recorder
  # shell — every one of these is required by .zshrc
  zsh zsh-syntax-highlighting starship fastfetch fzf zoxide aws-cli
  # dev toolchain
  rustup go nodejs npm docker base-devel
  # hypr/read.sh (Super+I)
  speech-dispatcher espeak-ng
  # fonts
  ttf-jetbrains-mono-nerd ttf-fira-code noto-fonts
  # utilities
  imagemagick btop baobab zip unzip
)

# NOTE ON THE NOCTALIA PACKAGE NAME — this one is a trap. Three candidates:
#   aur/noctalia-git    5.0.0.rNNNN  -> what we want; 1000+ commits past the 5.0.0 tag
#   aur/noctalia        5.0.0_beta.6 -> a PRE-release of 5.0.0, older than it looks.
#                                       Renamed `notification-send` to
#                                       `notification-show` and has no
#                                       `screenshot-window`, so binds break.
#   aur/noctalia-shell  4.7.7        -> v4. Ships NO cli at all; driven by
#                                       `qs -c noctalia-shell ipc call ...`.
#                                       Installs cleanly and silently breaks everything.
# The Hyprland config here is v5-only (see the "NOCTALIA v5 NATIVE BINDINGS"
# block in hypr/config/keybinds.conf) and tracks current v5, so use noctalia-git.
AUR_PKGS=(
  noctalia-git     # v5 current. NOT `noctalia` (beta) and NOT `noctalia-shell` (v4)
  oh-my-zsh-git    # .zshrc hard-sources /usr/share/oh-my-zsh/oh-my-zsh.sh
)

# Noctalia IPC commands the Hyprland config depends on. Verified against the
# installed binary at the end of the run — a version bump that renames one of
# these leaves the bind silently dead, which is exactly how the beta bit us.
NOCTALIA_CMDS=(
  notification-send screenshot-region
  "panel-toggle launcher" "panel-toggle clipboard" "panel-toggle session"
  "panel-toggle wallpaper" "panel-toggle control-center"
  window-switcher config-reload
)

# Dirs symlinked from the repo into ~/.config/
CONFIG_LINKS=(hypr kitty ghostty nvim tmux lazygit zed zsh)
# Individual files: "repo-relative:destination"
FILE_LINKS=(
  "starship.toml:$HOME/.config/starship.toml"
  ".zshrc:$HOME/.zshrc"
  ".ideavimrc:$HOME/.ideavimrc"
)
# Created empty; referenced by .zshrc / hypr scripts
MAKE_DIRS=(
  "$HOME/Pictures/wallpapers"
  "$HOME/Pictures/Screenshots"
  "$HOME/Videos/Screencasts"
  "$HOME/.npm-global"
)

# ── Output ──────────────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
  R=$'\e[31m'; G=$'\e[32m'; Y=$'\e[33m'; B=$'\e[34m'; D=$'\e[2m'; N=$'\e[0m'
else
  R=''; G=''; Y=''; B=''; D=''; N=''
fi

step() { printf '\n%s==>%s %s\n' "$B" "$N" "$*"; }
ok()   { printf '  %s✓%s %s\n' "$G" "$N" "$*"; }
warn() { printf '  %s!%s %s\n' "$Y" "$N" "$*"; }
err()  { printf '  %s✗%s %s\n' "$R" "$N" "$*" >&2; }
skip() { printf '  %s·%s %s\n' "$D" "$N" "$*"; }

run() {
  if (( DRY_RUN )); then
    printf '  %s[dry-run]%s %s\n' "$D" "$N" "$*"
  else
    "$@"
  fi
}

usage() { sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --no-pkgs) SKIP_PKGS=1 ;;
    -h|--help) usage ;;
    *) err "unknown option: $1"; exit 2 ;;
  esac
  shift
done

(( DRY_RUN )) && warn "DRY RUN — nothing will be changed"

# ── 1. Preflight ────────────────────────────────────────────────────────────
step "Preflight"

[[ -f /etc/os-release ]] && . /etc/os-release || true
if [[ "${ID:-}" != "arch" ]]; then
  err "This script targets Arch Linux (found: ${ID:-unknown}). Aborting."
  exit 1
fi
ok "Arch Linux"

if [[ $EUID -eq 0 ]]; then
  err "Do not run as root — it would create root-owned files in \$HOME."
  exit 1
fi
ok "running as $USER"

if (( ! SKIP_PKGS )) && [[ ! -t 0 ]]; then
  err "No TTY. sudo can't prompt for a password here."
  err "Run this from a real terminal, or use --no-pkgs for configs only."
  exit 1
fi

if ! command -v git >/dev/null; then
  err "git is required to bootstrap. Install it: sudo pacman -S git"
  exit 1
fi
ok "git present"

# ── 2. Repo in place ────────────────────────────────────────────────────────
step "Dotfiles repo"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

if [[ -d "$TARGET/.git" ]]; then
  ok "already at $TARGET"
elif [[ -d "$SCRIPT_DIR/.git" ]]; then
  # Running from a clone somewhere else (e.g. ~/Downloads) — relocate it.
  warn "moving $SCRIPT_DIR -> $TARGET"
  run mkdir -p "$(dirname "$TARGET")"
  run mv "$SCRIPT_DIR" "$TARGET"
  ok "relocated"
else
  warn "cloning $REPO_URL"
  run git clone "$REPO_URL" "$TARGET"
  ok "cloned"
fi

# .zshrc hardcodes $HOME/.config/Dot_Files/starship.toml, so this path matters.

# ── 3. nvim submodule ───────────────────────────────────────────────────────
step "nvim submodule"

if [[ -f "$TARGET/$NVIM_SUBMODULE/init.lua" ]]; then
  ok "already initialised"
else
  # NOTE: a plain `git submodule update --init` fails repo-wide because
  # ghostty/shaders is recorded as a gitlink in the index but has no
  # .gitmodules entry. Initialising nvim by name sidesteps it.
  run git -C "$TARGET" submodule update --init "$NVIM_SUBMODULE"
  ok "initialised (kickstart.nvim)"
fi

# ── 4. Back up + symlink ────────────────────────────────────────────────────
step "Symlinks"

backup() {
  local path="$1"
  [[ -e "$path" || -L "$path" ]] || return 0
  # An existing correct symlink into the repo needs no backup.
  if [[ -L "$path" && "$(readlink -f "$path")" == "$TARGET"/* ]]; then
    return 1
  fi
  run mkdir -p "$BACKUP_DIR"
  run mv "$path" "$BACKUP_DIR/"
  warn "backed up $(basename "$path") -> $BACKUP_DIR/"
  return 0
}

link() {
  local src="$1" dest="$2"
  if [[ ! -e "$src" ]]; then
    warn "missing in repo, skipping: $src"
    return
  fi
  if [[ -L "$dest" && "$(readlink -f "$dest")" == "$(readlink -f "$src")" ]]; then
    skip "$(basename "$dest") already linked"
    return
  fi
  backup "$dest" || true
  run ln -sfn "$src" "$dest"
  ok "$dest -> $src"
}

run mkdir -p "$HOME/.config"
for d in "${CONFIG_LINKS[@]}"; do
  link "$TARGET/$d" "$HOME/.config/$d"
done
for pair in "${FILE_LINKS[@]}"; do
  link "$TARGET/${pair%%:*}" "${pair#*:}"
done

# ── 5. Directories + exec bits ──────────────────────────────────────────────
step "Directories"

for d in "${MAKE_DIRS[@]}"; do
  if [[ -d "$d" ]]; then skip "$d"; else run mkdir -p "$d"; ok "$d"; fi
done

for s in "$TARGET"/hypr/*.sh; do
  [[ -e "$s" ]] || continue
  [[ -x "$s" ]] || { run chmod +x "$s"; ok "chmod +x $(basename "$s")"; }
done

# ── 6. Repo packages ────────────────────────────────────────────────────────
if (( SKIP_PKGS )); then
  step "Packages"; skip "--no-pkgs, skipping"
else
  step "Repo packages (pacman)"

  missing=()
  for p in "${PACMAN_PKGS[@]}"; do
    pacman -Q "$p" &>/dev/null || missing+=("$p")
  done

  if (( ${#missing[@]} == 0 )); then
    ok "all ${#PACMAN_PKGS[@]} already installed"
  else
    warn "${#missing[@]} to install: ${missing[*]}"
    run sudo pacman -S --needed --noconfirm "${missing[@]}"
    ok "done"
  fi

  # ── 7. AUR ────────────────────────────────────────────────────────────────
  step "AUR"

  if command -v yay >/dev/null; then
    ok "yay present"
  else
    warn "bootstrapping yay"
    tmp="$(mktemp -d)"
    run git clone --depth 1 https://aur.archlinux.org/yay.git "$tmp/yay"
    if (( ! DRY_RUN )); then
      ( cd "$tmp/yay" && makepkg -si --noconfirm )
    fi
    run rm -rf "$tmp"
    ok "yay installed"
  fi

  aur_missing=()
  for p in "${AUR_PKGS[@]}"; do
    pacman -Q "$p" &>/dev/null || aur_missing+=("$p")
  done

  if (( ${#aur_missing[@]} == 0 )); then
    ok "AUR packages already installed"
  else
    warn "building: ${aur_missing[*]} (noctalia-shell takes a few minutes)"
    run yay -S --needed --noconfirm "${aur_missing[@]}"
    ok "done"
  fi

  # ── 8. Post-install ───────────────────────────────────────────────────────
  step "Post-install"

  if [[ "$(getent passwd "$USER" | cut -d: -f7)" == "$(command -v zsh)" ]]; then
    skip "login shell already zsh"
  else
    warn "changing login shell to zsh (password prompt)"
    run chsh -s "$(command -v zsh)"
    ok "shell changed — takes effect next login"
  fi

  if rustup toolchain list 2>/dev/null | grep -q stable; then
    skip "rust stable present"
  else
    run rustup install stable
    ok "rust stable"
  fi

  if [[ "$(npm config get prefix 2>/dev/null)" == "$HOME/.npm-global" ]]; then
    skip "npm prefix set"
  else
    run npm config set prefix "$HOME/.npm-global"
    ok "npm prefix -> ~/.npm-global"
  fi

  if systemctl is-enabled docker &>/dev/null; then
    skip "docker enabled"
  else
    run sudo systemctl enable --now docker
    ok "docker enabled"
  fi

  if id -nG "$USER" | grep -qw docker; then
    skip "already in docker group"
  else
    run sudo usermod -aG docker "$USER"
    warn "added to docker group — log out and back in to take effect"
  fi
fi

# ── 9. Verify ───────────────────────────────────────────────────────────────
step "Verify"

fail=0

while IFS= read -r broken; do
  err "broken symlink: $broken"; fail=1
done < <(find "$HOME/.config" -maxdepth 1 -xtype l 2>/dev/null; \
         find "$HOME" -maxdepth 1 -xtype l 2>/dev/null)

for f in "$HOME/.zshrc" "$HOME/.config/hypr/hyprland.conf" \
         "$HOME/.config/nvim/init.lua" "$HOME/.config/starship.toml"; do
  if [[ -e "$f" ]]; then ok "$f"; else err "missing: $f"; fail=1; fi
done

# .zshrc sources these unguarded — a missing one means errors on every shell start.
if (( ! SKIP_PKGS )); then
  for f in /usr/share/oh-my-zsh/oh-my-zsh.sh /usr/bin/aws_zsh_completer.sh; do
    if [[ -e "$f" ]]; then
      ok "$f"
    else
      err "MISSING: $f — .zshrc sources this unguarded, every new shell will error"
      fail=1
    fi
  done

  # Guard against the package mixup: v4 installs fine but ships no CLI at all,
  # which would leave every `noctalia msg` bind silently dead.
  if ! command -v noctalia >/dev/null; then
    err "'noctalia' CLI not on PATH — every 'noctalia msg' bind will do nothing."
    if pacman -Q noctalia-shell &>/dev/null; then
      err "  Cause: noctalia-shell (v4) is installed. It ships no CLI."
      err "  Fix:   sudo pacman -R noctalia-shell && yay -S noctalia-git"
    fi
    fail=1
  else
    ok "noctalia CLI: $(noctalia --version 2>&1 | head -1)"

    # Every command the config uses must exist in this build. Renames between
    # versions are silent at runtime — the keybind just does nothing.
    absent=()
    bin="$(command -v noctalia)"
    for c in "${NOCTALIA_CMDS[@]}"; do
      grep -aqF "$c" "$bin" || absent+=("$c")
    done
    if (( ${#absent[@]} == 0 )); then
      ok "all ${#NOCTALIA_CMDS[@]} IPC commands present in this build"
    else
      err "this Noctalia build is missing: ${absent[*]}"
      err "  Those keybinds will silently do nothing."
      err "  Usually means a beta/older package — try: yay -S noctalia-git"
      fail=1
    fi
  fi
fi

printf '\n'
if (( DRY_RUN )); then
  warn "dry run complete — nothing was changed"
elif (( fail )); then
  err "finished with problems (see above)"
  exit 1
else
  ok "${G}Setup complete.${N}"
  [[ -d "$BACKUP_DIR" ]] && warn "previous configs backed up to $BACKUP_DIR"
  cat <<EOF

  Next:
    - log out / back in (picks up zsh, docker group, Noctalia autostart)
    - verify the one unconfirmed keybind:
        noctalia msg --help | grep -i screenshot
      If there's no top-level 'screenshot-window', fix the Ctrl+Shift+4 bind
      in hypr/config/keybinds.conf (there's a NOTE at that line).

EOF
fi
