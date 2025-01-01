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
echo "Updating and upgrading system packages..."
sudo apt update
sudo apt upgrade -y

# Disable and remove swap to save resources
echo "Disabling and removing swap..."
sudo service dphys-swapfile stop
echo "Stopped dphys-swapfile service."
sudo systemctl disable dphys-swapfile
echo "Disabled dphys-swapfile service."
sudo apt-get purge -y dphys-swapfile
echo "Removed dphys-swapfile package."

# Install required packages
echo "Installing required packages..."
sudo apt install --no-install-recommends -y \
    xserver-xorg \
    xinit \
    x11-xserver-utils \
    chromium-browser \
    matchbox-window-manager

# Create the kiosk script
echo "Creating kiosk script..."
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
echo "Configuring auto-start..."
if ! grep -q "xinit /home/pi/kiosk" ~/.bashrc; then
  echo "xinit /home/pi/kiosk -- vt\$(fgconsole)" >> ~/.bashrc
  echo "Added kiosk script to .bashrc for auto-start."
else
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
echo "==== Setup Complete ===="
echo "Reboot the system to apply changes."
echo "You entered Kiosk URL: $KIOSK_URL"
echo "You entered Screen Resolution: $SCREEN_RESOLUTION"

echo ""
echo "Setup complete. Reboot your system to apply the changes."

# Countdown timer with Ctrl+C cancellation
echo "The system will reboot in 10 seconds. Press Ctrl+C to cancel."
for i in {10..1}; do
    printf "\rRebooting in %d seconds... " "$i"
    sleep 1
done

# Reboot if the countdown is not interrupted
echo ""
echo "Rebooting now..."
sudo reboot
