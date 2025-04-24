#!/bin/bash
### every exit != 0 fails the script
set -e

echo "Starting VisoMaster setup and services..."

# Start SSH server if present
if [ -f /usr/sbin/sshd ]; then
  echo "Starting SSH server..."
  mkdir -p /var/run/sshd
  /usr/sbin/sshd || echo "WARNING: Failed to start SSH server"
fi

# Download TensorRT if not already present
if [ ! -d "/workspace/VisoMaster/tensorrt_engine" ] || [ -z "$(ls -A /workspace/VisoMaster/tensorrt_engine)" ]; then
  echo "Downloading TensorRT..."
  mkdir -p /workspace/VisoMaster/tensorrt_engine
  wget --progress=dot:giga -O TensorRT.tar.gz https://huggingface.co/Red1618/Viso/resolve/main/TensorRT-10.9.0.34.Linux.x86_64-gnu.cuda-12.8.tar.gz?download=true
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
  wget --progress=dot:giga -O dependencies.zip https://github.com/visomaster/visomaster-assets/releases/download/v0.1.0_dp/dependencies.zip
  unzip dependencies.zip -d /workspace/VisoMaster/dependencies
  rm -f dependencies.zip
fi

# Download special inswapper file if needed
if [ ! -f "/workspace/VisoMaster/model_assets/inswapper_128_fp16.onnx" ]; then
  echo "Downloading inswapper model..."
  wget -O /workspace/VisoMaster/model_assets/inswapper_128_fp16.onnx https://huggingface.co/Red1618/Viso/resolve/main/inswapper_128_fp16.onnx?download=true
fi