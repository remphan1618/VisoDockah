#!/bin/bash
# This script is for the Vast.ai Provisional script field.
# It runs inside the container after it has started.
# --- MODIFIED TO INCLUDE INSTALLERS FROM PROVIDED SCRIPTS ---
# Installs: common tools, XFCE, fonts, nss-wrapper, generates locale, modifies .bashrc
# Then runs the original VisoMaster model download logic.

# Exit immediately if a command exits with a non-zero status.
# Print commands and their arguments as they are executed.
set -eux # u: treat unset variables as error, x: print commands

echo "--- Running Vast.ai Provisional Script ---"

# --- BEGIN COMBINED INSTALLATION SECTION ---
echo "Updating package list and installing prerequisites..."
apt-get update # Update package lists first

# Install all required packages in one go
# Assuming script runs as root, so no 'sudo' needed here. Add 'sudo' if run as non-root with sudo rights.
# Using --no-install-recommends to potentially reduce image size
apt-get install -y --no-install-recommends \
    libnss-wrapper \
    gettext \
    ttf-wqy-zenhei \
    vim \
    wget \
    net-tools \
    locales \
    bzip2 \
    procps \
    apt-utils \
    python3-numpy \
    supervisor \
    xfce4 \
    xfce4-terminal \
    xterm \
    dbus-x11 \
    libdbus-glib-1-2

# Remove unnecessary packages
echo "Removing unnecessary packages..."
apt-get purge -y pm-utils *screensaver*

# Clean up downloaded package files
echo "Cleaning up apt cache..."
apt-get clean -y
rm -rf /var/lib/apt/lists/*

# Generate locale
echo "Generating en_US.UTF-8 locale..."
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
locale-gen

# Add source command to .bashrc
echo "Adding 'source generate_container_user' to .bashrc"
# WARNING: This modifies the .bashrc of the user RUNNING THIS SCRIPT (likely root).
#          Adjust '$HOME/.bashrc' to '/home/user/.bashrc' if needed for a specific user.
# WARNING: Ensure $STARTUPDIR is defined elsewhere in your environment (e.g., Dockerfile).
# WARNING: Ensure the script '$STARTUPDIR/generate_container_user' exists (created elsewhere).
echo 'source $STARTUPDIR/generate_container_user' >> $HOME/.bashrc

echo "Finished installing prerequisites."
# --- END COMBINED INSTALLATION SECTION ---


# --- BEGIN ORIGINAL VISOMASTER MODEL DOWNLOAD LOGIC ---
echo "Starting VisoMaster model download process..."

# Define the root directory of the VisoMaster project
VISOMASTER_ROOT_DIR="/workspace/visomaster"
MODEL_DOWNLOAD_SCRIPT_NAME="download_models.py"
MODEL_DOWNLOAD_SCRIPT_FULL_PATH="$VISOMASTER_ROOT_DIR/$MODEL_DOWNLOAD_SCRIPT_NAME"


# Check if the VisoMaster directory exists
if [ ! -d "$VISOMASTER_ROOT_DIR" ]; then
  echo "Error: VisoMaster project directory not found at $VISOMASTER_ROOT_DIR."
  echo "Please ensure the VisoMaster repository was cloned correctly in the Dockerfile."
  exit 1
fi

# Check if the download script exists
if [ ! -f "$MODEL_DOWNLOAD_SCRIPT_FULL_PATH" ]; then
    echo "Error: download_models.py script not found at $MODEL_DOWNLOAD_SCRIPT_FULL_PATH."
    echo "Please ensure the VisoMaster repository and the script are present."
    exit 1
fi


# Navigate to the root of the VisoMaster project
echo "Changing directory to $VISOMASTER_ROOT_DIR to execute model download script"
cd "$VISOMASTER_ROOT_DIR" || { echo "Failed to change directory to $VISOMASTER_ROOT_DIR!"; exit 1; }

# Execute the Python script to download the models from the project root
# We run it from here so it can correctly import modules from the 'app' package
echo "Executing $MODEL_DOWNLOAD_SCRIPT_NAME from $VISOMASTER_ROOT_DIR..."
python3 "$MODEL_DOWNLOAD_SCRIPT_NAME"

# Check the exit status of the python script
if [ $? -eq 0 ]; then
  echo "download_models.py executed successfully."
else
  echo "Error: download_models.py failed."
  exit 1
fi

echo "VisoMaster model download process finished."
# --- END ORIGINAL VISOMASTER MODEL DOWNLOAD LOGIC ---

echo "--- Provisional Script Finished ---"

# Note: The Dockerfile's ENTRYPOINT script (like the vnc_startup.sh you provided elsewhere)
# is typically what starts the VNC server, JupyterLab, FileBrowser, etc.
# This provisional script runs *after* the container starts but potentially before
# the main application startup logic in the ENTRYPOINT. Ensure dependencies are met.
