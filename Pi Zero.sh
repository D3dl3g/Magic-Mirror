#!/bin/bash

# Color definitions
bold_green='\033[1;32m'
bold_orange='\033[1;33m'
bold_yellow='\033[1;33m'
bold_red='\033[1;31m'
unbold_green='\033[0;32m'
unbold_orange='\033[0;33m'
unbold_yellow='\033[0;33m'
unbold_red='\033[0;31m'
unbold_blue='\033[0;34m'
unbold='\033[0m'

# Function to handle CTRL+C (Interrupt)
trap ctrl_c INT
function ctrl_c() {
    echo -e "\n${bold_red}Reboot canceled. Proceeding without reboot.${unbold}\n\n"
    exit 0
}

# Define the correct config.txt path
CONFIG_PATH="/boot/config.txt"

# Check if config.txt exists, if not, create it
if [ ! -f "$CONFIG_PATH" ]; then
  echo -e "\033[0;33mconfig.txt not found, creating a new one...\033[0m"
else
  echo -e "\033[0;31mWarning: $CONFIG_PATH already exists, it will be overwritten.\033[0m"
fi

# Backup the existing config.txt if it exists
if [ -f "$CONFIG_PATH" ]; then
  echo -e "\033[0;31mBacking up the existing config.txt to config.bk...\033[0m"
  sudo mv "$CONFIG_PATH" /boot/config.bk
fi

# Auto-detect architecture and set arm_64bit=1 if applicable
ARCHITECTURE=$(uname -m)

# Initialize the variable
ARM_64BIT=""

if [[ "$ARCHITECTURE" == "aarch64" || "$ARCHITECTURE" == "arm64" ]]; then
    ARM_64BIT="arm_64bit=1"
    echo -e "\033[0;32m***Detected 64-bit ARM architecture ($ARCHITECTURE).***\033[0m"
else
    echo -e "\033[0;32m***Detected 32-bit ARM architecture ($ARCHITECTURE).***\033[0m"
fi

# Create a new config.txt with the desired content
echo -e "\033[0;33mCreating the new config.txt...\033[0m"

# Use sudo tee to write the new config.txt
sudo tee /boot/firmware/config.txt > /dev/null <<EOF
# For more options and information see
# http://rpf.io/configtxt
# Some settings may impact device functionality. See link above for details

# uncomment if you get no picture on HDMI for a default "safe" mode
#hdmi_safe=1

# uncomment the following to adjust overscan. Use positive numbers if console
# goes off screen, and negative if there is too much border
#overscan_left=16
#overscan_right=16
#overscan_top=16
#overscan_bottom=16

# uncomment to force a console size. By default it will be display's size minus
# overscan.
#framebuffer_width=1280
#framebuffer_height=720

# uncomment if hdmi display is not detected and composite is being output
#hdmi_force_hotplug=1

# uncomment to force a specific HDMI mode (this will force VGA)
#hdmi_group=1
#hdmi_mode=1

# uncomment to force a HDMI mode rather than DVI. This can make audio work in
# DMT (computer monitor) modes
#hdmi_drive=2

# uncomment to increase signal to HDMI, if you have interference, blanking, or
# no display
#config_hdmi_boost=4

# uncomment for composite PAL
#sdtv_mode=2

#uncomment to overclock the arm. 700 MHz is the default.
#arm_freq=800

# Uncomment some or all of these to enable the optional hardware interfaces
#dtparam=i2c_arm=on
#dtparam=i2s=on
#dtparam=spi=on

# Uncomment this to enable infrared communication.
#dtoverlay=gpio-ir,gpio_pin=17
#dtoverlay=gpio-ir-tx,gpio_pin=18

# Additional overlays and parameters are documented /boot/overlays/README

# Enable audio (loads snd_bcm2835)
#dtparam=audio=on

# Automatically load overlays for detected cameras
#camera_auto_detect=1

# Automatically load overlays for detected DSI displays
#display_auto_detect=1

# Enable DRM VC4 V3D driver
#dtoverlay=vc4-kms-v3d
#max_framebuffers=2

# Disable compensation for displays with overscan
#disable_overscan=1

[cm4]
# Enable host mode on the 2711 built-in XHCI USB controller.
# This line should be removed if the legacy DWC2 controller is required
# (e.g. for USB device mode) or if USB support is not required.
#otg_mode=1

[all]

[pi4]
# Run as fast as firmware / board allows
#arm_boost=1

[all]
gpu_mem=128
EOF

echo -e "\033[0;32mconfig.txt has been created and updated successfully!\033[0m"

# Prompt the user for the username to enable autologin for
echo -e "\033[0;33mPlease enter the username for autologin (default: pi):\033[0m"
read -r username
username=${username:-pi}  # Default to 'pi' if no input is provided

echo -e "\033[0;32mAutologin will be configured for user: $username\033[0m"

# Check if the user exists
if id "$username" &>/dev/null; then
    echo -e "\033[0;32mUser '$username' exists.\033[0m"
else
    # User does not exist, create the user
    echo -e "\033[0;31mUser '$username' does not exist. Creating the user...\033[0m"
    sudo adduser --gecos "" --disabled-password "$username"
    echo -e "\033[0;32mUser '$username' has been created.\033[0m"

    # Prompt for password if the user wants to set one
    echo -e "\033[0;33mDo you want to set a password for user '$username'? (y/n):\033[0m"
    read -r set_password
    if [[ "$set_password" == "y" || "$set_password" == "Y" ]]; then
        echo -e "\033[0;33mPlease enter the password for user '$username':\033[0m"
        sudo passwd "$username"
        echo -e "\033[0;32mPassword for user '$username' has been set.\033[0m"
    else
        echo -e "\033[0;32mNo password set for user '$username'.\033[0m"
    fi

    # Add user to the sudo group
    sudo usermod -aG sudo "$username"
    echo -e "\033[0;32mUser '$username' has been added to the sudo group.\033[0m"
fi

# Check if the override.conf file exists for auto-login
AUTOLOGIN_FILE="/etc/systemd/system/getty@tty1.service.d/override.conf"

if [ -f "$AUTOLOGIN_FILE" ]; then
    echo -e "${unbold_green}Auto-login configuration already exists.${unbold}"
else
    echo -e "${unbold_orange}Enabling console auto-login for user 'pi'...${unbold}"

# Setting up autologin for tty1 with the selected or newly created user
echo -e "\033[0;33mSetting up autologin for tty1...\033[0m"
sudo mkdir -p /etc/systemd/system/getty@tty1.service.d/
cat <<EOF | sudo tee /etc/systemd/system/getty@tty1.service.d/autologin.conf > /dev/null
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $username --noclear %I \$TERM
EOF
echo -e "\033[0;32mAutologin for tty1 configured for user: $username.\033[0m"
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
sudo apt-get purge -y -qq dphys-swapfile > /dev/null 2>&1

# Confirm successful removal
echo -e "${unbold_green}\"dphys-swapfile\" Successfully Removed.${unbold}"
else
    echo -e "${unbold_green}Swap is already disabled.${unbold}"
fi

# Update system packages (minimized output)
echo -e "${unbold_orange}Updating packages...${unbold}"
sudo apt-get update -qq && sudo apt-get upgrade -y -qq > /dev/null 2>&1 && echo -e "${unbold_green}System updated.${unbold}"

# Install required packages (minimized output)
echo -e "${unbold_orange}Installing necessary packages...${unbold}"
sudo apt-get install --no-install-recommends -y -qq xserver-xorg xinit x11-xserver-utils openbox midori unclutter lm-sensors > /dev/null 2>&1 && echo -e "${unbold_green}Packages installed.${unbold}"

# Add one blank lines
#echo -e "\n"

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

# Ask the user for the MagicMirror server URL in blue
echo -e "\n${unbold_blue}Please enter the full URL of your MagicMirror Server (e.g., http://192.168.1.100:8080 or http://mm-server:8081):${unbold}"
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
sudo apt-get autoremove -y -qq > /dev/null 2>&1 && echo -e "${unbold_green}Non-required Packages Removed.${unbold}"

# Final message (bold green)
echo -e "\n${bold_green}Setup complete.${unbold}"

# Countdown before reboot (10 seconds)
echo -e "\n ${unbold_orange}Rebooting in 10 seconds... Press Ctrl+C to cancel.${unbold}"

for i in {10..1}; do
    echo -ne "$i seconds remaining...\r"
    sleep 1
done

# Reboot the system
sudo reboot
