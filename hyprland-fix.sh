#!/bin/bash
set -e  # Stop on any error — we’ll catch and report it

# =============================================================================
#  HYPR LAND DIRECT CONFIG APPLICATOR (FIXED VERSION)
#  Applies full mouse-first, floating-by-default Hyprland config
#  No /etc/skel dependency — writes directly to ~/.config/hypr
#  Reports errors clearly
#  Updated syntax per Hyprland wiki (v0.44+ as of 2025)
# =============================================================================

echo "Applying FIXED Hyprland configuration directly to ~/.config/hypr..."

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
    xdg-desktop-portal-hyprland libnotify || report_error "Failed to install packages"

# ——— 2. Define target directory ———
TARGET_DIR="$HOME/.config/hypr"
echo "Target directory: $TARGET_DIR"
mkdir -p "$TARGET_DIR" || report_error "Cannot create $TARGET_DIR"

# ——— 3. Write hyprland.conf (FIXED SYNTAX) ———
echo "Writing hyprland.conf..."
cat > "$TARGET_DIR/hyprland.conf" << 'EOF'
# MyCustomDistro Hyprland Config – Floating by Default
monitor=,preferred,auto,1

input {
    kb_layout = us
    follow_mouse = 1
    sensitivity = 0
    touchpad {
        natural_scroll = true
    }
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
    blur {
        enabled = true
        size = 8
        passes = 2
        noise = 0.02
        contrast = 0.9
    }
    shadow {
        enabled = true
        range = 12
        render_power = 3
        color = rgba(000000dd)
    }
}

animations {
    enabled = true
    bezier = ease, 0.4, 0.02, 0.2, 1
    animation = windows, 1, 3, ease, slide
    animation = fade, 1, 3, ease
    animation = workspaces, 1, 3, ease, slide
}

gestures {
    workspace_swipe = true
}

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
preload = /usr/share/backgrounds/mycustomdistro.jpg
wallpaper = ,/usr/share/backgrounds/mycustomdistro.jpg
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
    echo