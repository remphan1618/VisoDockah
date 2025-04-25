#!/bin/bash
# =====================================================
# == IDEAL PROVISIONING SCRIPT (Based on Provided Dockerfile) ==
# =====================================================
# Run ONCE during template image creation.

set -e # Exit immediately if a command exits with a non-zero status.

echo ">>> Starting Ideal Provisioning Script for Template <<<"

# --- Install Missing Core Service: OpenSSH Server ---
echo ">>> Installing OpenSSH Server (missing from Dockerfile)..."
apt-get update
# Install SSH server components. Using --no-install-recommends is good practice.
apt-get install -y --no-install-recommends openssh-server openssh-client openssh-sftp-server
# Clean up APT cache after installs
apt-get clean && rm -rf /var/lib/apt/lists/*

# --- SSH Configuration ---
echo ">>> Configuring SSH Server..."
mkdir -p /var/run/sshd # Ensure runtime directory exists (Dockerfile might miss this)
chmod 0755 /var/run/sshd

# Create a robust sshd_config
cat > /etc/ssh/sshd_config << 'EOL'
Port 22
PermitRootLogin yes
StrictModes no
ClientAliveInterval 60
ClientAliveCountMax 3
UsePAM no
PasswordAuthentication no # Ensure you use SSH keys for security
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys # Assumes keys are in /root/.ssh/authorized_keys for root login
ChallengeResponseAuthentication no
LogLevel VERBOSE
Subsystem sftp /usr/lib/openssh/sftp-server # Verify this path with 'dpkg -L openssh-sftp-server' if needed
AcceptEnv LANG LC_* # Pass through locale environment variables
EOL

echo ">>> Generating SSH host keys..."
# Generate the server's unique host keys. CRITICAL for security.
ssh-keygen -A

# --- Application Setup (Optional/Large Components) ---
echo ">>> Setting up VisoMaster application extras..."
# Navigate to app directory (created by Dockerfile's git clone)
cd /workspace/VisoMaster || { echo "ERROR: /workspace/VisoMaster not found."; exit 1; }

echo ">>> Installing TensorRT (optional)..."
# Use || true to make it non-fatal, but report the attempt/failure
pip install --no-cache-dir tensorrt==10.6.0 --extra-index-url https://pypi.nvidia.com || echo "WARNING: TensorRT installation failed or was skipped. Continuing provisioning."

echo ">>> Downloading models (this may take time)..."
# Ensure download_models.py exists in /workspace/VisoMaster
if [ -f "download_models.py" ]; then
    python download_models.py
else
    echo "WARNING: download_models.py not found. Skipping model download."
fi

echo ">>> Setting model permissions..."
# Set permissions if the directory exists
if [ -d "model_assets" ]; then
    chmod -R 755 model_assets
else
    echo "INFO: model_assets directory not found. Skipping chmod."
fi

# --- Create the REAL On-Start Script for Instances ---
# This script will be executed by Vast.ai every time an instance starts.
echo ">>> Creating the instance on-start script (/workspace/onstart_for_instance.sh)..."
cat > /workspace/onstart_for_instance.sh << 'EOL'
#!/bin/bash
set -e # Exit on error within this script too

echo "--- Running Instance On-Start Script ---"

# Start necessary background services configured during provisioning
echo "Starting SSH daemon in background..."
/usr/sbin/sshd # Start the SSH service

# Optional: Add current environment variables to the system environment file
# Useful if ENTRYPOINT script needs access to Vast.ai env vars not explicitly passed
# echo "Updating /etc/environment..."
# env | grep _ >> /etc/environment

echo "--- Instance On-Start Script finished. Docker ENTRYPOINT will now run. ---"
# DO NOT call /dockerstartup/vnc_startup.sh here. It runs automatically next.
EOL
chmod +x /workspace/onstart_for_instance.sh

# --- Finalization ---
touch /etc/.provisioned_successfully_ideal
echo "========================================================================"
echo ">>> Ideal Provisioning Script Completed Successfully <<<"
echo ">>> Template Image is Ready <<<"
echo ""
echo ">>> IMPORTANT: When launching an instance from this template:"
echo ">>> 1. Select Launch Mode: 'Docker ENTRYPOINT'"
echo ">>> 2. Use this EXACT command in the 'On-start Script' field:"
echo ">>>    bash /workspace/onstart_for_instance.sh"
echo "========================================================================"

exit 0
