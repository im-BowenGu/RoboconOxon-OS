#!/bin/bash
set -e  # Exit on any error

echo "Setting up RoboCon Oxfordshire OS – Full Desktop + Tools + Branding + Unattended Install"
echo "Run this on a fresh Manjaro install BEFORE buildiso -g"

# === 1. Update System ===
sudo pacman -Syu --noconfirm

# === 2. Install All Software ===
sudo pacman -S --needed --noconfirm \
    hyprland hyprpaper wofi waybar thunar thunar-archive-plugin file-roller \
    google-chrome code alacritty oh-my-posh \
    polkit-gnome systemsettings wlogout calamares \
    papirus-icon-theme nordic-theme \
    qt5-wayland qt6-wayland glfw-wayland xdg-desktop-portal-hyprland \
    git base-devel

# === 3. Install Yay (AUR Helper) ===
if ! command -v yay &> /dev/null; then
    sudo pacman -S --needed git base-devel
    git clone https://aur.archlinux.org/yay.git /tmp/yay
    cd /tmp/yay && makepkg -si --noconfirm
    cd ~
fi

# === 4. Create /etc/skel Structure ===
sudo mkdir -p /etc/skel/.config/{hypr,waybar,wofi,alacritty,pamac,calamares}
sudo mkdir -p /etc/skel/.local/share/applications
sudo mkdir -p /etc/skel/Desktop
sudo mkdir -p /usr/share/backgrounds
sudo mkdir -p /etc/opt/chrome/policies/managed

# === 5. Branding: os-release, logo, wallpaper ===
sudo tee /etc/os-release > /dev/null << 'EOF'
NAME="RoboConOS"
PRETTY_NAME="RoboCon Oxfordshire OS"
ID=RoboConOS
ID_LIKE=manjaro
VERSION_ID="1.0"
HOME_URL="https://roboconoxon.org.uk"
LOGO=RoboConOS-logo
EOF

sudo cp /etc/os-release /etc/lsb-release

# Download wallpaper & logo
sudo wget -qO /usr/share/backgrounds/RoboconOS.png \
    https://roboconoxon.org.uk/wp-content/uploads/2025/11/robocon-wallpaper.png
sudo wget -qO /usr/share/pixmaps/RoboconOS-logo.png \
    https://roboconoxon.org.uk/wp-content/uploads/2025/06/cropped-Robocon-Natural-Logo.png

# === 6. Hyprland Config (Floating by Default + Super+T Toggle) ===
sudo tee /etc/skel/.config/hypr/hyprland.conf > /dev/null << 'EOF'
monitor=,preferred,auto,1
input { kb_layout = us; follow_mouse = 1; sensitivity = 0; touchpad { natural_scroll = yes } }
general { gaps_in = 8; gaps_out = 16; border_size = 2; col.active_border = rgba(88c0d0ff) rgba(81a1c1ff) 45deg; col.inactive_border = rgba(3b4252aa); layout = dwindle }
decoration { rounding = 12; blur { enabled = true; size = 8; passes = 2; noise = 0.02; contrast = 0.9 }; drop_shadow = yes; shadow_range = 12; shadow_render_power = 3; col.shadow = rgba(000000dd) }
animations { enabled = yes; bezier = ease, 0.4, 0.02, 0.2, 1; animation = windows, 1, 3, ease, slide; animation = fade, 1, 3, ease; animation = workspaces, 1, 3, ease, slide }
gestures { workspace_swipe = yes }

# Default: ALL FLOATING
windowrulev2 = float, class:.*
windowrulev2 = size 80% 75%, class:.*
windowrulev2 = center, class:.*

# Auto Start
exec-once = waybar
exec-once = hyprpaper
exec-once = /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1
exec-once = ~/.config/hypr/update-waybar-mode.sh
exec-once = calamares -d --unattended  # UNATTENDED INSTALL

# Tiling Toggle: Super + T
bind = SUPER, T, exec, ~/.config/hypr/toggle-tiling.sh

# Spotlight Search: Alt + Space
bind = ALT, space, exec, wofi --show drun --prompt "Search"

# Volume
bind = ,XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
bind = ,XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
bind = ,XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+

# Auto-float specific apps
windowrulev2 = float, class:^(thunar)$
windowrulev2 = float, class:^(pavucontrol)$
EOF

# === 7. Hyprpaper ===
sudo tee /etc/skel/.config/hypr/hyprpaper.conf > /dev/null << 'EOF'
preload = /usr/share/backgrounds/RoboconOS.png
wallpaper = ,/usr/share/backgrounds/RoboconOS.png
EOF

# === 8. Waybar ===
sudo tee /etc/skel/.config/waybar/config > /dev/null << 'EOF'
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

sudo tee /etc/skel/.config/waybar/style.css > /dev/null << 'EOF'
* { font-family: "JetBrainsMono Nerd Font", sans-serif; font-size: 14px; color: #d8dee9; }
window#waybar { background: rgba(46,52,64,0.9); border-bottom: 2px solid #88c0d0; border-radius: 12px; margin: 8px; }
#workspaces button.active { background: #88c0d0; color: #2e3440; border-radius: 8px; }
EOF

# === 9. Wofi ===
sudo tee /etc/skel/.config/wofi/config > /dev/null << 'EOF'
width=600
height=400
show=drun
prompt=Search
allow_images=true
image_size=48
EOF

sudo tee /etc/skel/.config/wofi/style.css > /dev/null << 'EOF'
window { margin: 0px; border: 2px solid #88c0d0; background-color: #2e3440; border-radius: 16px; }
#input { padding: 12px; background-color: #3b4252; color: white; border-radius: 12px; }
#entry:selected { background-color: #88c0d0; color: #2e3440; border-radius: 8px; }
EOF

# === 10. wlogout ===
sudo tee /etc/skel/.config/wlogout/layout > /dev/null << 'EOF'
{ "label": "settings", "action": "systemsettings", "text": "Settings" }
{ "label": "lock", "action": "hyprctl dispatch dpms off", "text": "Lock" }
{ "label": "logout", "action": "hyprctl dispatch exit", "text": "Logout" }
{ "label": "reboot", "action": "systemctl reboot", "text": "Reboot" }
{ "label": "shutdown", "action": "systemctl poweroff", "text": "Shutdown" }
EOF

# === 11. Alacritty ===
sudo tee /etc/skel/.config/alacritty/alacritty.toml > /dev/null << 'EOF'
[window]
padding = { x = 12, y = 12 }
opacity = 0.95

[font]
normal = { family = "JetBrainsMono Nerd Font", style = "Regular" }
size = 13.0

[colors.primary]
background = "#2e3440"
foreground = "#d8dee9"
EOF

# === 12. Bash + Oh My Posh ===
sudo tee /etc/skel/.bashrc > /dev/null << 'EOF'
eval "$(oh-my-posh init bash --config /usr/share/oh-my-posh/themes/atomic.omp.json)"
alias ll='ls -la --color=auto'
alias ..='cd ..'
cd ~
echo -e "\e[1;34mWelcome to RoboconOS!\e[0m"
EOF

# === 13. Pamac (AUR + Snap + Flatpak) ===
sudo tee /etc/skel/.config/pamac/pamac.conf > /dev/null << 'EOF'
enable_aur = true
enable_snap = true
enable_flatpak = true
EOF

# === 14. Chrome Enterprise Policies ===
sudo tee /etc/opt/chrome/policies/CloudManagementEnrollmentToken > /dev/null << 'EOF'
8ed57fc9-f3fe-4613-8292-275c83846665
EOF

# === 15. Tiling Toggle Script ===
sudo tee /etc/skel/.config/hypr/toggle-tiling.sh > /dev/null << 'EOF'
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
sudo chmod +x /etc/skel/.config/hypr/toggle-tiling.sh

# === 16. Waybar Mode Updater ===
sudo tee /etc/skel/.config/hypr/update-waybar-mode.sh > /dev/null << 'EOF'
#!/bin/bash
echo "FLOAT" > /tmp/hypr-tiling-mode
pkill -RTMIN+8 waybar
EOF
sudo chmod +x /etc/skel/.config/hypr/update-waybar-mode.sh

# === 17. Desktop Shortcuts ===
sudo tee /etc/skel/Desktop/Home.desktop > /dev/null << 'EOF'
[Desktop Entry]
Name=Home Folder
Exec=thunar ~
Icon=folder-home
Type=Application
EOF

sudo tee /etc/skel/Desktop/Code.desktop > /dev/null << 'EOF'
[Desktop Entry]
Name=VS Code
Exec=code
Icon=code
Type=Application
EOF

sudo tee /etc/skel/Desktop/Terminal.desktop > /dev/null << 'EOF'
[Desktop Entry]
Name=Terminal
Exec=alacritty
Icon=utilities-terminal
Type=Application
EOF

sudo chmod +x /etc/skel/Desktop/*.desktop

# === 18. Default File Manager ===
sudo tee /etc/skel/.config/xdg/mimeapps.list > /dev/null << 'EOF'
[Default Applications]
inode/directory=thunar.desktop
EOF

# === 19. Auto-Start Hyprland ===
sudo tee /etc/skel/.bash_profile > /dev/null << 'EOF'
if [ -z "${WAYLAND_DISPLAY}" ] && [ "${XDG_VTNR}" -eq 1 ]; then
  exec Hyprland
fi
EOF

# === 20. UNATTENDED CALAMARES INSTALL ===
sudo tee /etc/skel/.config/calamares/settings.conf > /dev/null << 'EOF'
---
branding: RoboConOS
modules-search: [ local ]

sequence:
    - welcome
    - partition
    - mount
    - users
    - summary
    - install
    - bootloader
    - finished

welcome: { disable: true }
partition: { disable: true, config: |
    selectdisk: /dev/sda
    clearall:
        - device: /dev/sda
          partitions: []
    create:
        - device: /dev/sda
          partitions:
              - fs: fat32
                mountPoint: /boot/efi
                size: 512MiB
                flags: [ boot, esp ]
              - fs: ext4
                mountPoint: /
                size: 100%
    format: true
}
mount: { disable: true }
users: { disable: true, config: |
    username: roboconoxon
    fullname: RoboCon Oxfordshire
    password: roboconoxon
    autologin: true
    sudouser: true
    groups: [ wheel, storage, power, network, video, audio ]
}
summary: { disable: true }
install: { disable: true }
bootloader: { disable: true, config: |
    install: true
    efi: true
}
finished: { disable: true, config: |
    reboot: true
    message: "Installation complete! Rebooting..."
}
* unattended: true
EOF

# === 21. Final Permissions ===
sudo chown -R root:root /etc/skel
sudo chmod -R 755 /etc/skel

echo
echo "ALL DONE!"
echo "Now run:"
echo "  sudo buildiso -p RoboConOS -g"
echo "  sudo buildiso -p RoboConOS -f -c"
echo "Your ISO will have: Hyprland, Chrome, VS Code, Terminal, File Manager, Tiling Toggle, Spotlight, Branding, UNATTENDED INSTALL"
