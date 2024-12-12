#!/bin/bash

# Modify Thin Client Ini Config with Dialog
# Author: Jackson Baer
# Date: 27 Nov 2024

# Establish Log File
LOG_FILE="/var/log/thinclient_setup.log"

# Create Log_Event Function for log functions
log_event() {
    echo "$(date): $1" >> "$LOG_FILE"
}

# Ensure the log file exists
if [ ! -f "$LOG_FILE" ]; then
    touch "$LOG_FILE"
    log_event "Log file created."
fi

log_event "Starting Modify Thin Client script"

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
  dialog --title "Error" --msgbox "Please run as root." 10 50
  log_event "User ID is $EUID. Exiting because script was not run as root."
  exit
fi

# Collect Inputs Using Dialog
PROXMOX_IP=$(dialog --title "Proxmox IP Address" --inputbox "Enter the Proxmox IP Address:" 10 50 3>&1 1>&2 2>&3)
if [ $? -ne 0 ]; then
    log_event "User canceled input for Proxmox IP Address. Exiting."
    exec /home/vdiuser/simpledebianvdi/Installer.sh
    
fi

VDI_TITLE=$(dialog --title "Thin Client Title" --inputbox "Enter the Thin Client Title:" 10 50 3>&1 1>&2 2>&3)
if [ $? -ne 0 ]; then
    log_event "User canceled input for Thin Client Title. Exiting."
    exec /home/vdiuser/simpledebianvdi/Installer.sh
fi

VDI_AUTH=$(dialog --title "Authentication Method" --menu "Choose Authentication Method:" 15 50 2 \
"pve" "Proxmox Virtual Environment" \
"pam" "Pluggable Authentication Module" 3>&1 1>&2 2>&3)
if [ $? -ne 0 ]; then
    log_event "User canceled input for Authentication Method. Exiting."
    exec /home/vdiuser/simpledebianvdi/Installer.sh
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
