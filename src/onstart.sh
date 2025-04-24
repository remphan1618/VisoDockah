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

# Set required environment variables for VNC
export DISPLAY=${DISPLAY:-:1}
export VNC_PORT=${VNC_PORT:-5901}
export NO_VNC_PORT=${NO_VNC_PORT:-6901}
export NO_VNC_HOME=${NO_VNC_HOME:-/workspace/noVNC}
export STARTUPDIR=${STARTUPDIR:-/dockerstartup}
export VNC_COL_DEPTH=${VNC_COL_DEPTH:-24}
export VNC_RESOLUTION=${VNC_RESOLUTION:-1280x1024}
export VNC_PW=${VNC_PW:-vncpassword}
export VNC_PASSWORDLESS=${VNC_PASSWORDLESS:-true}

# Clean up any existing VNC processes
echo "Cleaning up any existing VNC processes..."
pkill -f vnc || true
pkill -f novnc || true
rm -rf /tmp/.X*-lock /tmp/.X11-unix/* || true

# Start VNC in a modified way that doesn't block
echo "Starting VNC and services..."
# Start noVNC
$NO_VNC_HOME/utils/novnc_proxy --vnc localhost:$VNC_PORT --listen $NO_VNC_PORT > $STARTUPDIR/no_vnc_startup.log 2>&1 &
PID_SUB=$!

# Kill any existing VNC server
vncserver -kill $DISPLAY &> $STARTUPDIR/vnc_startup.log || rm -rfv /tmp/.X*-lock /tmp/.X11-unix &> $STARTUPDIR/vnc_startup.log || echo "no locks present"

# Start VNC server
echo "Starting VNC server with depth=$VNC_COL_DEPTH, resolution=$VNC_RESOLUTION"
vnc_cmd="vncserver $DISPLAY -depth $VNC_COL_DEPTH -geometry $VNC_RESOLUTION PasswordFile=$HOME/.vnc/passwd --I-KNOW-THIS-IS-INSECURE"
if [[ ${VNC_PASSWORDLESS:-} == "true" ]]; then
  vnc_cmd="${vnc_cmd} -SecurityTypes None"
fi
$vnc_cmd > $STARTUPDIR/no_vnc_startup.log 2>&1

# Start window manager
echo "Starting window manager..."
$HOME/wm_startup.sh &> $STARTUPDIR/wm_startup.log &

# Give VNC a moment to initialize
sleep 3

# Start JupyterLab
echo "Starting JupyterLab at port 8080..."
nohup jupyter lab --port 8080 --notebook-dir=/workspace --allow-root --no-browser --ip=0.0.0.0 --NotebookApp.token='' --NotebookApp.password='' > $STARTUPDIR/jupyter.log 2>&1 &

# Start Filebrowser
echo "Starting Filebrowser at port 8585..."
nohup filebrowser -r /workspace -p 8585 -a 0.0.0.0 --noauth > $STARTUPDIR/filebrowser.log 2>&1 &

# Start VisoMaster in the background
echo "Starting VisoMaster..."
nohup python /workspace/visomaster/main.py > $STARTUPDIR/visomaster.log 2>&1 &

echo "Setup complete! Services available at:"
echo "- VNC: port 5901"
echo "- Web VNC: port 6901"
echo "- JupyterLab: port 8080"
echo "- Filebrowser: port 8585"
echo ""
echo "You can connect to these services using the vast.ai connection links"

# Keep the script running
wait $PID_SUB
