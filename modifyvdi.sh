#!/bin/bash
# Modify Thin Client Ini Config
# Compatible with Debian-based systems
# Author: Jackson Baer
# Date: 27 Nov 2024

#Establishes Log File
LOG_FILE="/var/log/thinclient_setup.log"

#Create Log_Event Function for log functions
log_event() {
    echo "$(date): $1" >> /var/log/thinclient_setup.log
}

# Ensure the log file exists
if [ ! -f "$LOG_FILE" ]; then
    touch "$LOG_FILE"
     log_event "Log file created."
fi

log_event "Starting Modift Thin Client  script"


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
#Prompt For Authentification Method for client
read -p "Enter Your Preferred Authentication Method {PVE, PAM}: " VDI_AUTH
 
while true; do
    read -p "Enter authentication type (pve or pam): " VDI_AUTH
    if [ "$VDI_AUTH" == "pve" ] || [ "$VDI_AUTH" == "pam" ]; then
        echo "You selected $VDI_AUTH authentication."
        break  # Exit the loop when a valid input is provided
    else
        echo "Error: Invalid input. Please enter 'PVE' or 'PAM'."
    fi
done

#Logging User Inputs
log_event "Proxmox Ip Address: $PROXMOX_IP, Thin Client Title: $VDI_TITLE, Authentification Method: $VDI_AUTH "

# Modify the configuration directory and file
echo "Modifying configuration..."

sudo tee /etc/vdiclient/vdiclient.ini > /dev/null <<EOL
[General]

title = $VDI_TITLE
icon=vdiicon.ico
logo=vdilogo.png
kiosk=false

[Authentication]
auth_backend=$VDI_AUTH
auth_totp=false
tls_verify=false

[Hosts]
$PROXMOX_IP=8006
EOL


read -p "Configuration complete. Do you want to restart the system now? (y/n): " RESTART
if [[ "$RESTART" =~ ^[Yy]$ ]]; then
  echo "Restarting the system..."
  sudo reboot
else
  echo "Please reboot the system manually to apply changes."
fi


