#!/bin/bash

# Function to print text with grey color for default values
print_grey() {
    echo -e "\033[0;37m$1\033[0m"
}

# Exit immediately if a command exits with a non-zero status
set -e

# Prompt the user for customization
echo -e "\033[0;32m==== Kiosk Setup Script ====\033[0m"

# Kiosk URL Prompt with default value in grey and flashing cursor
echo -n "Enter the Kiosk URL (default: "
print_grey "http://<MM_SERVER_IP>"
echo -n "): "
read -e -i "http://<MM_SERVER_IP>" KIOSK_URL
KIOSK_URL=${KIOSK_URL:-http://<MM_SERVER_IP>}

# Screen Resolution Prompt with default value in grey and flashing cursor
echo -n "Enter the screen resolution (default: "
print_grey "1920x1080"
echo -n "): "
read -e -i "1920x1080" SCREEN_RESOLUTION
SCREEN_RESOLUTION=${SCREEN_RESOLUTION:-1920x1080}

# Update and upgrade system
echo "Updating and upgrading system packages..."
sudo apt update
sudo apt upgrade -y

# Disable and remove swap to save resources
echo -e "\033[0;33mSynchronizing state of dphys-swapfile.service with SysV service script with /lib/systemd/systemd-sysv-install.\033[0m"
sudo service dphys-swapfile stop
echo "Stopped dphys-swapfile service."
echo -e "\033[0;33mExecuting: /lib/systemd/systemd-sysv-install disable dphys-swapfile\033[0m"
sudo systemctl disable dphys-swapfile
echo "Disabled dphys-swapfile service."
sudo apt-get purge -y dphys-swapfile
echo -e "\033[0;31mRemoved /etc/systemd/system/multi-user.target.wants/dphys-swapfile.service.\033[0m"
echo "Removed dphys-swapfile package."

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

echo ""
echo -e "\033[0;32mSetup complete. Reboot your system to apply the changes.\033[0m"

# Countdown timer with Ctrl+C cancellation
echo "The system will reboot in 10 seconds. Press Ctrl+C to cancel."
for i in {10..1}; do
    printf "\rRebooting in %d seconds... " "$i"
    sleep 1
done

# Reboot if the countdown is not interrupted
echo ""
echo -e "\033[0;32mRebooting now...\033[0m"
sudo reboot
