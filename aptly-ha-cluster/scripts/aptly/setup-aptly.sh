#!/bin/bash
#=============================================================================
# Aptly Setup Script
# Description: Install and configure Aptly on a single node
# Usage: sudo ./setup-aptly.sh
#=============================================================================

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

# Configuration
APTLY_VERSION="1.6.2"
APTLY_USER="aptly"
APTLY_ROOT="/var/aptly"

log_info "Installing Aptly ${APTLY_VERSION}..."

# Install dependencies
apt-get update
apt-get install -y gnupg unzip wget curl

# Download and install Aptly
cd /tmp
wget -q "https://github.com/aptly-dev/aptly/releases/download/v${APTLY_VERSION}/aptly_${APTLY_VERSION}_linux_amd64.zip"
unzip -q "aptly_${APTLY_VERSION}_linux_amd64.zip"
mv "aptly_${APTLY_VERSION}_linux_amd64/aptly" /usr/local/bin/
chmod +x /usr/local/bin/aptly
rm -rf "aptly_${APTLY_VERSION}_linux_amd64"*

# Create Aptly user
if ! id -u "$APTLY_USER" &>/dev/null; then
    useradd -r -m -d "/home/$APTLY_USER" -s /usr/sbin/nologin -c "Aptly Repository User" "$APTLY_USER"
    log_info "Created user: $APTLY_USER"
fi

# Create directories
mkdir -p "${APTLY_ROOT}/tmp"
chown -R "${APTLY_USER}:${APTLY_USER}" "$APTLY_ROOT"

log_info "Aptly $(aptly version | head -1) installed successfully"
log_info "User: $APTLY_USER"
log_info "Root directory: $APTLY_ROOT"
