#!/bin/bash

# Create a GPG key for Aptly
gpg --batch --gen-key <<EOF
Key-Type: default
Key-Length: 2048
Subkey-Type: default
Subkey-Length: 2048
Name-Real: Aptly Repository
Name-Email: aptly@example.com
Expire-Date: 0
EOF

# Export the GPG key
gpg --armor --export aptly@example.com > /etc/aptly/aptly.gpg

# Set permissions
chmod 600 /etc/aptly/aptly.gpg

# Output success message
echo "GPG key created and exported successfully."
