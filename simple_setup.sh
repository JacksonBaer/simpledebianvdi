#!/bin/bash
# Function to display usage
usage() {
    echo "Usage: $0 -i PROXMOX_IP -t VDI_TITLE -a AUTH_METHOD"
    echo "Options:"
    echo "  -i PROXMOX_IP         Proxmox IP or DNS"
    echo "  -t VDI_TITLE          Thin Client Title"
    echo "  -a AUTH_METHOD        Authentication method (pve or pam)"
    exit 1
}

# Parse command-line arguments
while getopts ":i:t:a:" opt; do
    case $opt in
        i) PROXMOX_IP=$OPTARG ;;
        t) VDI_TITLE=$OPTARG ;;
        a) VDI_AUTH=$OPTARG ;;
        *) usage ;;
    esac
done

# Validate arguments
if [ -z "$PROXMOX_IP" ] || [ -z "$VDI_TITLE" ] || [ -z "$VDI_AUTH" ]; then
    echo "Missing required arguments."
    usage
fi

# Ensure valid authentication type
if [[ "$VDI_AUTH" != "pve" && "$VDI_AUTH" != "pam" ]]; then
    echo "Invalid authentication type. Must be 'pve' or 'pam'."
    usage
fi

# Log file setup
LOG_FILE="/var/log/thinclient_setup.log"

log_event() {
    echo "$(date) [$(hostname)] [User: $(whoami)]: $1" >> "$LOG_FILE"
}

if [ ! -f "$LOG_FILE" ]; then
    touch "$LOG_FILE"
    log_event "Log file created."
fi

log_event "Starting Thin Client Setup script"
log_event "Proxmox IP: $PROXMOX_IP"
log_event "VDI Title: $VDI_TITLE"
log_event "Auth Method: $VDI_AUTH"


# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    log_event "Script exited: not run as root"
    exit 1
fi

# Update and upgrade system
echo "Updating and upgrading system packages..."
log_event "Updating and upgrading system packages"
sudo apt update && sudo apt upgrade -y

# Install required packages
log_event "Installing required dependencies..."
#Install Apt Packages:
sudo apt install virt-viewer lightdm zenity feh lightdm-gtk-greeter dialog sshpass curl python3-tk -y
sudo apt install python3-pip -y
sudo apt install python3-tk -y
pip3 install proxmoxer requests FreeSimpleGUI
# Clone the repository and configure the thin client
log_event "Cloning repository and configuring thin client"
cd /home/vdiuser || exit
git clone https://github.com/joshpatten/PVE-VDIClient.git
cd PVE-VDIClient || { echo "Failed to navigate to PVE-VDIClient"; log_event "Failed to navigate to PVE-VDIClient"; exit 1; }
sed -i '3s|.*|import FreeSimpleGUI as sg # pip install FreeSimpleGUI|' vdiclient.py


chmod +x vdiclient.py
sudo mkdir -p /etc/vdiclient
sudo tee /etc/vdiclient/vdiclient.ini > /dev/null <<EOL
[General]
title = $VDI_TITLE
icon = vdiicon.ico
logo = vdilogo.png
kiosk = false
theme = BrightColors

[Authentication]
auth_backend = $VDI_AUTH
auth_totp = false
tls_verify = false

[Hosts]
$PROXMOX_IP=8006
EOL

# Add the required line to the user's autostart file
echo "@/usr/bin/bash /home/vdiuser/thinclient" > /home/vdiuser/.config/lxsession/LXDE/autostart

log_event "'$cat /home/vdiuser/.config/lxsession/LXDE/autostart'"
# Configure thin client
echo "Configuring thin client script..."
cat <<EOL > /home/vdiuser/thinclient
#!/bin/bash
sleep 1
clear
feh --bg-fill /home/vdiuser/simpledebianvdi/BG.png
openbox --exit
cd /home/vdiuser/PVE-VDIClient

while true; do
    if grep -q "Lockdown" /home/vdiuser/status; then
        pkill python
        xsetroot -solid red
        while grep -q "Lockdown" /home/vdiuser/status; do
            zenity --error --text "System is in lockdown mode. Please contact your administrator." \
                --width=400 \
                --height=400 &
            
            while grep -q "Lockdown" /home/vdiuser/status; do
                sleep 2  # Prevent excessive CPU usage
            done
            pkill zenity
        done
    fi
    /usr/bin/python3 vdiclient.py
done
EOL


chmod +x /home/vdiuser/thinclient
echo "Green" > /home/vdiuser/status
# Configure LightDM for autologin
echo "Configuring LightDM for autologin..."
sudo tee /etc/lightdm/lightdm.conf > /dev/null <<EOL
[Seat:*]
autologin-user=vdiuser
autologin-user-timeout=0
xserver-command=X -s 0 -dpms
EOL

log_event "Thin Client setup completed successfully"

