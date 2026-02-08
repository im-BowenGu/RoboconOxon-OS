#!/bin/bash
set -e

echo "Setting up RoboCon Oxfordshire OS"
# === 1. Setup Debian Sid Repos ===
sudo tee /etc/apt/sources.list > /dev/null << 'EOF'
deb http://deb.debian.org/debian/ sid main contrib non-free non-free-firmware
EOF

sudo apt update && sudo apt dist-upgrade -y

# === 2. Install External Repos (Brave & VSCodium) ===
sudo apt install -y curl wget gnupg apt-transport-https software-properties-common

# Brave
sudo curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main" | sudo tee /etc/apt/sources.list.d/brave-browser-release.list

# VSCodium
wget -qO - https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/raw/master/pub.gpg | gpg --dearmor | sudo dd of=/usr/share/keyrings/vscodium-archive-keyring.gpg
echo 'deb [ signed-by=/usr/share/keyrings/vscodium-archive-keyring.gpg ] https://download.vscodium.com/debs vscodium main' | sudo tee /etc/apt/sources.list.d/vscodium.list

sudo apt update

# === 3. Install KDE Plasma (Wayland) & Core Apps ===
sudo apt install -y \
    plasma-desktop plasma-workspace-wayland kwin-wayland sddm \
    plasma-nm plasma-pa \
    dolphin konsole ark gwenview kcalc \
    network-manager-gnome \
    codium brave-browser \
    git build-essential \
    qemu-guest-agent

# === 4. Install RDP Server (XRDP) ===
sudo apt install -y xrdp xorgxrdp

# Configure XRDP to launch KDE
echo "startplasma-x11" > ~/.xsession

sudo sed -i 's/allowed_users=console/allowed_users=anybody/' /etc/X11/Xwrapper.config

sudo systemctl enable xrdp
sudo systemctl restart xrdp

# === 5. Install "Windows 11" Look for KDE ===
sudo apt install -y qt5-style-kvantum qt6-style-kvantum


sudo tee /usr/local/bin/apply-theme.sh > /dev/null << 'EOF'
#!/bin/bash
# Check if theme is already applied to avoid resetting
if [ -f ~/.config/robocon-theme-applied ]; then
    exit 0
fi

# 1. Move Panel to Bottom (KDE Default is bottom, but let's ensure task manager is icon-only)

echo "Theme Setup Complete" > ~/.config/robocon-theme-applied
EOF
sudo chmod +x /usr/local/bin/apply-theme.sh

# Add to autostart
mkdir -p /etc/xdg/autostart
sudo tee /etc/xdg/autostart/apply-theme.desktop > /dev/null << 'EOF'
[Desktop Entry]
Type=Application
Name=Theme Setup
Exec=/usr/local/bin/apply-theme.sh
EOF

# === 6. Set Defaults ===
# Default Editor -> VSCodium
sudo update-alternatives --set editor /usr/bin/codium

# Default Browser -> Brave
xdg-mime default brave-browser.desktop x-scheme-handler/http
xdg-mime default brave-browser.desktop x-scheme-handler/https

# === 7. Cloud-Init Prep for Proxmox ===
sudo apt install -y cloud-init
sudo truncate -s 0 /etc/machine-id
sudo rm /var/lib/dbus/machine-id
sudo ln -s /etc/machine-id /var/lib/dbus/machine-id

# === 8. Final Cleanup ===
sudo apt autoremove -y

echo "Setup Complete!"
echo "NOTE: KDE Wayland is the default local session."
echo "RDP sessions will use X11 backend (Standard Linux VDI behavior)."