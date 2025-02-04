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
