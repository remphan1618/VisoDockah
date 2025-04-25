#!/bin/bash
set -e # Keep set -e so script exits on error unless explicitly handled

# PROVISION SCRIPT FOR VAST.AI TEMPLATE
# ====================================
# COPY THIS ENTIRE SCRIPT INTO THE "PROVISION SCRIPT" FIELD IN VAST.AI
# This runs ONCE when creating the template and sets up everything

echo "Running comprehensive provisioning script..."

# Fix APT sources to ensure consistent package versions
echo "Fixing package repositories for consistent dependency versions..."
# It's generally better to manage sources in the Dockerfile if possible,
# but keeping this as it was in your original script.
cp /etc/apt/sources.list /etc/apt/sources.list.bak || true
cat > /etc/apt/sources.list << 'EOL'
deb http://archive.ubuntu.com/ubuntu/ jammy main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ jammy-updates main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ jammy-security main restricted universe multiverse
EOL

# Clean APT cache and update with fixed repositories
apt-get clean
apt-get update

# Install packages with correct version dependencies
echo "Installing packages with correct version dependencies..."
# Removing || true so installation errors are visible!
# Note: Version pinning can still cause issues if versions conflict or are unavailable.
# Consider if you truly need these *exact* versions vs. letting apt resolve.
apt-get install -y --allow-downgrades libcurl4=7.81.0-1ubuntu1.16
apt-get install -y --allow-downgrades openssh-client=1:8.9p1-3ubuntu0.10
apt-get install -y --allow-downgrades openssh-sftp-server
apt-get install -y --allow-downgrades openssh-server curl
apt-get install -y rsync wget git tmux less locales sudo software-properties-common

# Set up SSH server properly
mkdir -p /etc/ssh
cat > /etc/ssh/sshd_config << 'EOL'
Port 22
PermitRootLogin yes
StrictModes no
ClientAliveInterval 10
ClientAliveCountMax 2
UsePAM no
PasswordAuthentication no # Using PubkeyAuthentication, ensure you have keys set up
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys # Make sure keys are in /root/.ssh or similar for root
ChallengeResponseAuthentication no
LogLevel VERBOSE
EOL

# Create required directories
mkdir -p /var/run/sshd
chmod 0755 /var/run/sshd

# Create log directory
mkdir -p /var/log

# Make sure everything in the VisoMaster directory is set up correctly
cd /workspace/VisoMaster

# Pre-install TensorRT to speed up container startup
echo "Installing TensorRT packages..."
# Removing || echo so installation errors are visible!
pip install --no-cache-dir tensorrt==10.6.0 --extra-index-url https://pypi.nvidia.com

# Download models (doing this during provisioning saves time during container startup)
echo "Downloading models..."
# Assuming download_models.py exists and works
python download_models.py

# Set proper permissions for the model directory
chmod -R 755 model_assets

# Create a script that will handle GitHub script download
# This part seems overly complex. Why download onstart.sh *again* at runtime from GitHub?
# If onstart.sh contains critical runtime logic, consider including it in the Docker image directly.
# Keeping this as is, but note the complexity.
cat > /workspace/run_github_script.sh << 'EOL'
#!/bin/bash
# Download and execute custom script from GitHub
echo "Downloading custom script from GitHub..."
GITHUB_SCRIPT_URL="https://raw.githubusercontent.com/remphan1618/VisoDockah/refs/heads/main/onstart.sh" # Assuming this URL is correct and stable
# Removed || true so curl errors are visible!
curl -sSL $GITHUB_SCRIPT_URL -o /tmp/custom_script.sh && chmod +x /tmp/custom_script.sh && bash /tmp/custom_script.sh
EOL
chmod +x /workspace/run_github_script.sh

# Create an SSH startup script
cat > /workspace/start_ssh.sh << 'EOL'
#!/bin/bash
# Start SSH server
# Removed || echo so SSH startup errors are visible!
exec /usr/sbin/sshd -D # Using exec and -D to keep sshd in foreground as pid 1 (good for docker entrypoints)
EOL
chmod +x /workspace/start_ssh.sh

# Create a minimal onstart script that will be used in Vast.ai
cat > /workspace/minimal_onstart.sh << 'EOL'
#!/bin/bash
set -e # Ensure minimal_onstart.sh also exits on error

echo "Running minimal_onstart.sh..."

# Re-fixing package dependencies at runtime - This is potentially redundant if Dockerfile and provisioning worked.
# Leaving this in as it was in your original, but removed || true.
# If package installs consistently fail here, it points to an issue with version pinning
# or conflicts that need to be resolved during provisioning/build.
echo "Re-checking package dependencies at runtime..."
apt-get clean
apt-get update
# Removed || true so installation errors are visible!
apt-get install -y --allow-downgrades libcurl4=7.81.0-1ubuntu1.16 openssh-client=1:8.9p1-3ubuntu0.10 openssh-sftp-server openssh-server curl

/workspace/start_ssh.sh & # Run SSH in background (&) as the main entrypoint will be the VNC script

env | grep _ >> /etc/environment # Adds environment variables (good practice)

# Execute the GitHub script (which then downloads and runs onstart.sh)
/workspace/run_github_script.sh

# Finally, execute the main VNC startup script which is the container's designed entrypoint
# Use 'exec' to replace the current shell with the VNC script process (better signal handling)
# Added --wait as per your original script's intention, assuming vnc_startup.sh supports it.
echo "Starting main VNC application startup script..."
exec /dockerstartup/vnc_startup.sh --wait
EOL
chmod +x /workspace/minimal_onstart.sh

# Set up provisioning indicator
touch /etc/.provisioned

echo "Comprehensive provisioning completed successfully"
echo "====================================================================="
echo "IMPORTANT: After creating the template, use this for the onstart command field in Vast.ai:"
echo "bash /workspace/minimal_onstart.sh"
echo "====================================================================="
