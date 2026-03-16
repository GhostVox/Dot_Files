#!/bin/bash
WALLPAPER_DIR="$HOME/Pictures/wallpapers"
THUMB_DIR="$HOME/.cache/wallpaper-thumbs"
ROFI_THEME="$HOME/.config/rofi/wallselector/wallselector.rasi"
SYMLINK_TARGET="/home/ghostvox/.config/Dot_Files/hypr/current_wallpaper.png"

mkdir -p "$THUMB_DIR"

# Generate thumbnails using ImageMagick
# Using 'shopt' to handle cases where no files match the glob
shopt -s nullglob
for img in "$WALLPAPER_DIR"/*.{jpg,jpeg,png,JPG,PNG}; do
    thumb="$THUMB_DIR/$(basename "$img").png"
    if [[ ! -f "$thumb" ]]; then
        magick "$img" -resize 256x144^ -gravity center -extent 256x144 "$thumb"
    fi
done

# Rofi selection
# We use -printf "%f\n" to get just the filename for Rofi to display
CHOICE=$(find "$WALLPAPER_DIR" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) -printf "%f\n" \
    | while read -r fname; do
        echo -en "$fname\x00icon\x1f$THUMB_DIR/$fname.png\n"
    done | rofi -dmenu -i -p " Choose Wallpaper" -show-icons -theme "$ROFI_THEME")

# Action if a choice was made
if [[ -n "$CHOICE" ]]; then 
    WALLPAPER_PATH="$WALLPAPER_DIR/$CHOICE"
    
    # 1. Update the symlink first
    ln -sf "$WALLPAPER_PATH" "$SYMLINK_TARGET"
    
    # 2. Preload the NEW image
    hyprctl hyprpaper preload "$WALLPAPER_PATH"
    
    # 3. Apply the NEW image to all monitors
    # (Using the empty monitor name ',' applies it to all if you prefer)
    hyprctl hyprpaper wallpaper ",$WALLPAPER_PATH,"
    
    # 4. CRITICAL: Unload the PREVIOUS images
    # This forces Hyprpaper to stop holding onto the old file buffer
    # which usually stops the "reverting" behavior.
    hyprctl hyprpaper unload all
fi
