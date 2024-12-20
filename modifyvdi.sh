#!/bin/bash
# Modify Thin Client Ini Config
# Compatible with Debian-based systems
# Author: Jackson Baer
# Date: 27 Nov 2024

# Establish Log File
LOG_FILE="/var/log/thinclient_setup.log"

# Create Log_Event Function for log functions
log_event() {
    echo "$(date): $1" >> /var/log/thinclient_setup.log
}

# Ensure the log file exists
if [ ! -f "$LOG_FILE" ]; then
    touch "$LOG_FILE"
    log_event "Log file created."
fi

log_event "Starting Modify Thin Client script"

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  log_event "User ID is $EUID. Exiting because script was not run as root."
  exit
fi

# Parse command-line arguments
AUTO_RESTART=""
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --ip) PROXMOX_IP="$2"; shift ;;
        --title) VDI_TITLE="$2"; shift ;;
        --auth) VDI_AUTH="$2"; shift ;;
        --theme) VDI_THEME="$2"; shift ;;
        -y) AUTO_RESTART="yes" ;;
        -n) AUTO_RESTART="no" ;;
        *) echo "Unknown parameter: $1"; exit 1 ;;
    esac
    shift
done

# Validate required inputs
if [ -z "$PROXMOX_IP" ] || [ -z "$VDI_TITLE" ] || [ -z "$VDI_AUTH" ] || [ -z "$VDI_THEME" ]; then
    echo "Usage: $0 --ip <Proxmox_IP> --title <Thin_Client_Title> --auth <pve|pam> --theme <theme_name> [-y|-n]"
    log_event "Missing required arguments. Exiting."
    exit 1
fi

# Validate authentication method
if [[ "$VDI_AUTH" != "pve" && "$VDI_AUTH" != "pam" ]]; then
    echo "Error: Authentication method must be 'pve' or 'pam'."
    log_event "Invalid authentication method provided: $VDI_AUTH"
    exit 1
fi

# Log User Inputs
log_event "Proxmox IP Address: $PROXMOX_IP, Thin Client Title: $VDI_TITLE, Authentication Method: $VDI_AUTH, Theme: $VDI_THEME"

# Modify the configuration directory and file
echo "Modifying configuration..."

sudo tee /etc/vdiclient/vdiclient.ini > /dev/null <<EOL
[General]

title = $VDI_TITLE
icon=vdiicon.ico
logo=vdilogo.png
kiosk=false
theme=$VDI_THEME

[Authentication]
auth_backend=$VDI_AUTH
tls_verify=false

[Hosts]
$PROXMOX_IP=8006
EOL

log_event "Configuration file created with theme: $VDI_THEME"

# Handle auto-restart logic
if [ "$AUTO_RESTART" == "yes" ]; then
    echo "Restarting the system..."
    log_event "System reboot initiated via -y option."
    sudo reboot
elif [ "$AUTO_RESTART" == "no" ]; then
    echo "Restart skipped as per -n option."
    log_event "System reboot skipped via -n option."
else
    # Interactive prompt if neither -y nor -n is provided
    read -p "Configuration complete. Do you want to restart the system now? (y/n): " RESTART
    if [[ "$RESTART" =~ ^[Yy]$ ]]; then
        echo "Restarting the system..."
        log_event "System reboot initiated interactively."
        sudo reboot
    else
        echo "Please reboot the system manually to apply changes."
        log_event "System reboot skipped interactively."
    fi
fi
