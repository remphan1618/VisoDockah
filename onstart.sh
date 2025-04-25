#!/bin/bash
set -e

# Provisioning script for Vast.ai template
# This script runs ONCE when creating the template

echo "Running provisioning script..."

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

# Pre-install TensorRT to speed up container startup
cd /workspace/VisoMaster
pip install --no-cache-dir tensorrt==10.6.0 --extra-index-url https://pypi.nvidia.com

# Set up provisioning indicator
touch /etc/.provisioned

echo "Provisioning completed successfully"
