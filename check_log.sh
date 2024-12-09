LOG_FILE=~/log/client.log

# Ensure the log file exists
if [ ! -f "$LOG_FILE" ]; then
    echo "Log file does not exist: $LOG_FILE"
    exit 1
fi

# Monitor the log file for changes
echo "Monitoring log file: $LOG_FILE"
last_line=""

while true; do
    # Read the last line of the log file
    new_line=$(tail -n 1 "$LOG_FILE")

    # If the last line is different, print it
    if [ "$new_line" != "$last_line" ]; then
        echo "$new_line"
        last_line="$new_line"
    fi

    # Sleep for a short duration to reduce CPU usage
    sleep 1
done