# High Availability Cluster Setup

This document provides instructions for setting up a High Availability (HA) cluster using Aptly, HAProxy, Keepalived, and Nginx. The setup ensures that your Ubuntu package repository is highly available and resilient to failures.

## Prerequisites

Before proceeding with the HA cluster setup, ensure that you have the following:

- **7 Ubuntu 22.04 LTS servers** (or a minimum of 2 for testing)
- Root access to all servers
- Network connectivity between all nodes
- A configured Virtual IP (VIP) for the cluster

## Step 1: Clone the Repository

Start by cloning the repository to your local machine:

```bash
git clone https://github.com/yourusername/aptly-ha-cluster.git
cd aptly-ha-cluster
```

## Step 2: Configure the Cluster

Copy the example configuration file and edit it to suit your environment:

```bash
cp config/cluster.conf.example config/cluster.conf
vim config/cluster.conf
```

Make sure to set the correct IP addresses for your HAProxy and Aptly nodes.

## Step 3: Deploy the HA Cluster

Navigate to the HA cluster directory and run the deployment script:

```bash
cd ha-cluster
sudo ./deploy-ha.sh
```

This script will set up the HAProxy load balancer, Keepalived for VIP management, and the Aptly nodes.

## Step 4: Verify the Deployment

After the deployment is complete, verify that the HA cluster is functioning correctly:

```bash
cd ha-cluster
./verify-ha-cluster.sh
```

## Step 5: Testing Failover

To ensure that the HA setup is resilient, perform failover testing:

```bash
cd scripts/common
./test-failover.sh
```

This script will simulate a failure and check if the failover mechanism works as expected.

## Monitoring

You can monitor the HAProxy statistics by accessing the following URL:

```
http://<VIP>:8080/stats
```

Replace `<VIP>` with your configured Virtual IP address.

## Conclusion

You have successfully set up a High Availability cluster for your Ubuntu package repository using Aptly, HAProxy, Keepalived, and Nginx. For further details on configuration and maintenance, refer to the other documentation files in the `docs` directory.
