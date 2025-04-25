#!/bin/bash
set -e

# PROVISION SCRIPT FOR VAST.AI TEMPLATE
# ====================================
# COPY THIS ENTIRE SCRIPT INTO THE "PROVISION SCRIPT" FIELD IN VAST.AI
# This runs ONCE when creating the template and sets up everything

echo "Running comprehensive provisioning script..."

# Fix package dependencies permanently
apt-get update
apt-get install -y --allow-downgrades libcurl4=7.81.0-1ubuntu1.16
apt-get install -y curl openssh-client=1:8.9p1-3ubuntu0.10 openssh-sftp-server openssh-server
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
PasswordAuthentication no
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
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
pip install --no-cache-dir tensorrt==10.6.0 --extra-index-url https://pypi.nvidia.com || echo "TensorRT installation skipped"

# Download models (doing this during provisioning saves time during container startup)
echo "Downloading models..."
python download_models.py

# Set proper permissions for the model directory
chmod -R 755 model_assets

# Create a script that will handle GitHub script download
cat > /workspace/run_github_script.sh << 'EOL'
#!/bin/bash
# Download and execute custom script from GitHub
echo "Downloading custom script from GitHub..."
GITHUB_SCRIPT_URL="https://raw.githubusercontent.com/remphan1618/VisoDockah/refs/heads/main/onstart.sh"
curl -sSL $GITHUB_SCRIPT_URL -o /tmp/custom_script.sh && chmod +x /tmp/custom_script.sh && bash /tmp/custom_script.sh
EOL
chmod +x /workspace/run_github_script.sh

# Create an SSH startup script
cat > /workspace/start_ssh.sh << 'EOL'
#!/bin/bash
# Start SSH server
/usr/sbin/sshd || echo "Failed to start SSH daemon"
EOL
chmod +x /workspace/start_ssh.sh

# Create a minimal onstart script that will be used in Vast.ai
cat > /workspace/minimal_onstart.sh << 'EOL'
#!/bin/bash
# Minimal onstart script for Vast.ai
/workspace/start_ssh.sh
env | grep _ >> /etc/environment
/workspace/run_github_script.sh
/dockerstartup/vnc_startup.sh --wait
EOL
chmod +x /workspace/minimal_onstart.sh

# Set up provisioning indicator
touch /etc/.provisioned

echo "Comprehensive provisioning completed successfully"
echo "====================================================================="
echo "IMPORTANT: After creating the template, use this for the onstart command field:"
echo "bash /workspace/minimal_onstart.sh"
echo "====================================================================="
