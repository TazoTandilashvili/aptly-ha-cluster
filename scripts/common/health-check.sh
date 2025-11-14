#!/bin/bash

# Health check script for Aptly nodes

# Define the nodes to check
NODES=("10.80.11.143" "10.80.11.144")

# Loop through each node and check if it's reachable
for NODE in "${NODES[@]}"; do
    if ping -c 1 "$NODE" &> /dev/null; then
        echo "Node $NODE is reachable."
    else
        echo "Node $NODE is not reachable."
    fi
done

# Check if Aptly service is running on each node
for NODE in "${NODES[@]}"; do
    if ssh "$NODE" "systemctl is-active aptly" &> /dev/null; then
        echo "Aptly service is running on $NODE."
    else
        echo "Aptly service is NOT running on $NODE."
    fi
done
