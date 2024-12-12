#!/bin/bash

# Thin Client Setup Script with Dialog
# Compatible with Debian-based systems
# Author: Jackson Baer
# Date: 27 Nov 2024

# Check if dialog is installed
if ! command -v dialog &> /dev/null
then
    echo "Dialog is not installed. Installing it now..."
    sudo apt update && sudo apt install dialog -y
    if ! command -v dialog &> /dev/null
    then
        echo "Failed to install dialog. Please install it manually."
        exit 1
    fi
fi

# Log file
LOG_FILE="/var/log/thinclient_setup.log"
INSTALL_LOG="/tmp/thinclient_install.log"

log_event() {
    TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
    echo "$TIMESTAMP [$(hostname)] [User: $(whoami)]: $1" >> "$LOG_FILE"
    echo "$TIMESTAMP: $1" >> "$INSTALL_LOG"
}

# Ensure the log file exists
if [ ! -f "$LOG_FILE" ]; then
    touch "$LOG_FILE"
    log_event "Log file created."
fi

> "$INSTALL_LOG"  # Clear install log

log_event "Starting Thin Client Setup script"

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
  dialog --title "Error" --msgbox "Please run this script as root." 10 50
  log_event "User ID is $EUID. Exiting as not root."
  exit
fi

# Function to run commands with logging and progress bar
gauge_command() {
    local CMD="$1"
    local MSG="$2"
    log_event "Running: $CMD"
    (bash -c "$CMD" >> "$INSTALL_LOG" 2>&1) &
    local CMD_PID=$!
    { while ps -p $CMD_PID > /dev/null; do
        echo -n "# $MSG..."
        sleep 1
      done
    } | dialog --title "Progress" --gauge "$MSG" 10 70 0
    wait $CMD_PID
    if [ $? -ne 0 ]; then
        log_event "Command failed: $CMD"
        dialog --title "Error" --msgbox "An error occurred while running: $CMD. Check logs for details." 10 50
        exit 1
    fi
}

# Prompt for the Proxmox IP or DNS name
PROXMOX_IP=$(dialog --title "Proxmox IP or DNS" --inputbox "Enter the Proxmox IP or DNS name:" 10 50 3>&1 1>&2 2>&3 3>&-)
if [ $? -ne 0 ]; then
  log_event "User canceled input for Proxmox IP or DNS. Exiting script."
  dialog --title "Exit" --msgbox "You canceled the input. Exiting script." 10 50
  exit 1
fi

# Prompt for the Thin Client Title
VDI_TITLE=$(dialog --title "Thin Client Title" --inputbox "Enter the Thin Client Title:" 10 50 3>&1 1>&2 2>&3 3>&-)
if [ $? -ne 0 ]; then
  log_event "User canceled input for Thin Client Title. Exiting script."
  dialog --title "Exit" --msgbox "You canceled the input. Exiting script." 10 50
  exit 1
fi

# Prompt for the Authentication Type
VDI_AUTH=$(dialog --title "Authentication Type" --menu "Choose authentication type:" 15 50 2 \
"pve" "Proxmox Virtual Environment" \
"pam" "Pluggable Authentication Module" 3>&1 1>&2 2>&3 3>&-)
if [ $? -ne 0 ]; then
  log_event "User canceled input for Authentication Type. Exiting script."
  dialog --title "Exit" --msgbox "You canceled the input. Exiting script." 10 50
  exit 1
fi

log_event "Authentication type selected: $VDI_AUTH"

# Display network interfaces for user selection
AVAILABLE_INTERFACES=$(ip -o link show | awk -F': ' '{print $2}' | grep -v "lo")
INET_ADAPTER=$(dialog --title "Network Adapter" --menu "Select your Network Adapter:" 15 50 6 $(for iface in $AVAILABLE_INTERFACES; do echo "$iface $iface"; done) 3>&1 1>&2 2>&3 3>&-)
if [ $? -ne 0 ]; then
  log_event "User canceled input for Network Adapter. Exiting script."
  dialog --title "Exit" --msgbox "You canceled the input. Exiting script." 10 50
  exit 1
fi

log_event "Proxmox IP/DNS entered: $PROXMOX_IP"
log_event "Thin Client Title entered: $VDI_TITLE"
log_event "Network adapter selected: $INET_ADAPTER"

# Update and upgrade system
gauge_command "sudo apt update && sudo apt upgrade -y" "Updating and upgrading system packages"

# Install required packages
gauge_command "sudo apt install python3-pip virt-viewer lightdm zenity lightdm-gtk-greeter -y" "Installing dependencies"
gauge_command "sudo apt install python3-tk -y" "Installing Python 3 Tkinter"
gauge_command "pip3 install proxmoxer 'PySimpleGUI<5.0.0'" "Installing Python packages"

# Clone the repository
log_event "Cloning PVE-VDIClient repository"
if [ ! -d "/home/vdiuser" ]; then
  log_event "User directory /home/vdiuser does not exist. Exiting script."
  dialog --title "Error" --msgbox "User directory /home/vdiuser does not exist. Please create it before running the script." 10 50
  exit 1
fi
gauge_command "cd /home/vdiuser && git clone https://github.com/joshpatten/PVE-VDIClient.git" "Cloning PVE-VDIClient repository"
if [ ! -d "/home/vdiuser/PVE-VDIClient" ]; then
  log_event "Failed to clone PVE-VDIClient repository. Exiting script."
  dialog --title "Error" --msgbox "Failed to clone PVE-VDIClient repository. Check logs for details." 10 50
  exit 1
fi

# Configure VDI Client
log_event "Configuring VDI Client"
echo "Setting up configuration..."
mkdir -p /etc/vdiclient
cat <<EOL | sudo tee /etc/vdiclient/vdiclient.ini > /dev/null
[General]
title = $VDI_TITLE
icon=vdiicon.ico
logo=vdilogo.png
kiosk=false
theme=BrightColors

[Authentication]
auth_backend=$VDI_AUTH
auth_totp=false
tls_verify=false

[Hosts]
$PROXMOX_IP=8006
EOL

log_event "Configuration file created successfully."

# Create thin client script
log_event "Creating thinclient script"
cat <<EOL > /home/vdiuser/thinclient
#!/bin/bash

log_event "Thin client setup script started."

# Function to check if the system has a valid IP address
wait_for_ip() {
    log_event "Waiting for a valid IP address on $INET_ADAPTER..."
    echo "Waiting for a valid IP address on $INET_ADAPTER..."

    # Start a Zenity progress dialog in the background
    (
        while true; do
            # Get the IP address assigned to the specified network adapter
            IP_ADDRESS=$(ip -4 addr show "$INET_ADAPTER" | grep -oP '(?<=inet\s)\d+(\.\d+){3}')

            # Check if an IP address was found
            if [ -n "$IP_ADDRESS" ]; then
                echo "100"  # Send completion signal to Zenity
                break
            fi

            # Send a progress update to Zenity
            echo "50"  # Arbitrary progress to keep Zenity alive
            sleep 2
        done
    ) | zenity --progress --no-cancel --pulsate --text="Waiting for a valid IP address on $INET_ADAPTER..." --title="Network Initialization" --auto-close

    log_event "IP address obtained: $IP_ADDRESS"
    zenity --info --text="IP address obtained: $IP_ADDRESS" --title="Network Ready" --timeout=3
}

# Wait for IP address assignment
wait_for_ip

# Navigate to the PVE-VDIClient directory
cd ~/PVE-VDIClient || { log_event "Failed to navigate to ~/PVE-VDIClient."; exit 1; }
log_event "Navigated to ~/PVE-VDIClient."

# Run loop for thin client
while true; do
    # Start the VDI client if not already running
    if ! pgrep -f "vdiclient.py" > /dev/null; then
        log_event "Starting vdiclient.py..."
        /usr/bin/python3 ~/PVE-VDIClient/vdiclient.py &
    fi

    # Check for an active internet connection
    if ! ping -c 1 -W 2 8.8.8.8 > /dev/null; then
        log_event "Internet connection lost. Waiting to reconnect."
        wait_for_ip
    fi

    sleep 5

done
EOL
chmod +x /home/vdiuser/thinclient
log_event "Thin client script created successfully."

# Configure autostart for Thin Client
log_event "Configuring autostart for Thin Client"
mkdir -p /home/vdiuser/.config/lxsession/LXDE
echo "@/usr/bin/bash /home/vdiuser/thinclient" > /home/vdiuser/.config/lxsession/LXDE/autostart
log_event "Autostart configuration created successfully."

# Configure LightDM
log_event "Configuring LightDM for autologin"
LIGHTDM_CONF="/etc/lightdm/lightdm.conf"
echo "[Seat:*]
autologin-user=vdiuser
autologin-user-timeout=0
xserver-command=X -s 0 -dpms" > "$LIGHTDM_CONF"

log_event "LightDM configured successfully."

# Final message
log_event "Setup complete. Asking for reboot confirmation."
dialog --title "Setup Complete" --yesno "Setup complete! Do you want to reboot now?" 10 50
if [ $? -eq 0 ]; then
  log_event "User chose to reboot. Rebooting system."
  sudo reboot
else
  log_event "User chose not to reboot. Exiting script."
  dialog --title "Exit" --msgbox "You chose not to reboot. Please reboot manually later to apply changes." 10 50
fi