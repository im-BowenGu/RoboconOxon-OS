#!/bin/bash
set -e

# --- 1. Repos (Sid + Brave + VSCodium) ---
echo "deb http://deb.debian.org/debian/ sid main contrib non-free non-free-firmware" > /etc/apt/sources.list
apt update && apt dist-upgrade -y

apt install -y curl wget gnupg apt-transport-https software-properties-common

# Brave
curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main" > /etc/apt/sources.list.d/brave-browser-release.list

# VSCodium
wget -qO - https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/raw/master/pub.gpg | gpg --dearmor | dd of=/usr/share/keyrings/vscodium-archive-keyring.gpg
echo 'deb [ signed-by=/usr/share/keyrings/vscodium-archive-keyring.gpg ] https://download.vscodium.com/debs vscodium main' > /etc/apt/sources.list.d/vscodium.list

apt update

# --- 2. Install KDE Plasma 6 (Wayland), KRDP & Apps ---
apt install -y \
    plasma-desktop plasma-workspace-wayland kwin-wayland sddm \
    krdp \
    plasma-nm plasma-pa dolphin konsole ark kcalc \
    codium brave-browser \
    qemu-guest-agent cloud-init \
    qt6-style-kvantum

# --- 3. Configure Auto-Login (Required for Headless RDP) ---
# Replace 'student' with your actual user if different
USER_ID=$(id -u 1000)
USER_NAME=$(id -nu 1000)

mkdir -p /etc/sddm.conf.d
cat <<EOF > /etc/sddm.conf.d/autologin.conf
[Autologin]
User=$USER_NAME
Session=plasma.desktop
EOF

# Force Wayland Session
mkdir -p /var/lib/sddm
cat <<EOF > /var/lib/sddm/state.conf
[Last]
Session=/usr/share/wayland-sessions/plasma.desktop
EOF

# --- 4. Configure KRDP (RDP Server) ---
# Inject config to enable RDP on login
sudo -u $USER_NAME mkdir -p /home/$USER_NAME/.config
cat <<EOF > /home/$USER_NAME/.config/krdprc
[General]
Port=3389
EOF

# Enable KRDP Server for the user
loginctl enable-linger $USER_NAME
systemctl --user -M $USER_NAME@ enable krdp-server
systemctl --user -M $USER_NAME@ start krdp-server

# Open Firewall
if command -v ufw > /dev/null; then ufw allow 3389/tcp; fi

# --- 5. Branding & Defaults ---
# OS Release
cat <<EOF > /etc/os-release
NAME="RoboConOS"
PRETTY_NAME="RoboCon Oxfordshire OS"
ID=roboconos
ID_LIKE=debian
VERSION_ID="3.0"
HOME_URL="https://roboconoxon.org.uk"
EOF

# Set Defaults
update-alternatives --set editor /usr/bin/codium
xdg-mime default brave-browser.desktop x-scheme-handler/http
xdg-mime default brave-browser.desktop x-scheme-handler/https

# --- 6. Proxmox Prep ---
truncate -s 0 /etc/machine-id
rm /var/lib/dbus/machine-id
ln -s /etc/machine-id /var/lib/dbus/machine-id
systemctl enable qemu-guest-agent

apt autoremove -y
echo "Done. Reboot to initialize Wayland & RDP."