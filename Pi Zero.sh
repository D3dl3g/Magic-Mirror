#!/bin/bash

# Color definitions
bold_green='\033[1;32m'
bold_orange='\033[1;33m'
bold_yellow='\033[1;33m'
bold_red='\033[1;31m'        # Bold red color
unbold_green='\033[0;32m'
unbold_orange='\033[0;33m'
unbold_yellow='\033[0;33m'
unbold_red='\033[0;31m'
unbold='\033[0m'

# Function to handle CTRL+C (Interrupt)
trap ctrl_c INT
function ctrl_c() {
    echo -e "\n${bold_red}Reboot canceled. Proceeding without reboot.${unbold}\n\n"
    exit 0
}

# Check if the override.conf file exists for auto-login
AUTOLOGIN_FILE="/etc/systemd/system/getty@tty1.service.d/override.conf"

if [ -f "$AUTOLOGIN_FILE" ]; then
    echo -e "${unbold_green}Auto-login configuration already exists.${unbold}"
else
    echo -e "${unbold_orange}Enabling console auto-login for user 'pi'...${unbold}"

    # Create or modify the override.conf file for auto-login
    sudo mkdir -p /etc/systemd/system/getty@tty1.service.d/
    echo -e "[Service]\nExecStart=\nExecStart=-/sbin/agetty --autologin pi --noclear %I \$TERM" | sudo tee $AUTOLOGIN_FILE > /dev/null

    # Reload systemd to apply the changes
    sudo systemctl daemon-reload
    echo -e "${unbold_green}Console auto-login enabled for user 'pi'.${unbold}"
fi

# Check if swap is enabled
if [ $(free | grep Swap | awk '{print $2}') -gt 0 ]; then
    echo -e "${unbold_orange}Swap is enabled.${unbold}"
    echo -e "${unbold_yellow}Stopping swap service${unbold} and ${unbold_red}disabling swap...${unbold}"
    # Stop the dphys-swapfile service
    sudo service dphys-swapfile stop
    # Recheck swap status
    if [ $(free | grep Swap | awk '{print $2}') -eq 0 ]; then
        echo -e "${unbold_green}Swap Disabled.${unbold}"
    fi
    # Label for removing the service
    echo -e "${unbold_orange}Removing \"dphys-swapfile\"...${unbold}"
    # Remove the dphys-swapfile service
    sudo apt-get purge -y dphys-swapfile
else
    echo -e "${unbold_green}Swap is already disabled.${unbold}"
fi

# Update system packages (minimized output)
echo -e "${unbold_orange}Updating packages...${unbold}"
sudo apt-get update -qq && sudo apt-get upgrade -y -qq > /dev/null && echo -e "${unbold_green}System updated.${unbold}"

# Install required packages (minimized output)
echo -e "${unbold_orange}Installing necessary packages...${unbold}"
sudo apt-get install --no-install-recommends -y -qq midori matchbox-window-manager xserver-xorg xinit x11-xserver-utils unclutter xdotool lm-sensors > /dev/null && echo -e "${unbold_green}Packages installed.${unbold}"

# Add one blank lines
echo -e "\n"

# Check if the line exists in .bashrc and add it if necessary
line="######## <GITHUB LINK> LINE ADDED FOR KIOSK MODE ########"
bashrc_line="xinit /home/pi/kiosk -- vt\$(fgconsole)"

# Check if the line already exists in .bashrc
if ! grep -Fxq "$bashrc_line" ~/.bashrc; then
    echo -e "${unbold_green}Adding kiosk mode startup line to .bashrc...${unbold}"
    echo -e "\n$line" >> ~/.bashrc
    echo -e "$bashrc_line" >> ~/.bashrc
else
    echo -e "${unbold_green}Kiosk mode line already exists in .bashrc.${unbold}"
fi

# Ask the user for the MagicMirror server URL
echo -e "\n${unbold_green}Please enter the full URL of your MagicMirror Server (e.g., http://192.168.1.100:8080 or http://mm-server:8081):${unbold}"
read MM_URL


# Create the ~/kiosk file and add the script contents
echo -e "\n${unbold_orange}Creating ~/kiosk script...${unbold}"

cat << EOF > ~/kiosk
#!/bin/sh
xset -dpms     # disable DPMS (Energy Star) features.
xset s off     # disable screen saver
xset s noblank # don't blank the video device
matchbox-window-manager -use_titlebar no &
unclutter &    # hide X mouse cursor unless mouse activated
midori -e Fullscreen $MM_URL

# Wait for 30 seconds
sleep 30

# Send two F11 key presses
xdotool key F11
sleep 2
xdotool key F11
EOF

# Confirm script creation
echo -e "${unbold_green}~/kiosk Script Successfully Created.${unbold}"

# Make the script executable
chmod +x ~/kiosk

# Confirm script is executable
echo -e "${unbold_green}~/kiosk Script is Now Executable.${unbold}"


# Create the /etc/X11/xorg.conf file with the necessary configuration
echo -e "\n${unbold_orange}Creating /etc/X11/xorg.conf file...${unbold}"

# Create the xorg.conf file
sudo bash -c 'cat << EOF > /etc/X11/xorg.conf
Section "Screen"
    Identifier "Screen 0"
    Device "HDMI-1"
    SubSection "Display"
        Modes "1920x1080"
    EndSubSection
EndSection
EOF'

# Confirm creation of the xorg.conf file
echo -e "${unbold_green}/etc/X11/xorg.conf file successfully created.${unbold}"


echo -e "${unbold_orange}Removing Non-required Packages...${unbold}"
sudo apt-get autoremove -y -qq > /dev/null && echo -e "${unbold_green}Non-required Packages Removed.${unbold}"

# Final message (bold green)
echo -e "\n${bold_green}Setup complete.${unbold}"

# Countdown before reboot (60 seconds)
echo -e "\n ${unbold_orange}Rebooting in 60 seconds... Press Ctrl+C to cancel.${unbold}"

for i in {60..1}; do
    echo -ne "$i seconds remaining...\r"
    sleep 1
done

# Reboot the system
sudo reboot
