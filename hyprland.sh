#!/bin/bash
set -e  # Stop on any error — we’ll catch and report it

# =============================================================================
#  HYPR LAND DIRECT CONFIG APPLICATOR
#  Applies full mouse-first, floating-by-default Hyprland config
#  No /etc/skel dependency — writes directly to ~/.config/hypr
#  Reports errors clearly
# =============================================================================

echo "Applying Hyprland configuration directly to ~/.config/hypr..."

# ——— Helper: Report error and exit ———
report_error() {
    echo "ERROR: $1" >&2
    echo "Fix the issue and re-run the script."
    exit 1
}

# ——— 1. Install required packages ———
echo "Installing Hyprland and dependencies..."
sudo pacman -Syu --noconfirm || report_error "System update failed"
sudo pacman -S --needed --noconfirm \
    hyprland hyprpaper waybar wofi thunar polkit-gnome wlogout \
    papirus-icon-theme nordic-theme qt5-wayland qt6-wayland \
    xdg-desktop-portal-hyprland || report_error "Failed to install packages"

# ——— 2. Define target directory ———
TARGET_DIR="$HOME/.config/hypr"
echo "Target directory: $TARGET_DIR"
mkdir -p "$TARGET_DIR" || report_error "Cannot create $TARGET_DIR"

# ——— 3. Write hyprland.conf ———
echo "Writing hyprland.conf..."
cat > "$TARGET_DIR/hyprland.conf" << 'EOF'
# RoboCon Oxfordshire OS Hyprland Config – Floating by Default
monitor=,preferred,auto,1

input {
    kb_layout = us
    follow_mouse = 1
    sensitivity = 0
    touchpad { natural_scroll = yes }
}

general {
    gaps_in = 8
    gaps_out = 16
    border_size = 2
    col.active_border = rgba(88c0d0ff) rgba(81a1c1ff) 45deg
    col.inactive_border = rgba(3b4252aa)
    layout = dwindle
}

decoration {
    rounding = 12
    blur { enabled = true; size = 8; passes = 2; noise = 0.02; contrast = 0.9 }
    drop_shadow = yes
    shadow_range = 12
    shadow_render_power = 3
    col.shadow = rgba(000000dd)
}

animations {
    enabled = yes
    bezier = ease, 0.4, 0.02, 0.2, 1
    animation = windows, 1, 3, ease, slide
    animation = fade, 1, 3, ease
    animation = workspaces, 1, 3, ease, slide
}

gestures { workspace_swipe = yes }

# ——— FLOAT ALL WINDOWS BY DEFAULT ———
windowrulev2 = float, class:.*
windowrulev2 = size 80% 75%, class:.*
windowrulev2 = center, class:.*

# ——— Auto Start ———
exec-once = waybar
exec-once = hyprpaper
exec-once = /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1
exec-once = ~/.config/hypr/update-waybar-mode.sh

# ——— Keybinds ———
bind = SUPER, T, exec, ~/.config/hypr/toggle-tiling.sh
bind = ALT, space, exec, wofi --show drun --prompt "Search"
bind = ,XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
bind = ,XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
bind = ,XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+

# ——— Float specific apps ———
windowrulev2 = float, class:^(thunar)$
windowrulev2 = float, class:^(pavucontrol)$
EOF

# ——— 4. hyprpaper.conf ———
echo "Writing hyprpaper.conf..."
cat > "$TARGET_DIR/hyprpaper.conf" << 'EOF'
preload = /usr/share/backgrounds/RoboCon Oxfordshire OS.jpg
wallpaper = ,/usr/share/backgrounds/RoboCon Oxfordshire OS.jpg
EOF

# ——— 5. toggle-tiling.sh ———
echo "Writing toggle-tiling.sh..."
cat > "$TARGET_DIR/toggle-tiling.sh" << 'EOF'
#!/bin/bash
CURRENT=$(hyprctl getoption general:layout | grep str | awk '{print $2}')
if [ "$CURRENT" = "dwindle" ]; then
    hyprctl keyword general:layout master
    hyprctl keyword general:layout dwindle
    notify-send 'Desktop Mode' 'Windows float freely' -i system-users
    echo "FLOAT" > /tmp/hypr-tiling-mode
else
    hyprctl keyword general:layout dwindle
    notify-send 'Tiling Mode' 'Super+T to exit' -i view-grid
    echo "TILE" > /tmp/hypr-tiling-mode
fi
pkill -RTMIN+8 waybar
EOF
chmod +x "$TARGET_DIR/toggle-tiling.sh" || report_error "Failed to make toggle-tiling.sh executable"

# ——— 6. update-waybar-mode.sh ———
echo "Writing update-waybar-mode.sh..."
cat > "$TARGET_DIR/update-waybar-mode.sh" << 'EOF'
#!/bin/bash
echo "FLOAT" > /tmp/hypr-tiling-mode
pkill -RTMIN+8 waybar
EOF
chmod +x "$TARGET_DIR/update-waybar-mode.sh" || report_error "Failed to make update-waybar-mode.sh executable"

# ——— 7. Waybar config ———
echo "Writing Waybar config..."
mkdir -p "$HOME/.config/waybar"
cat > "$HOME/.config/waybar/config" << 'EOF'
{
  "layer": "top", "height": 36, "spacing": 8,
  "modules-left": ["custom/launcher", "hyprland/workspaces", "custom/tiling-mode"],
  "modules-center": ["clock"],
  "modules-right": ["tray", "pulseaudio", "network", "battery", "custom/power"],
  "custom/launcher": { "format": "Search", "on-click": "wofi --show drun", "tooltip": false },
  "hyprland/workspaces": { "format": "{icon}", "on-click": "activate", "format-icons": ["1","2","3","4","5","6","7","8","9"] },
  "custom/tiling-mode": { "format": "{}", "exec": "cat /tmp/hypr-tiling-mode 2>/dev/null || echo FLOAT", "interval": 1, "signal": 8 },
  "clock": { "format": "{:%H:%M  %a %b %d}", "tooltip-format": "{:%Y-%m-%d}" },
  "tray": { "spacing": 8 },
  "pulseaudio": { "format": "{icon} {volume}%", "format-muted": "Muted", "on-click": "pavucontrol", "format-icons": ["Low Volume","Medium Volume","High Volume"] },
  "network": { "format-wifi": "WiFi {essid}", "format-disconnected": "No Network", "on-click": "nm-connection-editor" },
  "battery": { "bat": "BAT0", "format": "{icon} {capacity}%", "format-icons": ["Low Battery","Medium Battery","High Battery"] },
  "custom/power": { "format": "Power", "on-click": "wlogout", "tooltip": false }
}
EOF

cat > "$HOME/.config/waybar/style.css" << 'EOF'
* { font-family: "JetBrainsMono Nerd Font", sans-serif; font-size: 14px; color: #d8dee9; }
window#waybar { background: rgba(46,52,64,0.9); border-bottom: 2px solid #88c0d0; border-radius: 12px; margin: 8px; }
#workspaces button.active { background: #88c0d0; color: #2e3440; border-radius: 8px; }
EOF

# ——— 8. Wofi ———
echo "Writing Wofi config..."
mkdir -p "$HOME/.config/wofi"
cat > "$HOME/.config/wofi/config" << 'EOF'
width=600
height=400
show=drun
prompt=Search
allow_images=true
image_size=48
EOF

cat > "$HOME/.config/wofi/style.css" << 'EOF'
window { margin: 0px; border: 2px solid #88c0d0; background-color: #2e3440; border-radius: 16px; }
#input { padding: 12px; background-color: #3b4252; color: white; border-radius: 12px; }
#entry:selected { background-color: #88c0d0; color: #2e3440; border-radius: 8px; }
EOF

# ——— 9. Wallpaper ———
echo "Downloading wallpaper..."
sudo mkdir -p /usr/share/backgrounds
sudo wget -qO /usr/share/backgrounds/RoboCon Oxfordshire OS.jpg \
    https://images.unsplash.com/photo-1506318137071-a8e063b4ca0a?auto=format&fit=crop&w=1920&q=80 \
    || echo "Warning: Wallpaper download failed (continuing)"

# ——— 10. Final check ———
echo "Verifying key files..."
for f in hyprland.conf hyprpaper.conf toggle-tiling.sh update-waybar-mode.sh; do
    [ -f "$TARGET_DIR/$f" ] || report_error "Missing: $TARGET_DIR/$f"
done

# ——— SUCCESS ———
echo
echo "HYPR LAND CONFIG APPLIED SUCCESSFULLY!"
echo "→ Config location: $TARGET_DIR"
echo "→ To apply now:"
echo "   1. Log out and log back in"
echo "   2. Or run: Hyprland (if already in session)"
echo
echo "Test:"
echo "   • Alt + Space → App launcher"
echo "   • Super + T → Toggle tiling"
echo "   • Click Search on bar → App grid"
echo
echo "If nothing works: check ~/.config/hypr/hyprland.conf for syntax errors."