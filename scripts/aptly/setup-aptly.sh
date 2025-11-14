#!/bin/bash

# This script installs and configures Aptly on Ubuntu 22.04

set -e

echo "=== Installing Aptly and Dependencies ==="

# Update system
sudo apt-get update
sudo apt-get install -y gnupg unzip nginx

# Install Aptly
echo "Installing Aptly v1.6.2..."
cd /tmp
wget https://github.com/aptly-dev/aptly/releases/download/v1.6.2/aptly_1.6.2_linux_amd64.zip
unzip aptly_1.6.2_linux_amd64.zip
mv aptly_1.6.2_linux_amd64/aptly /usr/local/bin/
chmod +x /usr/local/bin/aptly
aptly version

echo "=== Creating Aptly User ==="

# Create Aptly user
sudo useradd -r -m -d /home/aptly -s /usr/sbin/nologin -c "Aptly Repository User" aptly || true

# Create directories
sudo mkdir -p /var/aptly/tmp
sudo chown -R aptly:aptly /var/aptly

echo "=== Aptly Installation Complete ==="
