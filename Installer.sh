#!/bin/bash

# Installer Script with Menu to Run Specific Tasks
# Author: Jackson Baer
# Date: 27 Nov 2024

# Ensure dialog is installed
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

# Variable to store the selected option
SELECTED=0

# Menu to select which script to run
OPTION=$(dialog --title "Installer Menu" --menu "Choose a task to perform:" 15 50 4 \
1 "Run Setup Script" \
2 "Run Modify Script" \
3 "Run Service Script" \
4 "Exit" 3>&1 1>&2 2>&3)

# Check if user canceled
if [ $? -ne 0 ]; then
    clear
    echo "User canceled the installer."
    exit 1
fi

# Set the SELECTED variable based on the user's choice
case $OPTION in
    1)
        SELECTED=1
        ;;
    2)
        SELECTED=2
        ;;
    3)
        SELECTED=3
        ;;
    4)
        echo "Exiting the installer."
        clear
        exit 0
        ;;
    *)
        echo "Invalid option selected. Exiting."
        clear
        exit 1
        ;;
esac

# Run the corresponding script based on the SELECTED value
if [ $SELECTED -eq 1 ]; then
    exec /home/vdiuser/simpldebianvdi/scripts/setup.sh
elif [ $SELECTED -eq 2 ]; then
    exec /home/vdiuser/simpldebianvdi/scripts/modify.sh
elif [ $SELECTED -eq 3 ]; then
    exec /home/vdiuser/simpldebianvdi/scripts/service.sh
fi

# Final message
clear
echo "The selected task has completed successfully!"
