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

log_event "Starting Modify Thin Client  script"


# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  log_event "User ID is $EUID. Exiting if not root."
  exit
fi

#!/bin/bash

# Check input arguments
if [ "$1" == "on" ]; then
    ENABLE_OPENBOX_EXIT=true
elif [ "$1" == "-off" ]; then
    ENABLE_OPENBOX_EXIT=false
else
    echo "Usage: $0 -allow | -disallow"
    exit 1
fi

echo "Creating thinclient script..."
log_event "Modifying thinclient script"

cat <<EOL > /home/vdiuser/thinclient
#!/bin/bash
sleep 1

# Check if ENABLE_OPENBOX_EXIT is true, then run openbox --exit
if [ "$ENABLE_OPENBOX_EXIT" = "true" ]; then
    /usr/bin/openbox --exit
fi

# Navigate to the PVE-VDIClient directory
cd ~/PVE-VDIClient

# Run loop for thin client to prevent user closure
while true; do
    /usr/bin/python3 ~/PVE-VDIClient/vdiclient.py
done
EOL