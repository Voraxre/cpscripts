#!/bin/bash

# CyberPatriot Hardening Script for Ubuntu/Debian-based systems
# Run as root or with sudo privileges

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration Variables
AUTHORIZED_USERS=("root" "admin")      # Add authorized users here
SSH_PORT=2222                          # New SSH port
MIN_PASSWORD_AGE=7                     # Minimum password age
MAX_PASSWORD_AGE=90                    # Maximum password age
MIN_PASSWORD_LENGTH=12                 # Minimum password length

# Ensure script is run as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}[-] Please run as root${NC}"
    exit 1
fi

# Create log file
LOG_FILE="hardening_log_$(date +%Y%m%d_%H%M%S).txt"
exec > >(tee -i "$LOG_FILE")
exec 2>&1

echo -e "${GREEN}[+] Starting System Hardening Process...${NC}"

# Section 1: System Updates
echo -e "${YELLOW}[*] Updating System...${NC}"
apt-get update -y
apt-get upgrade -y
apt-get dist-upgrade -y
apt-get install -y unattended-upgrades
dpkg-reconfigure -plow unattended-upgrades

# Section 2: User Account Management
echo -e "${YELLOW}[*] Securing User Accounts...${NC}"

# Remove unauthorized users (example list)
UNAUTHORIZED_USERS=("user1" "test" "guest")
for user in "${UNAUTHORIZED_USERS[@]}"; do
    if id "$user" &>/dev/null; then
        userdel -r "$user" 2>/dev/null
        echo -e "${RED}[-] Removed unauthorized user: $user${NC}"
    fi
done

# Secure root account
passwd -l root

# Password policies
sed -i "s/PASS_MAX_DAYS.*/PASS_MAX_DAYS   $MAX_PASSWORD_AGE/" /etc/login.defs
sed -i "s/PASS_MIN_DAYS.*/PASS_MIN_DAYS   $MIN_PASSWORD_AGE/" /etc/login.defs
sed -i "s/PASS_MIN_LEN.*/PASS_MIN_LEN    $MIN_PASSWORD_LENGTH/" /etc/login.defs

# Lock inactive accounts
useradd -D -f 30

# Section 3: SSH Hardening
echo -e "${YELLOW}[*] Securing SSH...${NC}"
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak

sed -i "s/#Port 22/Port $SSH_PORT/" /etc/ssh/sshd_config
sed -i "s/PermitRootLogin yes/PermitRootLogin no/" /etc/ssh/sshd_config
sed -i "s/#PasswordAuthentication yes/PasswordAuthentication no/" /etc/ssh/sshd_config

echo -e "AllowUsers ${AUTHORIZED_USERS[*]}" >> /etc/ssh/sshd_config
echo "Protocol 2" >> /etc/ssh/sshd_config
echo "MaxAuthTries 3" >> /etc/ssh/sshd_config
echo "ClientAliveInterval 300" >> /etc/ssh/sshd_config

systemctl restart sshd

# Section 4: Firewall Configuration
echo -e "${YELLOW}[*] Configuring UFW Firewall...${NC}"
apt-get install -y ufw
ufw default deny incoming
ufw default allow outgoing
ufw allow "$SSH_PORT/tcp"
ufw allow http
ufw allow https
ufw --force enable

# Section 5: Remove Unnecessary Services
echo -e "${YELLOW}[*] Removing Unnecessary Packages...${NC}"
UNNECESSARY_PACKAGES=("telnetd" "vsftpd" "rsh-server" "nis" "snmpd")
for pkg in "${UNNECESSARY_PACKAGES[@]}"; do
    if dpkg -s "$pkg" &>/dev/null; then
        apt-get purge -y "$pkg"
        echo -e "${RED}[-] Removed package: $pkg${NC}"
    fi
done

# Section 6: File System Permissions
echo -e "${YELLOW}[*] Securing File Permissions...${NC}"
chmod 600 /etc/shadow
chmod 644 /etc/passwd
chmod 640 /etc/group
chmod 644 /etc/hosts
chmod 750 /etc/sudoers.d

# Find and fix world-writable files
find / -xdev -type f -perm -o+w -exec chmod o-w {} +

# Disable SUID/SGID on unnecessary binaries
for binary in /usr/sbin/nologin /bin/mount /bin/umount; do
    chmod u-s "$binary"
done

# Section 7: System Auditing
echo -e "${YELLOW}[*] Setting Up Auditing...${NC}"
apt-get install -y auditd lynis
systemctl enable auditd && systemctl start auditd

# Run Lynis audit
echo -e "${GREEN}[+] Running Lynis System Audit...${NC}"
lynis audit system

echo -e "${GREEN}[+] Hardening Complete!${NC}"
echo -e "${YELLOW}[!] Please review the log file: $LOG_FILE${NC}"
echo -e "${YELLOW}[!] Reboot the system to apply all changes${NC}"%         
