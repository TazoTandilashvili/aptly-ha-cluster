#!/bin/bash

# This script sets up HAProxy for the Aptly High Availability Cluster.

# Define variables
HAPROXY_CONFIG="/etc/haproxy/haproxy.cfg"
HAPROXY_SERVICE="haproxy"

# Install HAProxy if not already installed
if ! command -v haproxy &> /dev/null; then
    echo "HAProxy not found. Installing..."
    apt-get update
    apt-get install -y haproxy
else
    echo "HAProxy is already installed."
fi

# Copy the HAProxy configuration file
if [ -f "$HAPROXY_CONFIG" ]; then
    echo "Backing up existing HAProxy configuration."
    cp "$HAPROXY_CONFIG" "$HAPROXY_CONFIG.bak"
fi

# Create a new HAProxy configuration
cat <<EOL > "$HAPROXY_CONFIG"
# HAProxy configuration for Aptly High Availability Cluster

frontend http_front
    bind *:80
    default_backend http_back

backend http_back
    balance roundrobin
    server aptly1 10.80.11.143:80 check
    server aptly2 10.80.11.144:80 check
EOL

# Restart HAProxy service
systemctl restart $HAPROXY_SERVICE

echo "HAProxy setup completed."
