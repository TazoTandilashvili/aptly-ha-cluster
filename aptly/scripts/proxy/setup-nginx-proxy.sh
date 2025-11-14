#!/bin/bash

# This script sets up the Nginx proxy for the Aptly High Availability cluster.

# Variables
NGINX_CONF="/etc/nginx/sites-available/aptly"
NGINX_LINK="/etc/nginx/sites-enabled/aptly"

# Create Nginx configuration file
cat <<EOL > $NGINX_CONF
server {
    listen 80;
    server_name ubuntu.yourdomain.com;

    location / {
        proxy_pass http://10.80.11.140; # Virtual IP of the HAProxy
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOL

# Create a symbolic link to enable the configuration
ln -s $NGINX_CONF $NGINX_LINK

# Test Nginx configuration
nginx -t

# Restart Nginx to apply changes
systemctl restart nginx

echo "Nginx proxy setup completed."
