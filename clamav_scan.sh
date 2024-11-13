#!/bin/bash

# Ensure the script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "Please run this script as root."
    exit 1
fi

echo "Starting ClamAV installation and scan..."

# Install ClamAV
echo "Installing ClamAV..."
apt-get update
apt-get install -y clamav

# Update ClamAV database
echo "Updating ClamAV database..."
freshclam

# Run a full system scan
echo "Running ClamAV scan (this may take some time)..."
clamscan --recursive / --log=/var/log/clamav_scan.log

echo "ClamAV scan complete. Results are saved in /var/log/clamav_scan.log"

