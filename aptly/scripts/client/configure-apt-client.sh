#!/bin/bash

# This script configures the APT client to use the Aptly repository.

# Define the repository URL
REPO_URL="http://your.domain.com"

# Add the repository to the sources list
echo "deb $REPO_URL jammy main universe" | sudo tee /etc/apt/sources.list.d/aptly.list

# Import the GPG key
curl -fsSL "$REPO_URL/KEY.gpg" | sudo gpg --dearmor -o /usr/share/keyrings/aptly.gpg

# Update the package list
sudo apt update

# Install necessary packages
sudo apt install -y apt-transport-https ca-certificates

# Clean up
echo "APT client configured successfully to use the Aptly repository."
