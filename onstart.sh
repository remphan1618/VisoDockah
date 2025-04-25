#!/bin/bash

# This script runs when the container starts
# It downloads necessary models and sets up any outstanding dependencies

echo "Running VisoMaster onstart script..."

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

echo "VisoMaster onstart script completed"
