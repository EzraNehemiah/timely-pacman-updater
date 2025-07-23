#!/bin/bash
set -euo pipefail

CONFIG_FILE="/etc/tpu.conf"

# Load config
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Config file not found at $CONFIG_FILE. Exiting."
    exit 1
fi

# shellcheck source=/dev/null
source "$CONFIG_FILE"

# Prepare log directory and file
mkdir -p "$LOG_DIR"
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
LOG_FILE="$LOG_DIR/update-$TIMESTAMP.log"

# Run the update and log output
echo "Starting pacman update at $(date)" | tee -a "$LOG_FILE"
if sudo pacman -Syu --noconfirm 2>&1 | tee -a "$LOG_FILE"; then
    echo "Update completed successfully at $(date)" | tee -a "$LOG_FILE"
else
    echo "Update encountered errors at $(date)" | tee -a "$LOG_FILE"
fi

# Delete old logs based on retention period
echo "Cleaning logs older than $LOG_RETENTION_DAYS days..." | tee -a "$LOG_FILE"
find "$LOG_DIR" -type f -name "update-*.log" -mtime +"$LOG_RETENTION_DAYS" -exec rm -f {} \;

echo "Done."
