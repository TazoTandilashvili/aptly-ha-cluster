# HA Cluster Setup

This document provides instructions for setting up a High Availability (HA) cluster using Aptly, HAProxy, and Keepalived. The HA cluster is designed to ensure continuous availability of the Ubuntu package repository.

## Overview

The HA cluster consists of multiple nodes that work together to provide a reliable and scalable package repository. The architecture includes:

- **HAProxy**: Acts as a load balancer to distribute traffic among the Aptly nodes.
- **Keepalived**: Manages the Virtual IP (VIP) for failover and redundancy.
- **Aptly Nodes**: Serve as the primary package mirrors.

## Prerequisites

Before setting up the HA cluster, ensure you have the following:

- At least 7 Ubuntu 22.04 LTS servers.
- Root access to all servers.
- Network connectivity between all nodes.
- Proper DNS configuration for the Virtual IP.

## Installation Steps

1. **Clone the Repository**:
   ```bash
   git clone https://github.com/yourusername/aptly-ha-cluster.git
   cd aptly-ha-cluster
   ```

2. **Configure the Environment**:
   - Copy the example configuration file:
     ```bash
     cp config/cluster.conf.example config/cluster.conf
     ```
   - Edit the configuration file to set your specific parameters:
     ```bash
     vim config/cluster.conf
     ```

3. **Deploy the HA Cluster**:
   ```bash
   cd ha-cluster
   sudo ./deploy-ha.sh
   ```

## Verification

After deployment, verify that the HA cluster is functioning correctly:

- Check the status of HAProxy:
  ```bash
  systemctl status haproxy
  ```

- Access the HAProxy statistics page:
  ```
  http://<VIP>:8080/stats
  ```

## Maintenance

Regular maintenance tasks include:

- Monitoring the health of the nodes.
- Performing updates and backups.
- Testing failover scenarios to ensure reliability.

## Troubleshooting

For common issues and solutions, refer to the [Troubleshooting Guide](../docs/troubleshooting.md).

## Conclusion

Setting up a High Availability cluster with Aptly ensures that your Ubuntu package repository remains accessible and reliable. Follow the steps outlined in this document for a successful deployment.
