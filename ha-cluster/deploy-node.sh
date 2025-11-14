#!/bin/bash

# This script deploys a node in the HA cluster.

# Load cluster configuration
source ../config/cluster.conf

# Function to deploy a node
deploy_node() {
    local node_ip=$1
    echo "Deploying node at IP: $node_ip"

    # Example commands to deploy the node
    ssh root@$node_ip "apt-get update && apt-get install -y aptly"
    ssh root@$node_ip "aptly mirror create -architectures=amd64 my-mirror http://archive.ubuntu.com/ubuntu/ jammy main universe"
    ssh root@$node_ip "aptly publish mirror my-mirror"
}

# Deploy each node
deploy_node $APTLY_NODE1
deploy_node $APTLY_NODE2

echo "Node deployment completed."
