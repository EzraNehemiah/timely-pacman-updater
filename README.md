# Timely Pacman Updater

A lightweight Arch Linux system update automation script that runs via systemd timers. It updates your system (`pacman -Syu`), logs the output, and cleans up old logs automatically.

---

## Features

- Configurable update frequency: daily, weekly, or monthly
- Automatic systemd timer setup
- Logs saved with timestamps for easy debugging
- Old logs cleaned up based on configurable retention period
- Optional sudoers rule for passwordless `pacman -Syu` updates
- Simple install script to set everything up

---

## Table of Contents

- [Installation](#installation)
- [Configuration](#configuration)
- [Usage](#usage)
- [Log Files](#log-files)
- [Passwordless sudo](#passwordless-sudo)
- [Uninstall](#uninstall)
- [License](#license)

---

## Installation

1. Clone the repository and run the installer:

```bash
git clone https://github.com/EzraNehemiah/timely-pacman-updater.git
cd timely-pacman-updater
./install.sh
```
2. During installation, you will be prompted to:

   - Choose the update frequency (daily, weekly, monthly; default is **weekly**)
   - Set log retention days (default is **60** days)
   - Optionally enable a passwordless sudo rule for running `pacman -Syu` without a password (**strongly recommended to add this manually, but can be automated**)

3. The installer will:

   - Install the updater script to `/usr/local/bin/tpu.sh`
   - Create `/etc/tpu.conf` with your chosen settings
   - Setup systemd service and timer to run updates automatically
   - Create a log directory at `/var/log/tpu`
   - (Optionally) Create a sudoers file to allow passwordless updates

---

## Configuration

The main configuration file is located at: `/etc/tpu.conf`. It contains:

```bash
LOG_RETENTION_DAYS=60          # Number of days to keep logs
LOG_DIR="/var/log/tpu"         # Directory where logs are saved
```

---

## Usage

 - The updater script is installed as `/usr/local/bin/tpu.sh`.
 - It is triggered automatically by systemd timers at your chosen frequency.
 - To run manually:

```bash
sudo /usr/local/bin/tpu.sh
```

---

## Log Files

 - Logs are saved in `/var/log/tpu/` with filenames like `update-YYYMMDD-HHMMSS.log`.
 - Logs older than the retention period (`LOG_RETENTION_DAYS) are deleted automatically after each update.
 - Check these logs to troubleshoot any update issues.

---

## Passwordless sudo
**(Optional but Recommended)**

To allow the updater script to run `pacman -Syu` without prompting for your sudo password, you can add a sudoers rule.

The installer **can add this automatically**, but it is **strongly recommended to add it manually** for security.

Manual method:
  1. Open sudoers safely with `visudo`:

```bash
sudo visudo -f /etc/sudoers.d/timely-pacman-updater
# Set the EDITOR using EDITOR=nano or vim or nvim etc if you must
```
  2. Add this line (replace `yourusername` with your actual username):

```sql
yourusername ALL=(ALL) NOPASSWD: /usr/bin/pacman -Syu --noconfirm
```
  3. Save and exit.

The installer's automatic method creates `/etc/sudoers.d/timerly-pacman-updater` with the above line and validates its syntax.

---

## Uninstall

To remove the updater and timer

```bash
sudo systemctl disable --now timely-pacman-updater.timer
sudo rm /etc/systemd/system/timely-pacman-updater.timer
sudo rm /etc/systemd/system/timely-pacman-updater.service
sudo rm /usr/local/bin/tpu.sh
sudo rm /etc/tpu.conf
sudo rm -r /var/log/tpu
sudo rm /etc/sudoers.d/timely-pacman-updater   # If you enabled the sudoers rule
sudo systemctl daemon-reload
```

---

## License

This project is licensed under the GNU General Public License v3.0 (GPL-3.0). See LICENSE for details.
