#!/bin/bash

# Thin Client Setup Script with Dialog
# Author: Jackson Baer
# Date: 27 Nov 2024

# Establish Log File
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
  dialog --title "Error" --msgbox "Please run as root." 10 50
  log_event "User ID is $EUID. Exiting because script was not run as root."
  exit
fi

# Function to run commands with logging and progress bar
gauge_command() {
    local CMD="$1"
    local MSG="$2"
    log_event "Running: $CMD"
    {
        echo "10"; sleep 1
        bash -c "$CMD" >> "$INSTALL_LOG" 2>&1 && echo "100"
    } | dialog --title "Progress" --gauge "$MSG" 10 70 0

    if [ $? -ne 0 ]; then
        log_event "Command failed: $CMD"
        dialog --title "Error" --msgbox "An error occurred while running: $CMD. Check logs for details." 10 50
        exit 1
    fi
}

# Install Required Packages
gauge_command "sudo apt update && sudo apt upgrade -y" "Updating and upgrading system packages"
gauge_command "sudo apt install python3-pip virt-viewer lightdm zenity lightdm-gtk-greeter -y" "Installing dependencies"
gauge_command "sudo apt install python3-tk -y" "Installing Python 3 Tkinter"
gauge_command "pip3 install proxmoxer 'PySimpleGUI<5.0.0'" "Installing Python packages"

# Collect Inputs Using Dialog
PROXMOX_IP=$(dialog --title "Proxmox IP Address" --inputbox "Enter the Proxmox IP Address:" 10 50 3>&1 1>&2 2>&3)
if [ $? -ne 0 ]; then
    log_event "User canceled input for Proxmox IP Address. Exiting."
    exit 1
fi

VDI_TITLE=$(dialog --title "Thin Client Title" --inputbox "Enter the Thin Client Title:" 10 50 3>&1 1>&2 2>&3)
if [ $? -ne 0 ]; then
    log_event "User canceled input for Thin Client Title. Exiting."
    exit 1
fi

VDI_AUTH=$(dialog --title "Authentication Method" --menu "Choose Authentication Method:" 15 50 2 \
"pve" "Proxmox Virtual Environment" \
"pam" "Pluggable Authentication Module" 3>&1 1>&2 2>&3)
if [ $? -ne 0 ]; then
    log_event "User canceled input for Authentication Method. Exiting."
    exit 1
fi

VDI_THEME=$(dialog --title "Theme" --menu "Choose a Theme:" 15 50 10 \
"Black" "Black Theme" \
"BlueMono" "Blue Mono Theme" \
"BluePurple" "Blue Purple Theme" \
"BrightColors" "Bright Colors Theme" \
"BrownBlue" "Brown Blue Theme" \
"Dark" "Dark Theme" \
"Dark2" "Dark Theme 2" \
"DarkAmber" "Dark Amber Theme" \
"DarkBlack" "Dark Black Theme" \
"DarkBlue" "Dark Blue Theme" \
"DarkGreen" "Dark Green Theme" \
"LightBlue" "Light Blue Theme" \
"LightGrey" "Light Grey Theme" \
"Material1" "Material Theme 1" \
"NeutralBlue" "Neutral Blue Theme" \
"Purple" "Purple Theme" \
"Reddit" "Reddit Theme" \
"TanBlue" "Tan Blue Theme" \
"TealMono" "Teal Mono Theme" 3>&1 1>&2 2>&3)
if [ $? -ne 0 ]; then
    log_event "User canceled input for Theme. Exiting."
    exit 1
fi

log_event "Proxmox IP Address: $PROXMOX_IP, Thin Client Title: $VDI_TITLE, Authentication Method: $VDI_AUTH, Theme: $VDI_THEME"

# Modify the configuration directory and file
dialog --title "Modifying Configuration" --infobox "Updating configuration file..." 10 50
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

log_event "Configuration file updated with theme: $VDI_THEME"

# Clone the repository
gauge_command "git clone https://github.com/joshpatten/PVE-VDIClient.git /home/vdiuser/PVE-VDIClient" "Cloning PVE-VDIClient repository"
if [ ! -d "/home/vdiuser/PVE-VDIClient" ]; then
  log_event "Failed to clone PVE-VDIClient repository. Exiting script."
  dialog --title "Error" --msgbox "Failed to clone PVE-VDIClient repository. Check logs for details." 10 50
  exit 1
fi

# Create the thinclient script
log_event "Creating thinclient script"
cat <<EOL > /home/vdiuser/thinclient
#!/bin/bash

log_event "Thin client setup script started."

# Navigate to the PVE-VDIClient directory
cd ~/PVE-VDIClient || { log_event "Failed to navigate to ~/PVE-VDIClient."; exit 1; }

# Run loop for thin client
while true; do
    /usr/bin/python3 ~/PVE-VDIClient/vdiclient.py
    sleep 2
done
EOL
chmod +x /home/vdiuser/thinclient
log_event "Thinclient script created successfully."

# Handle Auto-Restart Logic
AUTO_RESTART=$(dialog --title "Restart Confirmation" --menu "Do you want to restart the system now?" 15 50 2 \
"yes" "Restart now" \
"no" "Restart later" 3>&1 1>&2 2>&3)

if [ "$AUTO_RESTART" == "yes" ]; then
    dialog --title "Restarting" --infobox "Restarting the system..." 10 50
    log_event "System reboot initiated via dialog."
    sudo reboot
elif [ "$AUTO_RESTART" == "no" ]; then
    dialog --title "Restart Skipped" --msgbox "Please reboot the system manually to apply changes." 10 50
    log_event "System reboot skipped via dialog."
fi
