#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Prompt the user for customization
echo "==== Kiosk Setup Script ===="
read -p "Enter the Kiosk URL (default: http://<MM_SERVER_IP>): " KIOSK_URL
KIOSK_URL=${KIOSK_URL:-http://<MM_SERVER_IP>}

read -p "Enter the screen resolution (default: 1920x1080): " SCREEN_RESOLUTION
SCREEN_RESOLUTION=${SCREEN_RESOLUTION:-1920x1080}

# Update and upgrade system
echo "\n[1/5] Updating and upgrading system packages..."
sudo apt update | pv -lep -s 100 > /dev/null
sudo apt upgrade -y | pv -lep -s 100 > /dev/null

# Disable and remove swap to save resources
echo "\n[2/5] Disabling and removing swap..."
sudo service dphys-swapfile stop
echo "Stopped dphys-swapfile service."
sudo systemctl disable dphys-swapfile
echo "Disabled dphys-swapfile service."
sudo apt-get purge -y dphys-swapfile
echo "Removed dphys-swapfile package."

# Install required packages
echo "\n[3/5] Installing required packages..."
sudo apt install --no-install-recommends -y \
    xserver-xorg \
    xinit \
    x11-xserver-utils \
    chromium-browser \
    matchbox-window-manager | pv -lep -s 100 > /dev/null

# Create the kiosk script
echo "\n[4/5] Creating kiosk script..."
cat <<EOL > ~/kiosk
#!/bin/sh
xset -dpms     # disable DPMS (Energy Star) features
xset s off     # disable screen saver
xset s noblank # don't blank the video device
matchbox-window-manager -use_titlebar no &
chromium-browser --display=:0 --kiosk --incognito --window-position=0,0 $KIOSK_URL
EOL
chmod +x ~/kiosk

echo "Kiosk script created at ~/kiosk."

# Add kiosk script to .bashrc for auto-start
echo "\n[5/5] Configuring auto-start..."
if ! grep -q "xinit /home/pi/kiosk" ~/.bashrc; then
  echo "xinit /home/pi/kiosk -- vt\$(fgconsole)" >> ~/.bashrc
  echo "Added kiosk script to .bashrc for auto-start."\else
  echo "Kiosk script already configured in .bashrc."
fi

# Configure X11 for the desired screen resolution
echo "Configuring X11 for screen resolution $SCREEN_RESOLUTION..."
sudo bash -c 'cat <<EOL > /etc/X11/xorg.conf
Section "Screen"
    Identifier "Screen 0"
    Device "HDMI-1"
    SubSection "Display"
        Modes "$SCREEN_RESOLUTION"
    EndSubSection
EndSection
EOL'
echo "X11 configuration updated."

# Inform the user
echo "\n==== Setup Complete ===="
echo "Reboot the system to apply changes."
echo "You entered Kiosk URL: $KIOSK_URL"
echo "You entered Screen Resolution: $SCREEN_RESOLUTION"
