# ~/.config/zsh/fix-jetbrains-icon.sh

fix-jetbrains-icon() {
  local ide="$1"

  if [[ -z "$ide" ]]; then
    echo "Usage: fix-jetbrains-icon <ide-name>"
    echo "Example: fix-jetbrains-icon rustrover"
    return 1
  fi

  local desktop=$(find ~/.local/share/applications -name "jetbrains-${ide}-*.desktop" | head -1)
  local svg=$(find ~/.local/share/icons/hicolor/scalable/apps -name "jetbrains-${ide}-*.svg" | head -1)

  if [[ -z "$desktop" ]]; then
    echo "Error: No .desktop file found for '$ide'"
    return 1
  fi

  if [[ -z "$svg" ]]; then
    echo "Error: No .svg icon found for '$ide'"
    return 1
  fi

  echo "Linking: $desktop"
  ln -sf "$desktop" ~/.local/share/applications/jetbrains-${ide}.desktop

  echo "Linking: $svg"
  ln -sf "$svg" ~/.local/share/icons/hicolor/scalable/apps/jetbrains-${ide}.svg

  gtk-update-icon-cache ~/.local/share/icons/hicolor
  echo "Done! Restart waybar to see the icon."
}
