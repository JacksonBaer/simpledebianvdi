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

# Install required packages
log_event "Installing required dependencies..."
echo "$(date): Installing required dependencies..."

sudo apt install python3-pip  virt-viewer lightdm lightdm-gtk-greeter -y
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
theme=LightBrown5

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

# Function to check if the system has a valid IP address
wait_for_ip() {
    echo "Waiting for a valid IP address..."

    # Start a Zenity progress dialog in the background
    (
        while true; do
            # Get the IP address assigned to the primary network interface (adjust 'eth0' if needed)
            IP_ADDRESS=$(ip -4 addr show eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
            
            # Check if an IP address was found
            if [ -n "$IP_ADDRESS" ]; then
                echo "100"  # Send completion signal to Zenity
                break
            fi
            
            # Send a progress update to Zenity
            echo "50"  # Arbitrary progress to keep Zenity alive
            sleep 2
        done
    ) | zenity --progress --no-cancel --pulsate --text="Waiting for a valid IP address..." --title="Network Initialization" --auto-close

    # Show a confirmation dialog when IP is obtained
    zenity --info --text="IP address obtained: $IP_ADDRESS" --title="Network Ready" --timeout=3
}

# Wait until an IP address is assigned
sleep 1
/usr/bin/openbox --exit

wait_for_ip


# Navigate to the PVE-VDIClient directory
cd ~/PVE-VDIClient

# Run loop for thin client to prevent user closure
while true; do
    /usr/bin/python3 ~/PVE-VDIClient/vdiclient.py
done
EOL

chmod +x /home/vdiuser/thinclient




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





