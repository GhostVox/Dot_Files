# 🚀 Hyprland Dotfiles

A Hyprland configuration built around the **Noctalia** desktop shell, with Ghostty,
Zsh + Starship, and Neovim (kickstart) for a development-focused workflow.

## 📸 Features

- **Window Manager**: Hyprland with smooth animations and custom workspace rules
- **Desktop Shell**: [Noctalia](https://noctalia.dev) v5 — bar, launcher, notifications,
  clipboard, wallpaper picker, session menu, lock screen, screenshots, screen recording,
  and Wi-Fi / Bluetooth / brightness / volume control, all native
- **Terminal**: Ghostty (primary) & Kitty
- **Editor**: Neovim (kickstart fork, git submodule), Zed, IdeaVim for JetBrains IDEs
- **Idle Management**: Hypridle, locking via Noctalia's lock screen
- **Shell**: Zsh with Oh My Zsh, Starship prompt, Zoxide, FZF, syntax highlighting
- **Multiplexer / Git**: tmux, lazygit
- **Per-host hardware config** so the same repo works across machines

## Demo

[![Watch the demo](https://img.youtube.com/vi/I52polarkx0/0.jpg)](https://www.youtube.com/watch?v=I52polarkx0)

---

## ⚡ Quick Start

```bash
git clone https://github.com/GhostVox/Dot_Files.git ~/.config/Dot_Files
cd ~/.config/Dot_Files
./install.sh
```

`install.sh` is idempotent — safe to re-run. It backs up any existing configs to a
timestamped directory rather than overwriting them.

```
./install.sh              full run
./install.sh --dry-run    print what would happen, change nothing
./install.sh --no-pkgs    configs and symlinks only, skip package installs
./install.sh --help
```

**Run it from a real terminal** — `sudo` needs a TTY to prompt for a password.

What it does:

1. Preflight — verifies Arch, non-root, TTY, git
2. Relocates or clones the repo to `~/.config/Dot_Files`
3. Initialises the `nvim` submodule
4. Backs up existing configs, then symlinks
5. Creates required directories, sets script exec bits
6. Installs repo packages via `pacman`
7. Bootstraps `yay` if absent, installs AUR packages
8. Post-install: `chsh`, rustup, npm prefix, docker
9. **Verifies** — broken symlinks, files `.zshrc` sources unguarded, and every
   Noctalia IPC command the config depends on

Step 9 matters: a Noctalia version bump that renames an IPC command leaves the
keybind silently dead with no error. Re-run `./install.sh --dry-run` after upgrading.

---

## 📦 Packages

### Official repos (36)

```bash
sudo pacman -S --needed \
  hypridle nautilus networkmanager wl-clipboard playerctl ddcutil \
  ghostty firefox thunderbird zed neovim tmux lazygit \
  gpu-screen-recorder \
  zsh zsh-syntax-highlighting starship fastfetch fzf zoxide aws-cli \
  rustup go nodejs npm docker base-devel \
  speech-dispatcher espeak-ng \
  ttf-jetbrains-mono-nerd ttf-fira-code noto-fonts \
  imagemagick btop baobab zip unzip
```

| Group | Packages | Notes |
|---|---|---|
| Core desktop | `hypridle` `nautilus` `networkmanager` `wl-clipboard` `playerctl` `ddcutil` | `networkmanager` is the backend Noctalia's Wi-Fi panel drives; `ddcutil` powers both `hypr/brightness.sh` and Noctalia's external-monitor brightness |
| Apps on keybinds | `ghostty` `firefox` `thunderbird` `zed` `neovim` `tmux` `lazygit` | |
| Screen recording | `gpu-screen-recorder` | **required backend** for Noctalia's `screen_recorder` plugin — without it `Ctrl+Shift+5` silently does nothing |
| Shell | `zsh` `zsh-syntax-highlighting` `starship` `fastfetch` `fzf` `zoxide` `aws-cli` | every one is required by `.zshrc`; see the warning below |
| Dev toolchain | `rustup` `go` `nodejs` `npm` `docker` `base-devel` | `base-devel` is needed to build AUR packages |
| Scripts | `speech-dispatcher` `espeak-ng` | `spd-say` in `hypr/read.sh` (`Super+I`) |
| Fonts | `ttf-jetbrains-mono-nerd` `ttf-fira-code` `noto-fonts` | |
| Utilities | `imagemagick` `btop` `baobab` `zip` `unzip` | |

> ⚠️ **`.zshrc` sources two files unguarded**: `/usr/share/oh-my-zsh/oh-my-zsh.sh`
> and `/usr/bin/aws_zsh_completer.sh`. Missing either means errors on *every* new
> shell — so `aws-cli` and `oh-my-zsh-git` are hard requirements, not optional.

### AUR (2)

```bash
yay -S --needed noctalia-git oh-my-zsh-git
```

| Package | Used for |
|---|---|
| `noctalia-git` | the desktop shell itself — `exec-once = noctalia -d` and every `noctalia msg ...` keybind |
| `oh-my-zsh-git` | sourced by `.zshrc` |

#### ⚠️ Getting the Noctalia package right

Three similarly-named AUR packages, two of them wrong — and **both wrong ones install
cleanly and fail silently**:

| Package | Version | Ships | Verdict |
|---|---|---|---|
| **`noctalia-git`** | 5.0.0.rNNNN | current v5 CLI | ✅ use this |
| `noctalia` | 5.0.0_**beta**.6 | v5 CLI, but a *pre*-release of 5.0.0 | ⚠️ older than it looks |
| `noctalia-shell` | 4.7.7 | **no CLI at all** — driven by `qs -c noctalia-shell ipc call ...` | ❌ v4 |

These configs are v5-only (see the `NOCTALIA v5 NATIVE BINDINGS` block in
`hypr/config/keybinds.conf`). Installing `noctalia-shell` gives you no `noctalia`
binary, so every bind is dead. Recovery:

```bash
sudo pacman -R noctalia-shell    # plain -R, not -Rns — keep noctalia-qs
yay -S noctalia-git
```

### Deliberately not installed

Noctalia replaces all of these natively. Their configs are kept in the repo for
reference but are **not** symlinked.

| Package | Replaced by |
|---|---|
| `waybar` | Noctalia bar |
| `rofi` | Noctalia launcher |
| `swaync` | Noctalia notifications |
| `wlogout` | Noctalia session panel |
| `walker` / `elephant` | Noctalia launcher |
| `cliphist` | Noctalia clipboard panel |
| `hyprpaper` | Noctalia wallpaper picker |
| `hyprlock` | Noctalia lock screen |
| `hyprshot` / `wf-recorder` / `satty` | Noctalia screenshot + `screen_recorder` plugin |
| `blueman` / `pavucontrol` / `brightnessctl` / `network-manager-applet` | Noctalia control center |
| `qalculate-gtk` | Noctalia launcher's global calculator provider |
| `pacman-contrib` / `gnome-calendar` | were Waybar-only dependencies |

**Hyprland plugins** (`hyprexpo`, `hyprmodoro`) are also not installed; the config
lines that load them are commented out. To re-enable:

```bash
hyprpm update
hyprpm add https://github.com/hyprwm/hyprland-plugins && hyprpm enable hyprexpo
hyprpm add https://github.com/zakk4223/hyprmodoro && hyprpm enable hyprmodoro
hyprpm reload
```

…then uncomment the plugin lines in `hypr/config/auto_start.conf`,
`hypr/hyprland.conf`, and the `Super+A` binds in `hypr/config/keybinds.conf`.

---

## 🖥️ Per-host configuration

Hardware settings differ per machine, so they live in a **gitignored** file:

| File | Tracked | Contents |
|---|---|---|
| `hypr/config/host.conf` | no | that machine's monitors + GPU env vars |
| `hypr/config/host.conf.example` | yes | template with AMD / Intel / NVIDIA blocks |

`hyprland.conf` sources `host.conf` **last**, so it overrides everything above it —
including the monitor rules in `monitors.conf`.

```bash
cp hypr/config/host.conf.example hypr/config/host.conf
$EDITOR hypr/config/host.conf     # values from: hyprctl monitors all
```

Getting the GPU vars wrong is not harmless — `LIBVA_DRIVER_NAME=nvidia` on an AMD
box silently disables hardware video decode, and `GBM_BACKEND` /
`__GLX_VENDOR_LIBRARY_NAME` can break rendering outright. Always include a catch-all
monitor rule (`monitor = , preferred, auto, auto`) so an unlisted display doesn't
come up dark.

---

## ⌨️ Key Bindings

`$mainMod` = `SUPER`, `$MOD` = `CTRL`. Full cheatsheet: `Super + /`.

### General
| Keybinding | Action |
|---|---|
| `Super + T` | Terminal (Ghostty) |
| `Super + Shift + T` | Terminal (Kitty) |
| `Super + Q` | Close window |
| `Super + M` | Exit Hyprland |
| `Super + F` | Fullscreen |
| `Super + G` | Toggle floating |
| `Super + B` / `Super + Shift + B` | Chromium / Firefox |
| `Super + E` | Thunderbird |
| `Super + Shift + F` | File manager |
| `Super + I` | Read selection aloud |

### Noctalia panels
| Keybinding | Action |
|---|---|
| `Super + Backspace` | Launcher |
| `Super + .` | Emoji picker |
| `Super + C` | Launcher (calculator — just type a digit) |
| `Super + V` | Clipboard history |
| `Super + N` / `Super + X` | Control center |
| `Super + W` | Wallpaper picker |
| `Super + Delete` | Session / power menu |
| `Super + Tab` | Window switcher |
| `Super + /` | Keybind cheatsheet |
| `Super + R` | Reload Noctalia config |

### Screenshots & recording
| Keybinding | Action |
|---|---|
| `Ctrl + Shift + 3` | Screenshot region |
| `Ctrl + Shift + 4` | Screenshot fullscreen |
| `Ctrl + Shift + 5` | Toggle screen recording |

> Noctalia v5 has **no window capture** — only `screenshot-region` and
> `screenshot-fullscreen`.

### Navigation
| Keybinding | Action |
|---|---|
| `Super + H/J/K/L` | Move focus (Vim-style) |
| `Super + Shift + H/J/K/L` | Swap window |
| `Super + 1-0` | Switch workspace |
| `Super + Shift + 1-0` | Move window to workspace |
| `Super + S` / `Super + Shift + S` | Toggle / move to scratchpad |
| `Super + Home` / `Super + End` | Brightness up / down (ddcutil) |

---

## 📁 Structure

```
Dot_Files/
├── install.sh              # setup script
├── hypr/
│   ├── hyprland.conf       # main config (sources host.conf last)
│   ├── hypridle.conf       # idle → Noctalia lock
│   └── config/
│       ├── keybinds.conf
│       ├── monitors.conf   # shared/desktop monitors
│       ├── auto_start.conf
│       ├── host.conf       # per-machine, GITIGNORED
│       └── host.conf.example
├── nvim/                   # submodule → GhostVox/kickstart.nvim
├── ghostty/  kitty/        # terminals
├── zsh/  .zshrc  starship.toml
├── tmux/  lazygit/  zed/
├── .ideavimrc
└── waybar/ rofi/ swaync/ wlogout/ walker/   # legacy, not symlinked
```

---

## 🐛 Troubleshooting

### Hyprland reports a missing config file

Hyprland 0.56+ generates **Lua** configs (`hyprland.lua`) by default; this repo uses
the classic `hyprland.conf`. A running Hyprland **pins its config path at launch** —
after switching formats, `hyprctl reload` returns `ok` but keeps using the old path,
and `hyprctl configerrors` still complains. Only a full logout/login re-discovers it.

Check a config without restarting:

```bash
Hyprland --verify-config
```

### A Noctalia keybind does nothing

Almost always an IPC command renamed between versions — it fails silently. Verify:

```bash
noctalia msg --help
./install.sh --dry-run     # greps the binary for every command the config uses
```

### Shell errors on every new terminal

`.zshrc` unguarded-sources oh-my-zsh and the AWS completer. Install `oh-my-zsh-git`
and `aws-cli`.

### Starship prompt wrong

`.zshrc` points `STARSHIP_CONFIG` at `$HOME/.config/Dot_Files/starship.toml`, so the
repo must live at that exact path.

### Submodule init fails

`ghostty/shaders` is recorded as a gitlink in the index but has no `.gitmodules`
entry, which breaks `git submodule update --init` repo-wide. Initialise by name:

```bash
git submodule update --init nvim
```

---

## 📝 Known Issues

- **`ghostty/shaders`** — dangling gitlink (see above). Clean up with
  `git rm --cached ghostty/shaders`.
- **`$Mod` vs `$MOD`** — the audio-output binds in `keybinds.conf` use `$Mod`, but the
  variable defined at the top is `$MOD`. Hyprland variables are case-sensitive, so
  `$Mod` is undefined and those two binds don't resolve.
- **`Super + Shift + I`** is bound to `hypr/discord_read.sh`, which doesn't exist.
- **`hypr/screenshot.sh` and `hypr/toggle-record.sh`** are dead code — Noctalia
  handles both now.
- **`hypr/config/hyprmodoro.conf`** is orphaned; nothing sources it.
- **`install_walker.sh`** is dead code and broken anyway (stray `EOF` on line 100).
- Noctalia rewrites theme files at runtime (`kitty/themes/`, `ghostty/themes/`,
  `starship.toml` palette, `zed/themes/`, `lazygit/themes/`), so those show up as
  working-tree churn after changing schemes.

---

## 📝 Credits

- **Hyprland**: [hyprland.org](https://hyprland.org)
- **Noctalia**: [noctalia.dev](https://noctalia.dev)
- **Neovim base**: [kickstart.nvim](https://github.com/nvim-lua/kickstart.nvim)
- **Icons**: Nerd Fonts

## 📄 License

Free to use and modify. Attribution appreciated but not required.

---

**Note**: Optimized for Arch Linux. Adjustments needed for other distributions.
