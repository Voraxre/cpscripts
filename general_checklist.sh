#!/bin/bash

# Ensure the script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "Please run this script as root."
    exit 1
fi

echo "Starting Ubuntu system hardening..."

# Remove unauthorized users
echo "Removing unauthorized users..."
awk -F: '$3 >= 1000 {print $1}' /etc/passwd | grep -v "your_user" | while read -r user; do
    echo "Removing user: $user"
    userdel -r "$user"
done

# Check admin users
echo "Checking admin users..."
getent group sudo | cut -d: -f4

# Configure firewall (reject incoming, allow outgoing)
echo "Configuring UFW firewall..."
ufw default deny incoming
ufw default allow outgoing
ufw enable

# Enforce strong password policy
echo "Enforcing password policy..."
apt-get install -y libpam-cracklib
sed -i '/pam_unix.so/ s/$/ remember=5 minlen=8/' /etc/pam.d/common-password
sed -i '/pam_cracklib.so/ s/$/ ucredit=-1 lcredit=-1 dcredit=-1 ocredit=-1/' /etc/pam.d/common-password

# Set password aging
echo "Configuring password aging..."
sed -i 's/^PASS_MAX_DAYS.*/PASS_MAX_DAYS   90/' /etc/login.defs
sed -i 's/^PASS_MIN_DAYS.*/PASS_MIN_DAYS   10/' /etc/login.defs
sed -i 's/^PASS_WARN_AGE.*/PASS_WARN_AGE   7/' /etc/login.defs

# Configure failed login attempts
echo "Configuring failed login attempts..."
echo "auth required pam_tally2.so deny=5 onerr=fail unlock_time=1800" >> /etc/pam.d/common-auth

# Remove guest account
echo "Removing guest account..."
if [ -f /etc/lightdm/lightdm.conf ]; then
    echo "allow-guest=false" >> /etc/lightdm/lightdm.conf
elif [ -f /etc/lightdm/users.conf ]; then
    echo "allow-guest=false" >> /etc/lightdm/users.conf
fi

# Disable FTP services if installed
echo "Disabling FTP services if found..."
for service in vsftpd pure-ftpd; do
    if systemctl is-active --quiet $service; then
        echo "Disabling and stopping $service..."
        systemctl stop $service
        systemctl disable $service
        apt-get remove --purge -y $service
    fi
done

# Enable automatic updates
echo "Enabling automatic updates..."
apt-get install -y unattended-upgrades
dpkg-reconfigure -plow unattended-upgrades

# Remove prohibited software and files
echo "Removing prohibited software and files..."
apt-get remove --purge -y zenmap nmap
find / -iname '*.mp3' -exec rm -f {} \;
