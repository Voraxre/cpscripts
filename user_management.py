import subprocess
import re

# Regular expression for insecure passwords
insecure_regex = r"^(abc|123|password|qwerty)$"

def check_insecure(password):
    """Check if password is insecure using regular expressions"""
    return bool(re.match(insecure_regex, password))

def manage_users(admin_mode=False):
    # Read users from file
    with open("users.in", "r") as f:
        lines = [line.strip() for line in f.readlines()]

    admin_start_index = None
    user_list = []

    # Identify the type of each account (admin/user)
    for i, line in enumerate(lines):
        if line == "ADMIN":
            admin_start_index = i + 1
        elif line == "USER" and admin_mode:
            break

    if admin_mode:
        return lines[admin_start_index:]

    for line in lines[admin_start_index:]:
        if line != "USER":
            user_list.append(line)

    current_user = input("Enter your username: ")
    current_password = input(f"Enter the password of {current_user}: ")

    insecure_users = []
    to_delete_users = []

    for i, user in enumerate(user_list):
        if not check_insecure(user[3]):  # Check password
            continue

        insecure_users.append(i)

        to_delete_users.append(i)

    # Remove all users that aren't on the list
    for i in set(range(len(user_list))).difference(set(to_delete_users)):
        subprocess.run(f"userdel -r {user_list[i][0]}", shell=True)

    # If any insecure passwords were found, remove them (except current user's)
    if insecure_users:
        for i in set(insecure_users) - {i for user in user_list if user[0] == current_user[0]}:
            subprocess.run(f"userdel -r {user_list[i][0]}", shell=True)

    print("User management complete.")

if __name__ == "__main__":
    admin_mode = input("Is this an admin mode (yes/no)? ").lower() == "yes"
    manage_users(admin_mode)
