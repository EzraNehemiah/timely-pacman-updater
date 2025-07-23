#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DEST="/etc/tpu.conf"
SCRIPT_PATH="/usr/local/bin/tpu.sh"
LOG_DIR="/var/log/tpu"
SERVICE_NAME="timely-pacman-updater"
SYSTEMD_DIR="/etc/systemd/system"

# Global variables to hold user inputs
UPDATE_FREQUENCY=""
LOG_RETENTION_DAYS=""

# Prompt for update frequency
prompt_update_frequency() {
    local choice default="weekly"
    echo -e "\e[1mChoose update frequency:\e[0m"
    echo "   1) daily"
    echo " > 2) weekly"
    echo "   3) monthly"
    while true; do
        read -rp "(1-3): " choice
        case "$choice" in
            "") UPDATE_FREQUENCY="$default"; return ;;
            1) UPDATE_FREQUENCY="daily"; return ;;
            2) UPDATE_FREQUENCY="weekly"; return ;;
            3) UPDATE_FREQUENCY="monthly"; return ;;
            *) echo "Invalid choice. Select a number between 1 and 3." ;;
        esac
    done
}

# Prompt for log retention days
prompt_log_retention() {
    local days default=60
    while true; do
        read -rp "Enter log retention time in days (default: $default): " days
        if [[ -z "$days" ]]; then
            LOG_RETENTION_DAYS="$default"
            return
        elif [[ "$days" =~ ^[1-9][0-9]*$ ]]; then
            LOG_RETENTION_DAYS="$days"
            return
        else
            echo "Please enter a positive integer."
        fi
    done
}

echo -e "\n=== Timely Pacman Updater Installation ===\n"

# Collect user input
prompt_update_frequency
prompt_log_retention

echo -e "\nYou chose update frequency: $UPDATE_FREQUENCY"
echo "You chose log retention days: $LOG_RETENTION_DAYS"

# Write config file
echo -e "\nWriting config to $CONFIG_DEST..."
sudo tee "$CONFIG_DEST" >/dev/null <<EOF
# Timely Pacman Updater configuration
LOG_RETENTION_DAYS=$LOG_RETENTION_DAYS
LOG_DIR="$LOG_DIR"
EOF

# Install the script
echo -e "\nInstalling updater script to $SCRIPT_PATH"
sudo install -m 755 "$SCRIPT_DIR/scripts/tpu.sh" "$SCRIPT_PATH"

# Create log directory
echo -e "\nCreating log directory at $LOG_DIR"
sudo mkdir -p "$LOG_DIR"
sudo chown "$USER:$USER" "$LOG_DIR"

# Create systemd service
echo -e "\nCreating systemd service file..."
sudo tee "$SYSTEMD_DIR/$SERVICE_NAME.service" >/dev/null <<EOF
[Unit]
Description=Timely Pacman System Update

[Service]
Type=oneshot
ExecStart=$SCRIPT_PATH
EOF

# Map frequency to systemd OnCalendar
case "$UPDATE_FREQUENCY" in
    daily) ON_CALENDAR="daily" ;;
    weekly) ON_CALENDAR="weekly" ;;
    monthly) ON_CALENDAR="monthly" ;;
    *) echo "Unexpected frequency value!"; exit 1 ;;
esac

# Create systemd timer
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

# Enable and start the timer
echo -e "\nReloading systemd daemon and enabling timer..."
sudo systemctl daemon-reload
sudo systemctl enable --now "$SERVICE_NAME.timer"

# Prompt user about passwordless sudo for pacman
echo -e "\n\e[1mIMPORTANT:\e[0m To allow the updater to run 'pacman -Syu' without asking for your sudo password,"
echo -e "the installer can create a sudoers rule for your user."
echo -e "\e[1mIt is \e[4mstrongly recommended\e[0m to add this rule \e[1mmanually\e[0m for security reasons."
echo "If you want to automate this step, choose 'y'. Otherwise, choose 'N' to skip."

read -rp "Add sudoers rule for passwordless pacman updates? (y/N): " add_sudoers

if [[ "$add_sudoers" == [Yy] ]]; then
    SUDOERS_FILE="/etc/sudoers.d/timely-pacman-updater"
    SUDOERS_RULE="$USER ALL=(ALL) NOPASSWD: /usr/bin/pacman -Syu --noconfirm"
    
    echo -e "\nCreating sudoers file at $SUDOERS_FILE..."
    echo "$SUDOERS_RULE" | sudo tee "$SUDOERS_FILE" >/dev/null
    sudo chmod 440 "$SUDOERS_FILE"
    
    # Validate sudoers syntax
    if sudo visudo -cf "$SUDOERS_FILE"; then
        echo "Sudoers file syntax is valid."
    else
        echo -e "\e[31mWARNING: Sudoers file syntax is INVALID! Removing $SUDOERS_FILE...\e[0m"
        sudo rm -f "$SUDOERS_FILE"
        echo "Skipping sudoers file creation. You will need to add the sudoers rule manually."
        echo "See the README for instructions on how to safely add the rule using visudo."
    fi
else
    echo "Skipping sudoers file creation. You will need to add the sudoers rule manually."
    echo "See the README for instructions on how to safely add the rule using visudo."
fi

echo -e "\nInstallation complete."
echo "Update frequency: $UPDATE_FREQUENCY"
echo "Log retention: $LOG_RETENTION_DAYS days"
echo "Logs saved in $LOG_DIR"
