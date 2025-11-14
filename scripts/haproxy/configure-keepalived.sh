#!/bin/bash

# Configure Keepalived for HAProxy

# Load the configuration file
source /etc/keepalived/keepalived.conf

# Set the virtual IP address
VIP="10.80.11.140"
INTERFACE="ens160"

# Install Keepalived if not already installed
if ! command -v keepalived &> /dev/null
then
    echo "Keepalived not found, installing..."
    apt-get update
    apt-get install -y keepalived
fi

# Create Keepalived configuration
cat <<EOL > /etc/keepalived/keepalived.conf
vrrp_instance VI_1 {
    state MASTER
    interface $INTERFACE
    virtual_router_id 51
    priority 100
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass your_password
    }
    virtual_ipaddress {
        $VIP
    }
}
EOL

# Restart Keepalived service
systemctl restart keepalived

echo "Keepalived configured with VIP $VIP on interface $INTERFACE."
