#!/usr/bin/env python3

import subprocess
import getpass
import sys

def parse_users_file(filename):
    admins = []
    users = []
    current_section = None
    with open(filename, 'r') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            if line.startswith('[') and line.endswith(']'):
                current_section = line[1:-1].lower()
            elif current_section in ('admins', 'users') and ':' in line:
                username, password = line.split(':', 1)
                username = username.strip()
                password = password.strip()
                if current_section == 'admins':
                    admins.append((username, password))
                elif current_section == 'users':
                    users.append((username, password))
    
    all_usernames = [u[0] for u in admins] + [u[0] for u in users]
    duplicates = set([u for u in all_usernames if all_usernames.count(u) > 1])
    if duplicates:
        print(f"Error: Users {duplicates} present in both admins and users.")
        sys.exit(1)
    return admins, users

def user_exists(username):
    try:
        subprocess.check_output(['id', username], stderr=subprocess.DEVNULL)
        return True
    except subprocess.CalledProcessError:
        return False

def is_in_sudo(username):
    try:
        groups = subprocess.check_output(['groups', username], stderr=subprocess.DEVNULL).decode().split()
        return 'sudo' in groups
    except subprocess.CalledProcessError:
        return False

def create_user(username):
    subprocess.run(['useradd', '-m', username], check=True)

def manage_sudo(username, should_have_sudo):
    current_status = is_in_sudo(username)
    if should_have_sudo and not current_status:
        subprocess.run(['usermod', '-aG', 'sudo', username], check=True)
    elif not should_have_sudo and current_status:
        subprocess.run(['gpasswd', '-d', username, 'sudo'], check=True)

def is_password_secure(password):
    if len(password) < 8:
        return False
    if not any(c.isupper() for c in password):
        return False
    if not any(c.islower() for c in password):
        return False
    if not any(c.isdigit() for c in password):
        return False
    if not any(c in '!@#$%^&*()_+-=[]{}|;:,.<>?/' for c in password):
        return False
    return True

def set_password(username, password):
    subprocess.run(['chpasswd'], input=f"{username}:{password}", encoding='utf-8', check=True)

def handle_password(username, initial_password):
    if not is_password_secure(initial_password):
        print(f"Password for {username} is insecure.")
        while True:
            new_pass = getpass.getpass(f"Enter new password for {username}: ")
            if is_password_secure(new_pass):
                set_password(username, new_pass)
                break
            print("Password must have: 8+ chars, uppercase, lowercase, digit, and special character.")
    else:
        set_password(username, initial_password)

def main():
    try:
        admins, regular_users = parse_users_file('users.in')
        
        # Process administrators
        for user, passwd in admins:
            if not user_exists(user):
                create_user(user)
            manage_sudo(user, should_have_sudo=True)
            handle_password(user, passwd)
        
        # Process regular users
        for user, passwd in regular_users:
            if not user_exists(user):
                create_user(user)
            manage_sudo(user, should_have_sudo=False)
            handle_password(user, passwd)
        
        print("User configuration completed successfully.")
        
    except subprocess.CalledProcessError as e:
        print(f"Error executing command: {e}")
        sys.exit(1)
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
