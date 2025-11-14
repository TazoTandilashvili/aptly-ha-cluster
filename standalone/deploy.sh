#!/bin/bash

# This script deploys the standalone Aptly setup.

# Update package lists
sudo apt-get update

# Install necessary packages
sudo apt-get install -y gnupg unzip nginx

# Install Aptly
cd /tmp
wget https://github.com/aptly-dev/aptly/releases/download/v1.6.2/aptly_1.6.2_linux_amd64.zip
unzip aptly_1.6.2_linux_amd64.zip
mv aptly_1.6.2_linux_amd64/aptly /usr/local/bin/
chmod +x /usr/local/bin/aptly
aptly version

# Configure Aptly
sudo mkdir -p /var/aptly
sudo chown -R $(whoami):$(whoami) /var/aptly

# Create Aptly configuration file
cat <<EOL > ~/.aptly.conf
{
    "rootDir": "/var/aptly",
    "downloadConcurrency": 4,
    "publishConcurrency": 4,
    "skipDownload": false,
    "gpg": {
        "keyring": "/var/aptly/aptly.gpg"
    }
}
EOL

# Start Nginx
sudo systemctl start nginx
sudo systemctl enable nginx

# Print completion message
echo "Standalone Aptly setup has been deployed successfully."
