#!/bin/bash
echo "Starting VisoMaster environment setup..."

# Save environment variables for any service that needs them
env | grep _ >> /etc/environment


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
fi

# Download inswapper model if needed
if [ ! -f "/workspace/VisoMaster/model_assets/inswapper_128_fp16.onnx" ]; then
  echo "Downloading inswapper model..."
  wget -O /workspace/VisoMaster/model_assets/inswapper_128_fp16.onnx https://huggingface.co/Red1618/Viso/resolve/main/inswapper_128_fp16.onnx?download=true
fi

# Clean up any existing VNC processes
pkill -f vnc || true
pkill -f novnc || true
rm -rf /tmp/.X*-lock /tmp/.X11-unix/* || true

# Setup VNC password
mkdir -p "$HOME/.vnc"
PASSWD_PATH="$HOME/.vnc/passwd"
if [[ -f $PASSWD_PATH ]]; then
    rm -f $PASSWD_PATH
fi
echo "$VNC_PW" | vncpasswd -f >> $PASSWD_PATH
chmod 600 $PASSWD_PATH

# Start noVNC
echo "Starting noVNC web client..."
$NO_VNC_HOME/utils/novnc_proxy --vnc localhost:$VNC_PORT --listen $NO_VNC_PORT > $STARTUPDIR/no_vnc_startup.log 2>&1 &
PID_SUB=$!

# Start VNC server
echo "Starting VNC server..."
vncserver -kill $DISPLAY &> $STARTUPDIR/vnc_startup.log || rm -rfv /tmp/.X*-lock /tmp/.X11-unix &> $STARTUPDIR/vnc_startup.log || echo "No locks present"
vncserver $DISPLAY -depth $VNC_COL_DEPTH -geometry $VNC_RESOLUTION PasswordFile=$HOME/.vnc/passwd --I-KNOW-THIS-IS-INSECURE -SecurityTypes None > $STARTUPDIR/no_vnc_startup.log 2>&1

# Start window manager
echo "Starting window manager..."
$HOME/wm_startup.sh &> $STARTUPDIR/wm_startup.log &

# Start additional services
echo "Starting JupyterLab at port 8080..."
jupyter lab --port 8080 --notebook-dir=/workspace --allow-root --no-browser --ip=0.0.0.0 --NotebookApp.token='' --NotebookApp.password='' > $STARTUPDIR/jupyter.log 2>&1 &

echo "Starting Filebrowser at port 8585..."
filebrowser -r /workspace -p 8585 -a 0.0.0.0 --noauth > $STARTUPDIR/filebrowser.log 2>&1 &

# Start VisoMaster in the background
echo "Starting VisoMaster..."
cd /workspace/visomaster
nohup python main.py > $STARTUPDIR/visomaster.log 2>&1 &

echo "Setup complete! Services available at:"
echo "- VNC: port 5901"
echo "- Web VNC: port 6901"
echo "- JupyterLab: port 8080"
echo "- Filebrowser: port 8585"

# Keep the script running
tail -f /dev/null
