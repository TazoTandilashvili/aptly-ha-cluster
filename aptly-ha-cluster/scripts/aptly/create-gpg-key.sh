#!/bin/bash
#=============================================================================
# Create GPG Key for Aptly
# Description: Generate GPG signing key for repository
# Usage: sudo -u aptly ./create-gpg-key.sh
#=============================================================================

set -e

# Configuration
GPG_NAME="Aptly Repository Signing Key"
GPG_EMAIL="aptly@yourdomain.local"
GPG_TYPE="rsa3072"
GPG_EXPIRY="2y"

echo "Creating GPG key for Aptly package signing..."

# Check if key already exists
if gpg --list-keys "$GPG_EMAIL" &>/dev/null; then
    echo "GPG key for $GPG_EMAIL already exists"
    gpg --list-keys "$GPG_EMAIL"
    exit 0
fi

# Generate key
gpg --batch --quick-generate-key "$GPG_NAME <$GPG_EMAIL>" "$GPG_TYPE" sign "$GPG_EXPIRY"

# Get key ID
KEY_ID=$(gpg --list-keys --keyid-format LONG "$GPG_EMAIL" | grep -A 1 "pub" | tail -1 | awk '{print $1}')

echo ""
echo "✓ GPG key created successfully!"
echo ""
echo "Key ID: $KEY_ID"
echo ""
echo "Update /etc/aptly.conf with this key ID:"
echo "  \"gpgKey\": \"$KEY_ID\""
echo ""

# Export public key
mkdir -p /var/aptly/public
gpg --armor --export > /var/aptly/public/repo-key.gpg
chmod 644 /var/aptly/public/repo-key.gpg

echo "✓ Public key exported to: /var/aptly/public/repo-key.gpg"
echo ""
echo "List keys:"
gpg --list-keys "$GPG_EMAIL"
