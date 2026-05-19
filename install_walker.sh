cat > ~/install-walker.sh << 'EOF'
#!/bin/bash

set -e

echo "Installing walker + elephant..."

yay -S --noconfirm walker-bin
yay -S --noconfirm elephant
yay -S --noconfirm elephant-providerlist
yay -S --noconfirm elephant-desktopapplications

echo "Creating systemd user service for elephant..."
mkdir -p ~/.config/systemd/user
cat > ~/.config/systemd/user/elephant.service << 'SERVICE'
[Unit]
Description=Elephant backend for Walker
After=graphical-session.target

[Service]
ExecStart=/usr/bin/elephant
Restart=on-failure

[Install]
WantedBy=graphical-session.target
SERVICE

systemctl --user enable --now elephant.service

echo "Creating Subliminal theme..."
mkdir -p ~/.config/walker/themes/subliminal
cat > ~/.config/walker/themes/subliminal/style.css << 'CSS'
@define-color window_bg_color rgba(13, 17, 23, 0.96);
@define-color accent_bg_color #2F6B85;
@define-color theme_fg_color #fef6fd;
@define-color error_bg_color #FF6B6B;
@define-color error_fg_color #0d1117;

* {
    all: unset;
    font-family: "JetBrainsMono Nerd Font", monospace;
    font-size: 14px;
}

.box-wrapper {
    background: @window_bg_color;
    border-radius: 12px;
    border: 1px solid #30363d;
    padding: 12px;
    min-width: 620px;
}

.input {
    background: #161b22;
    border-radius: 8px;
    padding: 10px 14px;
    color: @theme_fg_color;
    caret-color: #F5906A;
}

.input placeholder {
    opacity: 0.4;
}

.list {
    color: @theme_fg_color;
}

.item-box {
    border-radius: 8px;
    padding: 8px 12px;
}

child:selected .item-box,
child:hover .item-box {
    background: #161b22;
    border-left: 2px solid #F5906A;
}

.item-text {
    font-size: 14px;
    color: @theme_fg_color;
}

.item-subtext {
    font-size: 12px;
    color: #7d8590;
}

.placeholder,
.elephant-hint {
    color: @theme_fg_color;
    opacity: 0.4;
}

.error {
    padding: 10px;
    background: @error_bg_color;
    color: @error_fg_color;
    border-radius: 5px;
}

scrollbar {
    opacity: 0;
}
CSS

echo "Writing walker config..."
cat > ~/.config/walker/config.toml << 'TOML'
theme = "subliminal"
TOML

echo ""
echo "Done! Add this to your hyprland.conf:"
echo "  exec-once = elephant"
echo "  bind = \$mainMod, SPACE, exec, walker"
EOF

chmod +x ~/install-walker.sh
