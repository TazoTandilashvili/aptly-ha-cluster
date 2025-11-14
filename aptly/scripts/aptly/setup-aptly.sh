#!/bin/bash

# This script sets up Aptly for managing Ubuntu package repositories.

# Update package list
sudo apt-get update

# Install Aptly
sudo apt-get install -y aptly

# Create necessary directories for Aptly
mkdir -p /var/aptly/{db,public,private}

# Set permissions
sudo chown -R aptly:aptly /var/aptly

# Create default configuration file
cat <<EOL | sudo tee /etc/aptly.conf
{
    "rootDir": "/var/aptly",
    "database": {
        "type": "sqlite3",
        "file": "/var/aptly/db/aptly.db"
    },
    "public": {
        "url": "http://yourdomain.com/aptly",
        "path": "/var/aptly/public"
    },
    "private": {
        "url": "http://yourdomain.com/aptly/private",
        "path": "/var/aptly/private"
    }
}
EOL

# Initialize Aptly
sudo -u aptly aptly db create

echo "Aptly setup completed successfully."
