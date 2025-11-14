# Standalone Setup for Aptly High Availability Cluster

This document provides instructions for setting up a standalone instance of the Aptly High Availability Cluster.

## Prerequisites

Before proceeding with the standalone setup, ensure that you have the following:

- A server running Ubuntu 22.04 LTS.
- Root access to the server.
- Internet access for initial mirror synchronization.

## Installation Steps

1. **Clone the Repository**

   Start by cloning the repository to your server:

   ```bash
   git clone https://github.com/yourusername/aptly-ha-cluster.git
   cd aptly-ha-cluster
   ```

2. **Run the Standalone Setup Script**

   Navigate to the standalone directory and execute the deployment script:

   ```bash
   cd standalone
   sudo ./deploy.sh
   ```

3. **Configuration**

   After the deployment, you may need to configure Aptly. Edit the configuration file located in the `config` directory:

   ```bash
   vim config/aptly.conf
   ```

   Adjust the settings as necessary for your environment.

## Accessing the Repository

Once the setup is complete, you can access your Aptly repository using the following URL:

```
http://<your-server-ip>/repo
```

## Daily Operations

### Automatic Tasks

The following tasks are scheduled to run automatically:

- **06:00 AM**: Mirror update and snapshot creation.
- **07:00 AM**: Old snapshot cleanup (keeps the last 2).

### Manual Operations

You can perform manual operations as needed:

- **Force Update**: 

   ```bash
   sudo -u aptly /home/aptly/aptly-daily-update.sh
   ```

- **Manual Cleanup**: 

   ```bash
   sudo -u aptly /home/aptly/aptly-cleanup-daily.sh
   ```

- **Revert to Previous Snapshot**: 

   ```bash
   sudo -u aptly aptly publish switch jammy jammy-YYYYMMDD-merged
   ```

## Troubleshooting

If you encounter issues during the setup or operation, refer to the [Troubleshooting Guide](troubleshooting.md) for common problems and solutions.

## Conclusion

You have successfully set up a standalone instance of the Aptly High Availability Cluster. For further information, refer to the other documentation files in the `docs` directory.
