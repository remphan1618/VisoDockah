#!/bin/bash

# This script runs when the container starts
# It downloads necessary models and sets up any outstanding dependencies

echo "Running VisoMaster onstart script..."

# Add environment variables to /etc/environment
env | grep _ >> /etc/environment
echo "Environment variables added to /etc/environment"

# Fix package dependency issues
echo "Fixing package dependency issues..."
# Update package lists
apt-get update

# Fix dependencies in correct order
apt-get install -y --allow-downgrades libcurl4=7.81.0-1ubuntu1.16
apt-get install -y curl
apt-get install -y openssh-client=1:8.9p1-3ubuntu0.10
apt-get install -y openssh-sftp-server
apt-get install -y openssh-server
echo "Package dependency issues fixed"

# Change to the VisoMaster directory
cd /workspace/VisoMaster

# Try to install TensorRT (skipping if it fails due to space constraints)
echo "Installing TensorRT packages..."
pip install --no-cache-dir tensorrt==10.6.0 --extra-index-url https://pypi.nvidia.com || echo "TensorRT installation skipped"

# Download models if they don't exist already
echo "Checking for and downloading models..."
python download_models.py

# Set proper permissions for the model directory
chmod -R 755 model_assets

# Download and execute custom script from GitHub
echo "Downloading custom script from GitHub..."
GITHUB_SCRIPT_URL="https://raw.githubusercontent.com/remphan1618/VisoDockah/refs/heads/main/onstart.sh"
curl -sSL $GITHUB_SCRIPT_URL -o /tmp/custom_script.sh
chmod +x /tmp/custom_script.sh
bash /tmp/custom_script.sh

echo "VisoMaster onstart script completed"
