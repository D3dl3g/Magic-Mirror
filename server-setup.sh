#!/bin/bash
# MagicMirror² Auto Installer — with full logging
# Logs all output to file, including errors

# Redirect all output to log file and terminal
LOG_FILE="/var/log/mm-server-install.log"
mkdir -p /var/log
exec &> >(tee -a "$LOG_FILE")

# Color codes
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
ORANGE='\033[0;33m'
NC='\033[0m' # No Color

echo
echo -e "${YELLOW}D3dl3g's Proxmox MagicMirror² Server Auto Installer${NC}"
echo
echo
echo "Date: $(date)"
echo
echo "Log: $LOG_FILE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Exit on error, undefined vars, and pipeline failures
set -euo pipefail

# Trap to log errors
error_handler() {
    echo "ERROR: Command failed: '$BASH_COMMAND' (line $LINENO)" | tee -a "$LOG_FILE" >&2
}
trap error_handler ERR

# Trap Ctrl+C gracefully
trap 'echo -e "\n${RED}Installation interrupted by user.${NC}\nLog saved to $LOG_FILE"; exit 130' INT

# === INTERACTIVE USER INPUT ===
read -p "👤  Enter username: " USERNAME

# Validate username
if [[ ! "$USERNAME" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
    echo "👤  Invalid username. Must start with letter/underscore, lowercase only." >&2
    exit 1
fi

# Check if user exists
if id "$USERNAME" &>/dev/null; then
    echo "👤  User '$USERNAME' already exists. Choose a different name." >&2
    exit 1
fi

# Securely prompt for password
read -s -p "🔐  Enter password for $USERNAME: " USER_PASSWORD
echo
read -s -p "🔐  Confirm password: " USER_PASSWORD_CONFIRM
echo

if [[ "$USER_PASSWORD" != "$USER_PASSWORD_CONFIRM" ]]; then
    echo "🔐  Passwords do not match. Exiting." >&2
    exit 1
fi

# === AUTO-DETECT CURRENT IP ===
CURRENT_IP=$(ip -4 addr show scope global | awk '/inet / {gsub(/\/.*/, "", $2); print $2; exit}')

# Fallback and validation
if [[ -z "$CURRENT_IP" ]]; then
    echo "No IP address found on this machine." >&2
    echo "Please check your network connection and ensure the router has assigned an IP." >&2
    echo "Once fixed, re-run this script." >&2
    exit 1
fi

# === CUSTOM IP OPTION ===
echo -e "🌐  Current container IP: ${BLUE}$CURRENT_IP${NC}"
read -p "🌐  Would you like to set a custom static IP? (y/N): " SET_STATIC
echo

if [[ "$SET_STATIC" =~ ^[Yy]$ ]]; then
    read -p "🌐  Enter static IP for MagicMirror (e.g. ${GREEN}$CURRENT_IP${NC}): " MIRROR_IP
    MIRROR_IP=${MIRROR_IP:-$CURRENT_IP}
else
    MIRROR_IP=$CURRENT_IP
    echo -e "🌐  Using current IP as server address: ${GREEN}$MIRROR_IP${NC}"
fi

# Validate IP format
if ! [[ "$MIRROR_IP" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
    echo -e "🌐  Invalid IP address format: ${GREEN}$MIRROR_IP${NC}" >&2
    exit 1
fi

# Validate each octet (0-255)
if ! [[ "$MIRROR_IP" =~ ^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$ ]]; then
    echo -e "🌐  One or more octets out of range (0-255): ${GREEN}$MIRROR_IP${NC}" >&2
    exit 1
fi

# === UPDATE SYSTEM ===
echo -e "⚙️  ${YELLOW}Updating system packages...${NC}"
apt update &>/dev/null
apt upgrade -y &>/dev/null || { echo -e "⚙️  ${RED}Failed to upgrade system.${NC}" >&2; exit 1; }

# === INSTALL DEPENDENCIES ===
apt install -y sudo curl wget &>/dev/null || { echo -e "⚙️  ${RED}Failed to install dependencies.${NC}" >&2; exit 1; }

# === CREATE USER ===
echo -e "👤 ⚙️  ${GREEN}Creating user: $USERNAME${NC}"
adduser --disabled-password --gecos "" "$USERNAME"
echo -e "$USERNAME:$USER_PASSWORD" | chpasswd
echo -e "👤 ⚙️  ${GREEN}User $USERNAME created and password set${NC}"

# === ADD TO SUDO GROUP ===
usermod -aG sudo "$USERNAME"
echo -e "👤 ⚙️  ${GREEN}$USERNAME added to sudo group (password required)${NC}"

# === INSTALL MAGICMIRROR ===
su - "$USERNAME" -c "
    exec script -q -c \"
        bash -c \\\"\\\$(curl -sL https://raw.githubusercontent.com/sdetweil/MagicMirror_scripts/master/raspberry.sh)\\\"
    \" /dev/null
" || { echo "MagicMirror installer failed. See log for details." >&2; exit 1; }

# === CONFIGURE config.js ===
CONFIG_FILE="/home/$USERNAME/MagicMirror/config/config.js"

if [[ -f "$CONFIG_FILE" ]]; then
    sed -i "s|address:[[:space:]]*\"localhost\"|address: \"$MIRROR_IP\"|" "$CONFIG_FILE"
    sed -i 's/ipWhitelist: \["127\.0\.0\.1", "::ffff:127\.0\.0\.1", "::1"\],/ipWhitelist: [],/' "$CONFIG_FILE"
    chown "$USERNAME:$USERNAME" "$CONFIG_FILE"
    echo -e "⚙️ ${GREEN}Config updated: bound to $MIRROR_IP${NC}"
else
    echo "⚙️ config.js not found. Installation may be incomplete." >&2
    exit 1
fi

# === CREATE PM2 START SCRIPT ===
SERVER_SCRIPT="/home/$USERNAME/MagicMirror/installers/mm-server.sh"
mkdir -p "/home/$USERNAME/MagicMirror/installers"

cat > "$SERVER_SCRIPT" << 'EOF'
#!/bin/bash
cd ~/MagicMirror
npm run server
EOF

chmod +x "$SERVER_SCRIPT"
chown "$USERNAME:$USERNAME" "$SERVER_SCRIPT"
echo -e "⚙️ ${GREEN}PM2 start script created: $SERVER_SCRIPT${NC}"

# === SETUP PM2: Start & Save ===
su - "$USERNAME" -c "
    export PATH=\$HOME/bin:\$HOME/.npm-global/bin:\$PATH
    pm2 delete all 2>/dev/null || true
    pm2 start \$HOME/MagicMirror/installers/mm-server.sh --name MagicMirror²Server
    pm2 save
" || { echo "⚙️ Failed to configure PM2." >&2; exit 1; }

# === ENABLE PM2 BOOT STARTUP ===
echo -e "⚙️ ${GREEN}Enabling PM2 startup...${NC}"
su - "$USERNAME" -c "pm2 startup systemd --silent" || true
su - "$USERNAME" -c "pm2 save" &>/dev/null

# === FINAL MESSAGE ===
echo -e "⚙️ ${GREEN}Removing Non-required Packages...${NC}"
sudo apt-get autoremove -y -qq > /dev/null 2>&1 && echo -e "⚙️ ${GREEN}Non-required Packages Removed.${NC}"

echo
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "⚙️ ${GREEN}SETUP COMPLETE!${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "👤 User: ${GREEN}$USERNAME${NC}"
echo -e "🌐 Access at: ${GREEN}http://$MIRROR_IP:8080${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📝 Full log saved to: $LOG_FILE"

# Countdown before reboot (30 seconds)
for i in {30..1}; do
    echo -ne "${ORANGE}$i seconds remaining...${NC}\r"
    sleep 1
done

# Reboot the system
echo -e "\n${YELLOW}Rebooting now...${NC}"
sudo reboot
