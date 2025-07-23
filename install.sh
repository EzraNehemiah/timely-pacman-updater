#!/bin/bash
set -euo pipefail

# Paths and constants
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DEST="/etc/tpu.conf"
SCRIPT_PATH="/usr/local/bin/tpu.sh"
LOG_DIR="/var/log/tpu"
SERVICE_NAME="timely-pacman-updater"
SYSTEMD_DIR="/etc/systemd/system"

# Prompt user for update frequency with default 'weekly'
prompt_update_frequency() {
    local default="weekly"
    echo -e "\e[1mChoose update frequency:\e[0m"
    echo "   1) daily"
    echo " > 2) weekly"
    echo "   3) monthly"
    while true; do
        read -rp "[1-3] (default: $default): " choice
        if [[ -z "$choice" ]]; then
            echo "Selected: $default" >&2
            echo "$default"
            return
        fi
        case "$choice" in
            1) echo "Selected: daily" >&2; echo "daily"; return ;;
            2) echo "Selected: weekly" >&2; echo "weekly"; return ;;
            3) echo "Selected: monthly" >&2; echo "monthly"; return ;;
            *) echo "Invalid choice. Select any number 1-3." >&2 ;;
        esac
    done
}

# Prompt user for log retention days with default 60
prompt_log_retention() {
    local default=60
    while true; do
        read -rp "Enter log retention time in days (default: $default): " days
        if [[ -z "$days" ]]; then
            echo "Selected: $default days" >&2
            echo "$default"
            return
        elif [[ "$days" =~ ^[1-9][0-9]*$ ]]; then
            echo "Selected: $days days" >&2
            echo "$days"
            return
        else
            echo "Please enter a positive integer." >&2
        fi
    done
}

echo -e "\n=== Timely Pacman Updater Installation ===\n"

UPDATE_FREQUENCY=$(prompt_update_frequency)
LOG_RETENTION_DAYS=$(prompt_log_retention)

echo -e "\nYou chose update frequency: $UPDATE_FREQUENCY"
echo "You chose log retention days: $LOG_RETENTION_DAYS"

# Write configuration file
echo -e "\nWriting config to $CONFIG_DEST..."
sudo tee "$CONFIG_DEST" >/dev/null <<EOF
# Timely Pacman Updater configuration
UPDATE_FREQUENCY="$UPDATE_FREQUENCY"
LOG_RETENTION_DAYS=$LOG_RETENTION_DAYS
LOG_DIR="$LOG_DIR"
EOF

# Install updater script
echo -e "\nInstalling updater script to $SCRIPT_PATH"
sudo install -m 755 "$SCRIPT_DIR/scripts/tpu.sh" "$SCRIPT_PATH"

# Create log directory
echo -e "\nCreating log directory at $LOG_DIR"
sudo mkdir -p "$LOG_DIR"
sudo chown "$USER:$USER" "$LOG_DIR"

# Create systemd service file
echo -e "\nCreating systemd service file..."
sudo tee "$SYSTEMD_DIR/$SERVICE_NAME.service" >/dev/null <<EOF
[Unit]
Description=Timely Pacman System Update

[Service]
Type=oneshot
ExecStart=$SCRIPT_PATH
EOF

# Determine systemd timer OnCalendar based on update frequency
case "$UPDATE_FREQUENCY" in
    daily) ON_CALENDAR="daily" ;;
    weekly) ON_CALENDAR="weekly" ;;
    monthly) ON_CALENDAR="monthly" ;;
    *)
        echo "Unexpected update frequency value: $UPDATE_FREQUENCY"
        exit 1
        ;;
esac

# Create systemd timer file
echo -e "\nCreating systemd timer file..."
sudo tee "$SYSTEMD_DIR/$SERVICE_NAME.timer" >/dev/null <<EOF
[Unit]
Description=Timer for Timely Pacman System Update

[Timer]
OnCalendar=$ON_CALENDAR
Persistent=true

[Install]
WantedBy=timers.target
EOF

# Enable and start timer
echo -e "\nReloading systemd and enabling timer..."
sudo systemctl daemon-reload
sudo systemctl enable --now "$SERVICE_NAME.timer"

echo -e "\nInstallation complete!"
echo "Update frequency: $UPDATE_FREQUENCY"
echo "Log retention: $LOG_RETENTION_DAYS days"
echo "Logs saved in $LOG_DIR"
