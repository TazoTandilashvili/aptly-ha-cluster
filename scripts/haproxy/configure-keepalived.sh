#!/bin/bash
#=============================================================================
# Keepalived Configuration Script
# Description: Install and configure Keepalived for VRRP
# Usage: sudo ./configure-keepalived.sh [master|backup]
#=============================================================================

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check arguments
if [ $# -ne 1 ] || [[ ! "$1" =~ ^(master|backup)$ ]]; then
    log_error "Usage: $0 [master|backup]"
    exit 1
fi

NODE_TYPE="$1"

log_info "Installing Keepalived..."
apt-get update
apt-get install -y keepalived

# Configuration will be provided separately
log_info "Keepalived installed for ${NODE_TYPE} node"
log_info "Configuration: /etc/keepalived/keepalived.conf"
log_info ""
log_info "Next steps:"
log_info "1. Copy keepalived configuration to /etc/keepalived/keepalived.conf"
log_info "2. Update with your VIP, interface, and peer IP"
log_info "3. systemctl enable keepalived"
log_info "4. systemctl start keepalived"
