#!/bin/bash
#=============================================================================
# HAProxy Setup Script
# Description: Install and configure HAProxy
# Usage: sudo ./setup-haproxy.sh
#=============================================================================

set -e

GREEN='\033[0;32m'
NC='\033[0m'
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }

log_info "Installing HAProxy..."

# Install HAProxy
apt-get update
apt-get install -y haproxy

# Backup original config
if [ -f /etc/haproxy/haproxy.cfg ]; then
    cp /etc/haproxy/haproxy.cfg /etc/haproxy/haproxy.cfg.backup.$(date +%Y%m%d)
fi

log_info "HAProxy installed"
log_info "Version: $(haproxy -v | head -1)"
log_info ""
log_info "Configuration file: /etc/haproxy/haproxy.cfg"
log_info "Copy your config and run: systemctl restart haproxy"
