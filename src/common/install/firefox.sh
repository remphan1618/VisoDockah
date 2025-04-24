#!/bin/bash
set -e
echo "Installing Firefox"
apt-get update && apt-get install -y firefox
echo "Firefox installation complete"

