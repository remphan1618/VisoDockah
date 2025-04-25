#!/bin/bash
# This script is for the Vast.ai Provisional script field.
# It runs inside the container after it has started.
# This version accounts for download_models.py being in the VisoMaster root directory
# and needing to be run from there to resolve imports.

# Exit immediately if a command exits with a non-zero status.
# Print commands and their arguments as they are executed.
set -eux

echo "--- Running Vast.ai Provisional Script ---"

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

echo "--- Provisional Script Finished ---"

# Note: The Dockerfile's ENTRYPOINT script (/dockerstartup/vnc_startup.sh)
# is typically what starts the VNC server, JupyterLab, FileBrowser, etc.
# This provisional script runs *after* the ENTRYPOINT has potentially started.
# Ensure that the VisoMaster application (if it's started via vnc_startup.sh
# or accessed through JupyterLab) is designed to handle models being
# downloaded asynchronously after its own startup, or consider modifying
# vnc_startup.sh to wait for this script to complete if necessary.
