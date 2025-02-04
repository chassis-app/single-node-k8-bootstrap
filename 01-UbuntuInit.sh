# 1. Perform system updates and upgrades
echo "Updating and upgrading system packages..."
sudo apt update -y && sudo apt upgrade -y

# 2. Create new user and add to sudo group (CHECK FOR EXISTING USER)
if ! id -u user >/dev/null 2>&1; then  # Check if user exists
  echo "Creating 'user' account..."
  sudo adduser --disabled-password --gecos "" user
  echo "user:dev123123!" | sudo chpasswd
  sudo usermod -aG sudo user

else
  echo "User 'user' already exists. Skipping user creation."
fi

# 3. Configure SSH key for new user
read -r -p "Paste your SSH public key for user 'user': " ssh_key

# Get the user's home directory
user_home=$(getent passwd user | cut -d: -f6)

# Create the .ssh directory and authorized_keys file as the user
sudo -u user mkdir -p "$user_home/.ssh"
sudo -u user sh -c "echo \"$ssh_key\" | tee \"$user_home/.ssh/authorized_keys\" >/dev/null"
sudo -u user chmod 700 "$user_home/.ssh"
sudo -u user chmod 600 "$user_home/.ssh/authorized_keys"

# 4. Harden SSH configuration (Still needs sudo)
echo "Configuring SSH security..."
sudo sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sudo sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo systemctl restart ssh
