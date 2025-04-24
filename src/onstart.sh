#!/bin/bash
### every exit != 0 fails the script
set -e

echo "Starting VisoMaster setup and services..."

# Add environment variables to /etc/environment (crucial for vast.ai)
env | grep _ >> /etc/environment || true

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

# Set standard environment variables for VNC
export VNC_PASSWORDLESS=${VNC_PASSWORDLESS:-true}
export VNC_RESOLUTION=${VNC_RESOLUTION:-1280x1024}

# Clean up any existing VNC processes
echo "Cleaning up any existing VNC processes..."
pkill -f vnc || true
pkill -f novnc || true
rm -rf /tmp/.X*-lock /tmp/.X11-unix/* || true

# Start VNC server - using the direct approach from the original repo
echo "Starting VNC server and services..."
/dockerstartup/vnc_startup.sh &

# Give VNC time to initialize
sleep 5

echo "Setup complete! Services available at:"
echo "- VNC: port 5901"
echo "- Web VNC: port 6901"
echo "- JupyterLab: port 8080"
echo "- Filebrowser: port 8585"
echo ""
echo "You can connect to these services using the vast.ai connection links"

# Keep the script running indefinitely to prevent container shutdown
if [ -z "$1" ]; then
  echo "Keeping container alive..."
  # This approach avoids issues with tmux and terminal requirements
  tail -f /dev/null
fi
