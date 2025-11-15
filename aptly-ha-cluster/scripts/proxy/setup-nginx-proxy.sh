#!/bin/bash
#=============================================================================
# Nginx Proxy Setup Script
# Description: Install and configure Nginx as proxy to Ubuntu archives
# Usage: sudo ./setup-nginx-proxy.sh
#=============================================================================

set -e

GREEN='\033[0;32m'
NC='\033[0m'
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }

UPSTREAM_MIRROR="ge.archive.ubuntu.com"

log_info "Installing Nginx..."
apt-get update
apt-get install -y nginx

log_info "Configuring Nginx proxy to $UPSTREAM_MIRROR..."

cat > /etc/nginx/sites-available/ubuntu-proxy <<EOF
server {
    listen 80;
    server_name _;
    
    access_log /var/log/nginx/ubuntu-proxy-access.log;
    error_log /var/log/nginx/ubuntu-proxy-error.log;
    
    # Health check for HAProxy
    location /health {
        access_log off;
        return 200 "OK\n";
        add_header Content-Type text/plain;
    }
    
    # Serve Ubuntu's official GPG key
    location = /repo-key.gpg {
        proxy_pass http://${UPSTREAM_MIRROR}/ubuntu/project/ubuntu-archive-keyring.gpg;
        proxy_set_header Host ${UPSTREAM_MIRROR};
    }
    
    location /ubuntu-official-keyring.gpg {
        proxy_pass http://${UPSTREAM_MIRROR}/ubuntu/project/ubuntu-archive-keyring.gpg;
        proxy_set_header Host ${UPSTREAM_MIRROR};
    }
    
    # Distribution metadata
    location ~ ^/dists/(jammy|jammy-updates|jammy-security)/ {
        proxy_pass http://${UPSTREAM_MIRROR}/ubuntu\$request_uri;
        proxy_set_header Host ${UPSTREAM_MIRROR};
        proxy_buffering on;
        proxy_connect_timeout 30s;
        proxy_read_timeout 60s;
    }
    
    # Package pools
    location /pool/ {
        proxy_pass http://${UPSTREAM_MIRROR}/ubuntu/pool/;
        proxy_set_header Host ${UPSTREAM_MIRROR};
        proxy_buffering on;
    }
    
    # Catch-all
    location / {
        proxy_pass http://${UPSTREAM_MIRROR}/ubuntu/;
        proxy_set_header Host ${UPSTREAM_MIRROR};
    }
}
EOF

# Enable site
ln -sf /etc/nginx/sites-available/ubuntu-proxy /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Test configuration
nginx -t

log_info "Nginx proxy configured"
log_info "Upstream: $UPSTREAM_MIRROR"
log_info ""
log_info "Start with: systemctl enable nginx && systemctl start nginx"
log_info "Test with: curl http://localhost/health"
