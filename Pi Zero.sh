#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Check if the script is running on a physical console
if [[ "$(tty)" != "/dev/tty"* ]]; then
    echo -e "\033[0;31mThis script must be run from a physical console (not over SSH).\033[0m"
    exit 1
fi

# Prompt the user for customization
echo -e "\033[0;32m==== Kiosk Setup Script ====\033[0m"
read -p "\033[0;32mEnter the Kiosk URL (default: http://<MM_SERVER_IP>): \033[0m" KIOSK_URL
KIOSK_URL=${KIOSK_URL:-http://<MM_SERVER_IP>}

read -p "\033[0;32mEnter the screen resolution (default: 1920x1080): \033[0m" SCREEN_RESOLUTION
SCREEN_RESOLUTION=${SCREEN_RESOLUTION:-1920x1080}

# Update and upgrade system
echo -e "\033[0;33mUpdating and upgrading system packages...\033[0m"
sudo apt update
sudo apt upgrade -y

# Disable and remove swap to save resources
echo -e "\033[0;33mDisabling and removing swap...\033[0m"
sudo service dphys-swapfile stop
echo -e "\033[0;32mStopped dphys-swapfile service.\033[0m"
sudo systemctl disable dphys-swapfile
echo -e "\033[0;32mDisabled dphys-swapfile service.\033[0m"
sudo apt-get purge -y dphys-swapfile
echo -e "\033[0;32mRemoved dphys-swapfile package.\033[0m"

# Install required packages
echo -e "\033[0;33mInstalling required packages...\033[0m"
sudo apt install --no-install-recommends -y \
    xserver-xorg \
    xinit \
    x11-xserver-utils \
    chromium-browser \
    matchbox-window-manager

# Create the kiosk script
echo -e "\033[0;33mCreating kiosk script...\033[0m"
cat <<EOL > ~/kiosk
#!/bin/sh
xset -dpms     # disable DPMS (Energy Star) features
xset s off     # disable screen saver
xset s noblank # don't blank the video device
matchbox-window-manager -use_titlebar no &
chromium-browser --display=:0 --kiosk --incognito --window-position=0,0 $KIOSK_URL
EOL
chmod +x ~/kiosk

echo -e "\033[0;32mKiosk script created at ~/kiosk.\033[0m"

# Add kiosk script to .bashrc for auto-start
echo -e "\033[0;33mConfiguring auto-start...\033[0m"
if ! grep -q "xinit /home/pi/kiosk" ~/.bashrc; then
  echo "xinit /home/pi/kiosk -- vt\$(fgconsole)" >> ~/.bashrc
  echo -e "\033[0;32mAdded kiosk script to .bashrc for auto-start.\033[0m"
else
  echo -e "\033[0;32mKiosk script already configured in .bashrc.\033[0m"
fi

# Configure X11 for the desired screen resolution
echo -e "\033[0;33mConfiguring X11 for screen resolution $SCREEN_RESOLUTION...\033[0m"
sudo bash -c 'cat <<EOL > /etc/X11/xorg.conf
Section "Screen"
    Identifier "Screen 0"
    Device "HDMI-1"
    SubSection "Display"
        Modes "$SCREEN_RESOLUTION"
    EndSubSection
EndSection
EOL'
echo -e "\033[0;32mX11 configuration updated.\033[0m"

# Inform the user
echo -e "\033[0;32m==== Setup Complete ====\033[0m"
echo -e "\033[0;32mReboot the system to apply changes.\033[0m"
echo "You entered Kiosk URL: $KIOSK_URL"
echo "You entered Screen Resolution: $SCREEN_RESOLUTION"

echo -e "\n\n\033[1;32mSetup complete. Reboot your system to apply the changes.\033[0m"

# Countdown timer with Ctrl+C cancellation
echo -e "\033[0;33mThe system will reboot in 10 seconds. Press Ctrl+C to cancel.\033[0m"
for i in {10..1}; do
    printf "\rRebooting in %d seconds... " "$i"
    sleep 1
done

# Reboot if the countdown is not interrupted
echo -e "\n\033[0;32mRebooting now...\033[0m"
sudo reboot
