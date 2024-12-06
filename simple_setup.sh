#!/bin/bash
# Thin Client Setup
# Compatible with Debian-based systems
# Author: Jackson Baer
# Date: 27 Nov 2024
#git clone https://github.com/JacksonBaer/debianvdi.git && cd debianvdi/ && chmod +x simple_setup.sh

#Establishes Log File
LOG_FILE="/var/log/thinclient_setup.log"

log_event() {
    echo "$(date) [$(hostname)] [User: $(whoami)]: $1" >> /var/log/thinclient_setup.log
}


# Ensure the log file exists
if [ ! -f "$LOG_FILE" ]; then
    touch "$LOG_FILE"
     log_event "Log file created."
fi

log_event "Starting Thin Client Setup script"


# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  log_event "User ID is $EUID. Exiting if not root."
  exit
fi

# Prompt for the Proxmox IP or DNS name
read -p "Enter the Proxmox IP or DNS name: " PROXMOX_IP

# Prompt for the Thin Client Title
read -p "Enter the Thin Client Title: " VDI_TITLE

while true; do
    read -p "Enter authentication type (pve or pam): " VDI_AUTH
    if [ "$VDI_AUTH" == "pve" ] || [ "$VDI_AUTH" == "pam" ]; then
        echo "You selected $VDI_AUTH authentication."
        break  # Exit the loop when a valid input is provided
    else
        echo "Error: Invalid input. Please enter 'PVE' or 'PAM'."
    fi
done

log_event  "Proxmox IP/DNS entered: $PROXMOX_IP"
log_event  "Thin Client Title entered: $VDI_TITLE"
log_event "Authentication type selected: $VDI_AUTH"

# Update and upgrade system
echo "Updating and upgrading system packages"
log_event "Updating and upgrading system packages"
echo "Updating and upgrading system..."
sudo apt update && sudo apt upgrade -y

#Adding License File
#PySimple Dev Key
echo "ePy6JrMIatWENTlUbYnrNIleVGHIlEw4ZySqIB6ZI5kgRMlrdvm0VusMbA3XBiltcXi5ITsMIXkIxJppYe2jVtuLcg2RV9JXR7CbIB6iM1TVcwzTMxTHUy0DMMTaUOx3NSyKw5iSTZGVl0j2ZMWs5bz5ZaUzRUlzcpGYxRviePWR1flJb5n5RVW9ZvX2JBzmaFWt9aubImj2oox2LGCEJNO9Y8WU1KlaRUmRlRyjcX3EQXiaOCicJ1KWY0WtNurgcA2q9AuvI7iKwgiGTxmcFZt4ZpUHxthvcd3pQgiuO4ivJ0CiY2WCVnyBIeiuwniGQT2a9PtXcGGVFGuSeYSHId6sI7ivIBswIGkNNb12ch3GRhvZbVWDVnyMSDUHQTidOIipIh0iNqjWIS42N5iHIIsqIikuRghOdmGiVnJecc3YNu1oZ2WrQhiMOKiZI3xVMxS88zxBNlCo88y2MADoIU0KI1iRwyizRXGtFb0KZUUtVP45cyGZljyXZHXEM7iMOdijIFxQMOSb8qxPNhCl8jyCMtDXIN1iIxi8wRipRaW11ahYaxWkxsBQZbGDRYyxZHXgNWzhIAjgoiiQa1mBFNjBaB3ENpvcbOi15yiQYTW5VWyvMbjwAewiN2ERBBnNb7WsFMpHbSCP5wjPbt2H0siSLsCbJZJpUAEbFqk4ZWHoJjl5co34Mbi3OXiXIX2QNkiX4Y0rNgSn45x5MRj1ggurM3jvUhyxIEni02=r593ac8659d1c61fecfb1ee42194408e1c0bb0463f820e3a443de56a73d843787d52ab187750eb8b30559ae80cc51a1b4166d64d440ecef8dd405beaf8116152f5b3c21c0c042546ad7dbbe145fad912ea6bacc30617bc08dc5877a5e0076eb28f1c75f3ac61b7db0bc626b7b519e7c3dbc5d1919f10cc8ce91e40c6f779fbf3816710c6f493ca13e90920d95dad168f05c370eb3f70f4b6e69bef4283b345a73eccaecaffbeeb8bd8a4a760f56bf814cd84f38c15bb73e7ba746c52a62d176380de62f475bc65d4c1bc5744d04187de8ebd47f3191691a9c623c8a99a55f03c84e32aba967541808dec91ad3917886d41617ebc9e194cb9c34e21aa15eda431f005e2984d7a65750010450eeaeabd41e12b25f79c23b74c1564b75f3e4a69bd884d97b70ec401d34e534f465fa67b0d1dd5b312760a334a1770374ecb432be90c5f659cc293d3e888dcb2100fefc684219eb50464542eff97ca3193c845c1e9d96abb40e219a09cd14e9d5f6f9e05de3db383aaec2dd93cbca20d8584cadd70ab6e9438b395022f2d770646e8d6622320b00b487f30500d39cab5f539be99dad278ed4950dbebc4a9bf32150e55443e9e6f6e5f13a13b36cfa12f362ccb4928c5ecf36426c83bd31ce68cfc6c731be90a01f19b653d30526a9069b293dbfe5498fb525f53241403d7feddb249c75829b9749d4a8401267333dc425cc75970b8f" > license.txt

# Install required packages
log_event "Installing required dependencies..."
echo "$(date): Installing required dependencies..."

sudo apt install python3-pip  virt-viewer lxde lightdm lightdm-gtk-greeter -y
sudo apt install python3-tk -y
# Install Python dependencies
echo "Installing Python dependencies..."
pip3 install proxmoxer "PySimpleGUI<5.0.0"

# Clone the repository and navigate into it
echo "Cloning PVE-VDIClient repository..."
log_event "Cloning PVE-VDIClient repository..."

cd /home/vdiuser
git clone https://github.com/joshpatten/PVE-VDIClient.git
cd ./PVE-VDIClient || { echo "Failed to change directory to PVE-VDIClient"; exit 1; }

# Make the script executable
echo "Making vdiclient.py executable..."
chmod +x vdiclient.py

# Create the configuration directory and file
echo "Setting up configuration..."
echo "Creating vdiclient configuration file"
log_event "Creating vdiclient configuration file"

sudo mkdir -p /etc/vdiclient
sudo tee /etc/vdiclient/vdiclient.ini > /dev/null <<EOL
[General]

title = $VDI_TITLE
icon=vdiicon.ico
logo=vdilogo.png
kiosk=false
theme=Black2

[Authentication]
auth_backend=$VDI_AUTH
auth_totp=false
tls_verify=false

[Hosts]
$PROXMOX_IP=8006
EOL

# Copy vdiclient.py to /usr/local/bin
echo "Copying vdiclient.py to /usr/local/bin..."
echo "$(date): Copying vdiclient.py to /usr/local/bin..." >> $LOG_FILE
sudo cp vdiclient.py /usr/local/bin/vdiclient

# Copy optional images
# echo "Copying optional images..."
# sudo cp vdiclient.png /etc/vdiclient/
# sudo cp vdiicon.ico /etc/vdiclient/

# Add the required line to the user's autostart file
echo "@/usr/bin/bash /home/vdiuser/thinclient" > ~/.config/lxsession/LXDE/autostart

# Create thin client script
echo "Creating thinclient script..."
touch ~/thinclient

cat <<'EOL' > ~/thinclient
#!/bin/bash
# Navigate to the PVE-VDIClient directory
cd ~/PVE-VDIClient
# Run loop for thin client to prevent user closure
while true; do
    /usr/bin/python3 ~/PVE-VDIClient/vdiclient.py
done
EOL

# Make thinclient script executable
chmod +x ~/thinclient


# Define the username
USERNAME="vdiuser"

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
  echo "Please run this script as root or with sudo."
  exit 1
fi

# Add the user if they don't exist
if ! id "$USERNAME" &>/dev/null; then
  echo "User $USERNAME does not exist. Creating user..."
  adduser --gecos "" "$USERNAME"
else
  echo "User $USERNAME already exists."
fi

# Configure autologin in LightDM
LIGHTDM_CONF="/etc/lightdm/lightdm.conf"

echo "Configuring LightDM for autologin..."
echo "$(date): Configuring LightDM autologin for $USERNAME" >> $LOG_FILE

{
  echo "[Seat:*]"
  echo "autologin-user=$USERNAME"
  echo "autologin-user-timeout=0"
  echo "xserver-command=X -s 0 -dpms"

  
} >"$LIGHTDM_CONF"
# Confirm changes
if [ $? -eq 0 ]; then
  echo "LightDM autologin configured successfully for $USERNAME."
  log_event "$(date): Checking existence of user $USERNAME"

else
  echo "Failed to configure LightDM autologin."
  exit 1
fi

# Add the required line to the user's autostart file
echo "@/usr/bin/bash /home/vdiuser/thinclient" > /home/vdiuser/.config/lxsession/LXDE/autostart

# Create thin client script
echo "Creating thinclient script..."
log_event "Creating thinclient script"
touch /home/vdiuser/thinclient

cat <<'EOL' > /home/vdiuser/thinclient
#!/bin/bash
sleep 1
/usr/bin/openbox --exit
# Navigate to the PVE-VDIClient directory
cd ~/PVE-VDIClient
# Run loop for thin client to prevent user closure
while true; do
    /usr/bin/python3 ~/PVE-VDIClient/vdiclient.py
done
EOL

# Make thinclient script executable
log_event "Making ~/thinclient Bootable"
chmod +x ~/thinclient
#Restarting the client
log_event "Rebooting System to Apply Changes"
sudo reboot

# # Restart client for changes to take effect
# echo " If this is your initial installation of the VDI client, Please wait to restart the client"
# echo " You will need to Cat the contents of the newly created "license.txt" file from the client device and manually open the vdiclient.py file and register the gui backend"
# read -p "Configuration complete. Do you want to restart the system now? (y/n): " RESTART
# if [[ "$RESTART" =~ ^[Yy]$ ]]; then
#   echo "Restarting the system..."
#   sudo reboot
# else
#   echo "Please reboot the system manually to apply changes."
# fi
# exit 0
# echo "Setup complete! Reboot the system for changes to take effect."





