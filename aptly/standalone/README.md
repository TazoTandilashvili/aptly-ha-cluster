# Standalone Deployment of Aptly High Availability Cluster

This document provides instructions for setting up a standalone instance of the Aptly High Availability Ubuntu Repository Cluster.

## Overview

The standalone deployment is suitable for development and testing purposes. It consists of a single Aptly node without load balancing or high availability features.

## Prerequisites

- **Ubuntu 22.04 LTS** server
- Root access to the server
- Internet access for initial mirror sync
- Sufficient disk space for the Aptly repository

## Quick Start

To deploy the standalone setup, follow these steps:

1. **Clone the Repository:**

   ```bash
   git clone https://github.com/yourusername/aptly-ha-cluster.git
   cd aptly-ha-cluster
   ```

2. **Run the Deployment Script:**

   ```bash
   cd standalone
   sudo ./deploy.sh
   ```

## Configuration

After deployment, you may need to configure Aptly according to your requirements. The configuration file can be found in the `config` directory.

## Daily Operations

### Automatic Tasks

- **Daily Updates:** The repository will automatically sync and create snapshots at 6:00 AM.

### Manual Operations

You can manually trigger updates and cleanups using the following commands:

```bash
# Force update
sudo -u aptly /home/aptly/aptly-daily-update.sh

# Manual cleanup
sudo -u aptly /home/aptly/aptly-cleanup-daily.sh
```

## Troubleshooting

For common issues and solutions, refer to the [Troubleshooting Guide](../docs/troubleshooting.md).

## Support

For issues or support, please open a ticket in the [GitHub Issues](https://github.com/yourusername/aptly-ha-cluster/issues) section.

## License

This project is licensed under the MIT License. See the [LICENSE](../LICENSE) file for details.
