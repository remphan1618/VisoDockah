#!/bin/bash
echo "Starting VisoMaster environment setup..."

# Create logs directory in workspace
mkdir -p /workspace/logs
export LOG_DIR=/workspace/logs

# Save environment variables for any service that needs them
env | grep _ >> /etc/environment

# Set VNC environment variables
export DISPLAY=:1
export VNC_PORT=5901
export NO_VNC_PORT=6901
export NO_VNC_HOME=/workspace/noVNC 
export STARTUPDIR=/
export VNC_COL_DEPTH=24
export VNC_RESOLUTION=1280x1024
export VNC_PW=""
export VNC_PASSWORDLESS=true
export JUPYTER_DIR=/

# Start SSH server if installed
if [ -f /usr/sbin/sshd ]; then
  echo "Starting SSH server..."
  mkdir -p /var/run/sshd
  # Start SSH with root login permitted and empty passwords allowed
  sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
  sed -i 's/#PermitEmptyPasswords no/PermitEmptyPasswords yes/' /etc/ssh/sshd_config
  /usr/sbin/sshd || echo "WARNING: Failed to start SSH server"
fi

# Download TensorRT if not already present
if [ ! -d "/workspace/VisoMaster/tensorrt_engine" ] || [ -z "$(ls -A /workspace/VisoMaster/tensorrt_engine)" ]; then
  echo "Downloading TensorRT..."
  mkdir -p /workspace/VisoMaster/tensorrt_engine
  wget --progress=dot:giga -O /tmp/TensorRT.tar.gz https://huggingface.co/Red1618/Viso/resolve/main/TensorRT-10.9.0.34.Linux.x86_64-gnu.cuda-12.8.tar.gz?download=true
  tar -xzf /tmp/TensorRT.tar.gz -C /workspace/VisoMaster/tensorrt_engine --strip-components=1
  rm -f /tmp/TensorRT.tar.gz
  
  # Set up environment variables
  echo 'export TRT_HOME=/workspace/VisoMaster/tensorrt_engine' >> ~/.bashrc
  echo 'export PATH=$PATH:$TRT_HOME/bin' >> ~/.bashrc
  echo 'export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$TRT_HOME/lib' >> ~/.bashrc
  echo 'export LIBRARY_PATH=$LIBRARY_PATH:$TRT_HOME/lib' >> ~/.bashrc
  echo 'export CPATH=$CPATH:$TRT_HOME/include' >> ~/.bashrc
  
  # Source updated environment
  source ~/.bashrc
fi

# Download inswapper model if needed
if [ ! -f "/workspace/VisoMaster/model_assets/inswapper_128_fp16.onnx" ]; then
  echo "Downloading inswapper model..."
  wget -O /workspace/VisoMaster/model_assets/inswapper_128_fp16.onnx https://huggingface.co/Red1618/Viso/resolve/main/inswapper_128_fp16.onnx?download=true
fi

# Clean up any existing VNC processes
pkill -f vnc 2>/dev/null || true
pkill -f novnc 2>/dev/null || true
rm -rf /tmp/.X*-lock /tmp/.X11-unix/* 2>/dev/null || true

# Create empty VNC password file (completely disable authentication)
mkdir -p "$HOME/.vnc"
PASSWD_PATH="$HOME/.vnc/passwd"
if [[ -f $PASSWD_PATH ]]; then
    rm -f $PASSWD_PATH
fi

touch $PASSWD_PATH
chmod 600 $PASSWD_PATH

# Start noVNC with no security
echo "Starting noVNC web client with NO SECURITY..."
if [ -d "$NO_VNC_HOME" ]; then
  $NO_VNC_HOME/utils/novnc_proxy --vnc localhost:$VNC_PORT --listen $NO_VNC_PORT --web $NO_VNC_HOME > $LOG_DIR/novnc_startup.log 2>&1 &
  PID_SUB=$!
else
  echo "WARNING: noVNC home directory not found"
  # Keep a reference for wait command at the end
  sleep infinity &
  PID_SUB=$!
fi

# Start VNC server with all security disabled
echo "Starting VNC server with NO SECURITY..."
vncserver -kill $DISPLAY &> $LOG_DIR/vnc_startup.log 2>/dev/null || true
vncserver $DISPLAY -depth $VNC_COL_DEPTH -geometry $VNC_RESOLUTION -SecurityTypes None -localhost no > $LOG_DIR/vnc_startup.log 2>&1

echo "VNC server started with NO SECURITY on port 5901"

# Start window manager
echo "Starting window manager..."
if [ -f "$HOME/wm_startup.sh" ]; then
  $HOME/wm_startup.sh &> $LOG_DIR/wm_startup.log &
else
  echo "WARNING: Window manager startup script not found"
fi

# Start additional services with no authentication
echo "Starting JupyterLab at port 8080 with NO SECURITY..."
if command -v jupyter &> /dev/null; then
  jupyter lab --port 8080 --notebook-dir=/workspace --allow-root --no-browser --ip=0.0.0.0 --NotebookApp.token='' --NotebookApp.password='' > $LOG_DIR/jupyter.log 2>&1 &
else
  echo "WARNING: JupyterLab not found"
fi

echo "Starting Filebrowser at port 8585 with NO SECURITY..."
if command -v filebrowser &> /dev/null; then
  filebrowser -r /workspace -p 8585 -a 0.0.0.0 --noauth > $LOG_DIR/filebrowser.log 2>&1 &
else
  echo "WARNING: Filebrowser not found"
fi

# Start VisoMaster in the background
echo "Starting VisoMaster..."
if [ -f "/workspace/VisoMaster/main.py" ]; then
  cd /workspace/VisoMaster
  nohup python main.py > $LOG_DIR/visomaster.log 2>&1 &
else
  echo "WARNING: VisoMaster main.py not found"
fi

echo "Setup complete! ALL SECURITY DISABLED!"
echo "Services available at:"
echo "- VNC: port 5901 (NO SECURITY)"
echo "- Web VNC: port 6901 (NO SECURITY)"
echo "- JupyterLab: port 8080 (NO SECURITY)"
echo "- Filebrowser: port 8585 (NO SECURITY)"
echo "- VisoMaster: Running in background"
echo "- All logs are saved in: /workspace/logs/"

# Keep the script running
wait $PID_SUB
