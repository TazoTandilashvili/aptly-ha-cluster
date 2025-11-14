#!/bin/bash

# Verify the status of the node

NODE_IP=$1

if [ -z "$NODE_IP" ]; then
  echo "Usage: $0 <node-ip>"
  exit 1
fi

# Check if the node is reachable
ping -c 1 $NODE_IP > /dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "Node $NODE_IP is not reachable."
  exit 1
fi

# Check if the necessary services are running
SERVICES=("aptly" "haproxy" "keepalived")

for SERVICE in "${SERVICES[@]}"; do
  if systemctl is-active --quiet $SERVICE; then
    echo "$SERVICE is running on $NODE_IP."
  else
    echo "$SERVICE is NOT running on $NODE_IP."
  fi
done

echo "Node verification completed."
