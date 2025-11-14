#!/bin/bash

# This script deploys the High Availability (HA) cluster for the Aptly repository.

# Load cluster configuration
source ../config/cluster.conf

# Function to deploy a node
deploy_node() {
    local node_ip=$1
    echo "Deploying node at $node_ip..."
    ssh root@$node_ip 'bash -s' < ./deploy-node.sh
}

# Deploy HAProxy nodes
deploy_node $HAPROXY_MASTER
deploy_node $HAPROXY_BACKUP

# Deploy Aptly nodes
deploy_node $APTLY_NODE1
deploy_node $APTLY_NODE2

# Deploy Proxy nodes
deploy_node $PROXY_NODE1
deploy_node $PROXY_NODE2

echo "HA cluster deployment completed."
