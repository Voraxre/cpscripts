#!/bin/bash
echo "Configuring password policies..."

# Configure PAM password requirements
sudo sed -i '/pam_unix.so/s/$/ remember=5 minlen=8/' /etc/pam.d/common-password
sudo sed -i '/pam_cracklib.so/s/$/ ucredit=-1 lcredit=-1 dcredit=-1 ocredit=-1/' /etc/pam.d/common-password

# Configure login attempt limits
echo "auth required pam_tally2.so deny=5 onerr=fail unlock_time=1800" | sudo tee -a /etc/pam.d/common-auth

# Configure password aging
sudo sed -i 's/PASS_MAX_DAYS.*/PASS_MAX_DAYS   90/' /etc/login.defs
sudo sed -i 's/PASS_MIN_DAYS.*/PASS_MIN_DAYS   10/' /etc/login.defs
sudo sed -i 's/PASS_WARN_AGE.*/PASS_WARN_AGE   7/' /etc/login.defs

echo "Password policy configuration completed."
