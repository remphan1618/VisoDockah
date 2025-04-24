#!/bin/bash
# Simple startup script that avoids syntax errors

echo "starting up" > /var/log/onstart.log

# Start SSH server if installed
if [ -f /usr/sbin/sshd ]; then
  echo "Starting SSH server..." >> /var/log/onstart.log
  mkdir -p /var/run/sshd
  /usr/sbin/sshd || echo "WARNING: Failed to start SSH server" >> /var/log/onstart.log
fi

# Start VNC server if available
if [ -f /dockerstartup/vnc_startup.sh ]; then
  echo "Starting VNC server..." >> /var/log/onstart.log
  bash /dockerstartup/vnc_startup.sh >> /var/log/onstart.log 2>&1 &
fi

# Start JupyterLab if available
if command -v jupyter &> /dev/null; then
  echo "Starting JupyterLab at port 8080..." >> /var/log/onstart.log
  jupyter lab --port 8080 --notebook-dir=/workspace --allow-root --no-browser --ip=0.0.0.0 --NotebookApp.token='' --NotebookApp.password='' >> /var/log/onstart.log 2>&1 &
fi

# Start Filebrowser if available
if command -v filebrowser &> /dev/null; then
  echo "Starting Filebrowser at port 8585..." >> /var/log/onstart.log
  filebrowser -r /workspace -p 8585 -a 0.0.0.0 --noauth >> /var/log/onstart.log 2>&1 &
fi

echo "Environment setup complete!" >> /var/log/onstart.log

# Keep container running
tail -f /dev/null
