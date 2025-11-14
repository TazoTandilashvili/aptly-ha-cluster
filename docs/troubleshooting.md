# Troubleshooting Guide for Aptly High Availability Cluster

This document provides solutions to common issues encountered while using the Aptly High Availability Ubuntu Repository Cluster.

## Common Issues and Solutions

| Issue | Solution |
|-------|----------|
| **VIP not responding** | Check the status of Keepalived to ensure it is running correctly. Verify network connectivity and configuration. |
| **GPG signature errors** | Re-run the client configuration script to ensure the GPG keys are correctly set up. Check for any missing keys. |
| **Mirror sync failed** | Ensure there is sufficient disk space on the Aptly nodes and verify internet connectivity for the mirror sync process. |
| **HAProxy backend DOWN** | Check the service status on the backend Aptly nodes. Ensure that the Aptly service is running and accessible. |
| **Nginx proxy not serving** | Verify the Nginx configuration and ensure that it is correctly set up to point to the Aptly nodes. Check the Nginx error logs for more details. |
| **Keepalived not failing over** | Check the Keepalived logs for any errors. Ensure that the VRRP configuration is correct and that the nodes can communicate over the network. |
| **Daily update script not running** | Check the cron job configuration to ensure it is set up correctly. Review the logs for any errors during execution. |

For further assistance, refer to the [Maintenance Guide](maintenance.md) or contact support.
