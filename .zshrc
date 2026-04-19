# --------------------------------------------------------------------------- #
# Enviroment Variables
# -------------------------------------------------------------------------- #
alias zed='zeditor'
export HYPRSHOT_DIR="$HOME/Pictures/Screenshots/"



# --------------------------------------------------------------------------- #
# Oh My Zsh Configuration
# --------------------------------------------------------------------------- #

# Path to your Oh My Zsh installation.
export ZSH="/usr/share/oh-my-zsh"

# Set ZSH_THEME to blank to disable Oh My Zsh themes and prevent conflicts
# with Starship. Starship will handle the prompt.
ZSH_THEME=""

# Oh My Zsh plugins to load.
# zsh-syntax-highlighting is handled below as a separate plugin.
plugins=(
  git
  rust
  golang
  docker
  mvn
)

# Source Oh My Zsh. This MUST come after the settings above.
source $ZSH/oh-my-zsh.sh

# --------------------------------------------------------------------------- #
# PATH Exports & Environment Variables
# --------------------------------------------------------------------------- #

# Consolidate all PATH modifications for clarity.
# The order is important: paths added first are checked first.
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/.cargo/bin:$PATH"
export PATH="$HOME/go/bin:$PATH"
export PATH="$HOME/.npm-global/bin:$PATH"


# Set preferred editor.
export EDITOR='zeditor'

# Environment variables for GUI scaling and fonts.
export FREETYPE_PROPERTIES="truetype:interpreter-version=40"
export QT_FONT_DPI=96
export GDK_SCALE=1
export GDK_DPI_SCALE=1

# --------------------------------------------------------------------------- #
# Plugin and Tool Configuration
# --------------------------------------------------------------------------- #

# --- ASDF Version Manager ---
export ASDF_DATA_DIR="$HOME/.asdf"
# Add asdf shims to PATH if the directory exists
if [ -d "${ASDF_DATA_DIR:-$HOME/.asdf}/shims" ]; then
  export PATH="${ASDF_DATA_DIR:-$HOME/.asdf}/shims:$PATH"
  # Add ASDF completions
  fpath=(${ASDF_DATA_DIR:-$HOME/.asdf}/completions $fpath)
fi

# --- Zoxide ---
eval "$(zoxide init zsh)"

# --- FZF ---
eval "$(fzf --zsh)"

# --- Zsh Syntax Highlighting ---
# Source the plugin. Make sure it's installed at this path.
ZSH_SYNTAX_HIGHLIGHTING_PATH="/usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
if [ -f "$ZSH_SYNTAX_HIGHLIGHTING_PATH" ]; then
  source "$ZSH_SYNTAX_HIGHLIGHTING_PATH"
fi

# --- AWS Completer ---
source /usr/bin/aws_zsh_completer.sh

# --- Zsh Completions System ---
# Initialize the completions system.
autoload -Uz compinit && compinit

# --------------------------------------------------------------------------- #
# Startup Commands & Prompt
# --------------------------------------------------------------------------- #

# --- Fastfetch ---
# Run fastfetch only in interactive shells, not in tmux or ssh sessions.
if [[ -z "$FASTFETCH_RAN" && -z "$TMUX" && -z "$SSH_CLIENT" ]]; then
    export FASTFETCH_RAN=1
    fastfetch --logo Xenia_old
fi

# --- Starship Prompt ---
# Set the path to your custom Starship config and initialize the prompt.
# This MUST be the last thing to run to take control of the prompt.
export STARSHIP_CONFIG="$HOME/.config/Dot_Files/starship.toml"
source <(starship init zsh)
source ~/.config/zsh/fix-jetbrains-icon.sh
export PATH="$PATH:$HOME/.dotnet/tools"




