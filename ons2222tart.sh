#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status. CRITICAL for debugging.

# PROVISION SCRIPT FOR VAST.AI TEMPLATE
# ====================================
# COPY THIS ENTIRE SCRIPT INTO THE "PROVISION SCRIPT" FIELD IN VAST.AI
# This runs ONCE when creating the template and sets up persistent environment.

echo "Running comprehensive provisioning script..."
echo "--------------------------------------------------------------------"

# Fix APT sources to ensure consistent package versions for pinning
echo "Setting package repositories for version pinning..."
# Replacing the sources.list file
cp /etc/apt/sources.list /etc/apt/sources.list.bak || true
cat > /etc/apt/sources.list << 'EOL'
deb http://archive.ubuntu.com/ubuntu/ jammy main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ jammy-updates main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ jammy-security main restricted universe multiverse
EOL

# Clean APT cache and update with fixed repositories
echo "Cleaning APT cache and updating package list..."
apt-get clean
apt-get update

# Install SSH server and other packages needed post-Dockerfile build
# Also handle specific version pinning here
echo "Installing SSH server and specific packages, including version-pinned ones..."
# Removed || true so installation errors are visible!
# IMPORTANT: If this step fails, check if the specified versions are available in the configured repositories.
apt-get install -y --allow-downgrades \
openssh-server \
openssh-client=1:8.9p1-3ubuntu0.10 \ # Version pinned here
openssh-sftp-server \
curl \
libcurl4=7.81.0-1ubuntu1.16 \ # Version pinned here
rsync \
tmux \
less \
locales \
sudo \
software-properties-common

# Set up SSH server configuration
echo "Configuring SSH server..."
# SSH server package is installed by THIS script. We configure it here.
mkdir -p /etc/ssh
cat > /etc/ssh/sshd_config << 'EOL'
Port 22
PermitRootLogin yes
StrictModes no
ClientAliveInterval 10
ClientAliveCountMax 2
UsePAM no
PasswordAuthentication no # Assuming key-based auth is intended on Vast.ai
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys # Ensure keys are correctly placed for the user (likely root)
ChallengeResponseAuthentication no
LogLevel VERBOSE
EOL

# Create required directories for SSH runtime
echo "Creating SSH runtime directory..."
mkdir -p /var/run/sshd
chmod 0755 /var/run/sshd

# Create log directory (if not already done by Dockerfile)
echo "Creating log directory..."
mkdir -p /var/log

# Make sure everything in the VisoMaster directory is accessible
echo "Ensuring VisoMaster directory is accessible..."
# Assuming /workspace is the WORKDIR set in Dockerfile
cd /workspace/VisoMaster

# Pre-install TensorRT to speed up container startup (if not done by Dockerfile, or want to re-ensure)
# Keeping this here as it was in your original provisioning script.
echo "Installing TensorRT packages via pip..."
# Removed || echo so installation errors are visible!
pip install --no-cache-dir tensorrt==10.6.0 --extra-index-url https://pypi.nvidia.com

# Download models (doing this during provisioning saves time during container startup)
echo "Downloading models..."
# Assuming download_models.py exists in /workspace/VisoMaster and works
python download_models.py

# Set proper permissions for the model directory
echo "Setting permissions for model assets..."
chmod -R 755 model_assets

# Create a script that will handle GitHub script download (intended to be run by minimal_onstart.sh)
echo "Creating runtime script to fetch onstart.sh from GitHub..."
cat > /workspace/run_github_script.sh << 'EOL'
#!/bin/bash
set -e # Exit on error

echo "Downloading custom script from GitHub..."
GITHUB_SCRIPT_URL="https://raw.githubusercontent.com/remphan1618/VisoDockah/refs/heads/main/onstart.sh" # Verify this URL is correct and stable
# Removed || true so curl errors are visible!
curl -sSL $GITHUB_SCRIPT_URL -o /tmp/custom_script.sh
chmod +x /tmp/custom_script.sh
echo "Executing downloaded custom script..."
bash /tmp/custom_script.sh # Execute the downloaded script
EOL
chmod +x /workspace/run_github_script.sh

# Create an SSH startup script (intended to be called by minimal_onstart.sh)
echo "Creating runtime script to start SSH daemon..."
cat > /workspace/start_ssh.sh << 'EOL'
#!/bin/bash
set -e # Exit on error

echo "Starting SSH daemon..."
# Use exec -D to run sshd in the foreground, good for Docker entrypoints.
# If running in background (&) in the calling script, this might need adjustment.
# Keeping it as exec -D here, and backgrounding it in minimal_onstart.sh
exec /usr/sbin/sshd -D
EOL
chmod +x /workspace/start_ssh.sh

# Create the minimal onstart script that will be used in Vast.ai (intended as the ONSTART COMMAND)
echo "Creating minimal_onstart.sh script for Vast.ai..."
cat > /workspace/minimal_onstart.sh << 'EOL'
#!/bin/bash
set -e # Ensure minimal_onstart.sh also exits on error

echo "Running /workspace/minimal_onstart.sh at instance start..."

# Optional: Re-check/re-install specific pinned packages at runtime if needed
# This is less necessary now that provisioning installs them, but keeping
# a check for the pinned versions here. Removed the full list again.
echo "Re-checking specific packages (libcurl4, openssh-client) at runtime..."
apt-get clean
apt-get update
# Removed || true so installation errors are visible at instance start!
apt-get install -y --allow-downgrades libcurl4=7.81.0-1ubuntu1.16 openssh-client=1:8.9p1-3ubuntu0.10

echo "Starting SSH service..."
# Run SSH in background (&) as the main container entrypoint is the VNC script
/workspace/start_ssh.sh &

# Ensure environment variables are available to subsequent commands
echo "Adding environment variables to /etc/environment..."
# This might overwrite /etc/environment if run multiple times. Consider alternative if needed.
env | grep _ >> /etc/environment # Assuming variables like VNC_* are set by Vast.ai

echo "Executing GitHub script runner..."
# This downloads and runs the onstart.sh from GitHub
/workspace/run_github_script.sh

# Finally, execute the main VNC application startup script, which is the container's designed entrypoint.
# Use 'exec' to replace the current shell process with the VNC startup script process.
# This script (/dockerstartup/vnc_startup.sh) should handle starting VNC, Jupyter, Filebrowser, and VisoMaster.
echo "Executing main container entrypoint: /dockerstartup/vnc_startup.sh..."
exec /dockerstartup/vnc_startup.sh --wait # Ensure --wait is a valid flag for your script
EOL
chmod +x /workspace/minimal_onstart.sh

# Set up provisioning indicator
touch /etc/.provisioned

echo "--------------------------------------------------------------------"
echo "Comprehensive provisioning completed successfully"
echo "===================================================================="
echo "IMPORTANT: When launching a Vast.ai INSTANCE from this template,"
echo "use the following command in the 'On-start Script' field:"
echo "bash /workspace/minimal_onstart.sh"
echo "===================================================================="
