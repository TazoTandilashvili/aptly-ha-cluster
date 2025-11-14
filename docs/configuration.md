# Configuration Options for Aptly High Availability Cluster

This document outlines the detailed configuration options available for setting up and managing the Aptly High Availability Cluster.

## General Configuration

### Virtual IP (VIP)

- **VIP**: The virtual IP address that clients will use to access the repository.
- **VIP Interface**: The network interface through which the VIP will be managed.

### HAProxy Configuration

- **HAProxy Master**: The IP address of the master HAProxy node.
- **HAProxy Backup**: The IP address of the backup HAProxy node.

### Aptly Node Configuration

- **Aptly Node 1**: The IP address of the first Aptly node.
- **Aptly Node 2**: The IP address of the second Aptly node.

### Proxy Node Configuration

- **Proxy Node 1**: The IP address of the first proxy node.
- **Proxy Node 2**: The IP address of the second proxy node.

## Aptly Configuration

Aptly supports the following components for Ubuntu 22.04 (Jammy):

- **Main Repositories**: 
  - `jammy` (main, universe)
  - `jammy-updates` (main, universe)
  - `jammy-security` (main, universe)

## Configuration File Examples

### Example Cluster Configuration

```bash
# Virtual IP
VIP="10.80.11.140"
VIP_INTERFACE="ens160"

# HAProxy nodes
HAPROXY_MASTER="10.80.11.141"
HAPROXY_BACKUP="10.80.11.142"

# Aptly nodes
APTLY_NODE1="10.80.11.143"
APTLY_NODE2="10.80.11.144"

# Proxy nodes
PROXY_NODE1="10.80.11.145"
PROXY_NODE2="10.80.11.146"

# Domain
DOMAIN="ubuntu.yourdomain.com"
```

## Additional Configuration Options

- **GPG Signing**: Ensure that all packages are signed with GPG keys for security.
- **Snapshot Retention**: Configure the number of snapshots to retain for Aptly.
- **Health Checks**: Set up health checks for HAProxy to monitor the status of backend nodes.

## Conclusion

Proper configuration is crucial for the successful deployment and operation of the Aptly High Availability Cluster. Ensure that all settings are reviewed and tested before going live.
