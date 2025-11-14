# Daily Operations and Troubleshooting Guide

This document provides guidance on daily operations and troubleshooting for the Aptly High Availability Ubuntu Repository Cluster.

## Daily Operations

### Automatic Tasks (Cron)
- **06:00 AM**: Mirror update and snapshot creation
- **07:00 AM**: Old snapshot cleanup (keeps last 2)

### Manual Operations
```bash
# Force update
sudo -u aptly /home/aptly/aptly-daily-update.sh

# Manual cleanup
sudo -u aptly /home/aptly/aptly-cleanup-daily.sh

# Revert to previous snapshot
sudo -u aptly aptly publish switch jammy jammy-YYYYMMDD-merged
```

## Troubleshooting

Common issues and solutions:

| Issue | Solution |
|-------|----------|
| VIP not responding | Check Keepalived status |
| GPG signature errors | Re-run client configuration script |
| Mirror sync failed | Check disk space and internet connectivity |
| HAProxy backend DOWN | Verify service status on backend nodes |

For detailed troubleshooting steps, refer to the [Troubleshooting Guide](troubleshooting.md).
