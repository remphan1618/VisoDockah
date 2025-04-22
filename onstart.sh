#!/bin/bash
set -e

echo "Starting VisoMaster setup..."

# Download TensorRT if not already present
if [ ! -d "/workspace/VisoMaster/tensorrt_engine" ] || [ -z "$(ls -A /workspace/VisoMaster/tensorrt_engine)" ]; then
  echo "Downloading TensorRT..."
  mkdir -p /workspace/VisoMaster/tensorrt_engine
  wget -O TensorRT.tar.gz https://huggingface.co/Red1618/Viso/resolve/main/TensorRT-10.9.0.34.Linux.x86_64-gnu.cuda-12.8.tar.gz?download=true
  tar -xzf TensorRT.tar.gz -C /workspace/VisoMaster/tensorrt_engine --strip-components=1
  rm -f TensorRT.tar.gz
  
  # Set up environment variables
  echo 'export TRT_HOME=/workspace/VisoMaster/tensorrt_engine' >> ~/.bashrc
  echo 'export PATH=$PATH:$TRT_HOME/bin' >> ~/.bashrc
  echo 'export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$TRT_HOME/lib' >> ~/.bashrc
  echo 'export LIBRARY_PATH=$LIBRARY_PATH:$TRT_HOME/lib' >> ~/.bashrc
  echo 'export CPATH=$CPATH:$TRT_HOME/include' >> ~/.bashrc
fi

# Download dependencies if not already present
if [ ! -d "/workspace/VisoMaster/dependencies" ] || [ -z "$(ls -A /workspace/VisoMaster/dependencies)" ]; then
  echo "Downloading dependencies..."
  mkdir -p /workspace/VisoMaster/dependencies
  wget -O dependencies.zip https://github.com/visomaster/visomaster-assets/releases/download/v0.1.0_dp/dependencies.zip
  unzip dependencies.zip -d /workspace/VisoMaster/dependencies
  rm -f dependencies.zip
fi

echo "Setup complete! Starting main application..."

# Start the VNC server
/dockerstartup/vnc_startup.sh
