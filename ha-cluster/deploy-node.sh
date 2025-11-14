#!/bin/bash

# This script deploys a node in the HA cluster.

# Load cluster configuration
source ../config/cluster.conf

# Function to deploy a node
deploy_node() {
    local node_ip=$1
    echo "Deploying node at IP: $node_ip"

    # Install Aptly
    ssh root@$node_ip "cd /tmp && wget https://github.com/aptly-dev/aptly/releases/download/v1.6.2/aptly_1.6.2_linux_amd64.zip && unzip aptly_1.6.2_linux_amd64.zip && mv aptly_1.6.2_linux_amd64/aptly /usr/local/bin/ && chmod +x /usr/local/bin/aptly && aptly version"
    ssh root@$node_ip "aptly mirror create -architectures=amd64 my-mirror http://archive.ubuntu.com/ubuntu/ jammy main universe"
    ssh root@$node_ip "aptly publish mirror my-mirror"
}

# Deploy each node
deploy_node $APTLY_NODE1
deploy_node $APTLY_NODE2

echo "Node deployment completed."
