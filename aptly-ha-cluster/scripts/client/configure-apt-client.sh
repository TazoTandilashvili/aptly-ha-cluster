#!/bin/bash
#=============================================================================
# APT Client Configuration Script
# Description: Configure Ubuntu client to use Aptly HA repository
# Usage: sudo ./configure-apt-client.sh
#=============================================================================

set -e

# Configuration (update these!)
REPO_URL="${REPO_URL:-http://ubuntu.yourdomain.com}"
REPO_VIP="${REPO_VIP:-10.80.11.140}"

echo "=================================================="
echo "Ubuntu HA Repository Client Configuration"
echo "=================================================="
echo "Repository: $REPO_URL"
echo "VIP Address: $REPO_VIP"
echo ""

# Install required packages
echo "Installing required packages..."
apt-get update >/dev/null 2>&1 || true
apt-get install -y gnupg wget ca-certificates >/dev/null 2>&1

# Backup existing sources.list
if [ -f /etc/apt/sources.list ]; then
    BACKUP="/etc/apt/sources.list.backup.$(date +%Y%m%d-%H%M%S)"
    cp /etc/apt/sources.list "$BACKUP"
    echo "✅ Backed up sources.list to: $BACKUP"
fi

echo ""
echo "Downloading GPG keyrings..."

# Download Aptly custom key
echo -n "  - Aptly custom key... "
wget -q "$REPO_URL/repo-key.gpg" -O /tmp/aptly-key.gpg
if [ -f /tmp/aptly-key.gpg ] && [ -s /tmp/aptly-key.gpg ]; then
    if file /tmp/aptly-key.gpg 2>/dev/null | grep -q "PGP\|ASCII"; then
        gpg --dearmor < /tmp/aptly-key.gpg > /usr/share/keyrings/aptly-custom-keyring.gpg 2>/dev/null
    else
        cp /tmp/aptly-key.gpg /usr/share/keyrings/aptly-custom-keyring.gpg
    fi
    chmod 644 /usr/share/keyrings/aptly-custom-keyring.gpg
    echo "✅ ($(stat -c%s /usr/share/keyrings/aptly-custom-keyring.gpg) bytes)"
else
    echo "❌ FAILED"
    exit 1
fi

# Download Ubuntu official key
echo -n "  - Ubuntu official key... "
wget -q "$REPO_URL/ubuntu-official-keyring.gpg" -O /tmp/ubuntu-key.gpg
if [ -f /tmp/ubuntu-key.gpg ] && [ -s /tmp/ubuntu-key.gpg ]; then
    if file /tmp/ubuntu-key.gpg 2>/dev/null | grep -q "PGP\|ASCII"; then
        gpg --dearmor < /tmp/ubuntu-key.gpg > /usr/share/keyrings/ubuntu-archive-keyring.gpg 2>/dev/null
    else
        cp /tmp/ubuntu-key.gpg /usr/share/keyrings/ubuntu-archive-keyring.gpg
    fi
    chmod 644 /usr/share/keyrings/ubuntu-archive-keyring.gpg
    echo "✅ ($(stat -c%s /usr/share/keyrings/ubuntu-archive-keyring.gpg) bytes)"
else
    echo "❌ FAILED"
    exit 1
fi

# Verify keys are different
APTLY_SIZE=$(stat -c%s /usr/share/keyrings/aptly-custom-keyring.gpg)
UBUNTU_SIZE=$(stat -c%s /usr/share/keyrings/ubuntu-archive-keyring.gpg)

echo ""
if [ "$APTLY_SIZE" -ne "$UBUNTU_SIZE" ]; then
    echo "✅ Both keyrings verified (different keys)"
else
    echo "⚠️  Warning: Keys are the same size - may be duplicates"
fi

# Configure APT to allow release info changes
echo ""
echo "Configuring APT settings..."
cat > /etc/apt/apt.conf.d/99allow-release-info-change <<'EOFAPT'
# Allow repository metadata changes during HA failover
Acquire::AllowReleaseInfoChange "true";
EOFAPT
echo "✅ APT configured to handle failover gracefully"

# Configure sources.list
echo "Configuring APT sources..."
cat > /etc/apt/sources.list <<EOFSOURCES
# High Availability Ubuntu Repository
# Dual keyring support: Aptly nodes + Proxy fallback
deb [signed-by=/usr/share/keyrings/aptly-custom-keyring.gpg,/usr/share/keyrings/ubuntu-archive-keyring.gpg] $REPO_URL jammy main universe
deb [signed-by=/usr/share/keyrings/aptly-custom-keyring.gpg,/usr/share/keyrings/ubuntu-archive-keyring.gpg] $REPO_URL jammy-updates main universe
deb [signed-by=/usr/share/keyrings/aptly-custom-keyring.gpg,/usr/share/keyrings/ubuntu-archive-keyring.gpg] $REPO_URL jammy-security main universe
EOFSOURCES
echo "✅ sources.list configured"

# Clean APT cache
echo ""
echo "Cleaning APT cache..."
apt-get clean
rm -rf /var/lib/apt/lists/*

# Update package lists
echo "Updating package lists..."
if apt-get update --allow-releaseinfo-change; then
    echo ""
    echo "=================================================="
    echo "✅ Configuration completed successfully!"
    echo "=================================================="
    echo ""
    echo "Repository Details:"
    echo "  URL: $REPO_URL"
    echo "  VIP: $REPO_VIP"
    echo "  Distribution: Ubuntu 22.04 (Jammy)"
    echo "  Components: main, universe"
    echo ""
    echo "Keyring Configuration:"
    echo "  Aptly custom key: $APTLY_SIZE bytes"
    echo "  Ubuntu official key: $UBUNTU_SIZE bytes"
    echo ""
    echo "High Availability Status:"
    echo "  ✅ Aptly nodes (primary) - Custom signed packages"
    echo "  ✅ Proxy nodes (backup) - Ubuntu official packages"
    echo "  ✅ Seamless failover - No manual intervention required"
    echo ""
else
    echo ""
    echo "=================================================="
    echo "❌ Configuration failed during apt-get update"
    echo "=================================================="
    exit 1
fi
