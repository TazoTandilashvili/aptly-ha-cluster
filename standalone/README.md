# Standalone Deployment

Quick setup guide for a single-node Aptly repository.

## When to Use

- **Development/Testing**: Testing repository setup before production
- **Small Environments**: <50 clients, low availability requirements
- **Lab/Demo**: Learning Aptly or demonstrating repository management
- **Branch Office**: Simple mirror for satellite location

## When NOT to Use

- **Production**: Use HA cluster for production workloads
- **High Traffic**: Single node cannot handle 100+ concurrent clients
- **Critical Systems**: No redundancy, single point of failure

## Requirements

- Ubuntu 22.04 LTS
- 150GB disk space
- 8GB RAM (minimum)
- 4 CPU cores (recommended)
- Root access
- Internet connectivity

## Quick Start

```bash
# Clone repository
git clone https://github.com/TazoTandilashvili/aptly-ha-cluster.git
cd aptly-ha-cluster/standalone

# Set domain (optional, defaults to ubuntu.yourdomain.com)
export DOMAIN="repo.example.com"

# Run deployment
sudo ./deploy.sh
```

## What It Does

The deployment script will:

1. ✅ Install Aptly 1.6.2 and Nginx
2. ✅ Create Aptly user and directories
3. ✅ Generate GPG signing key
4. ✅ Create Ubuntu mirrors (jammy, jammy-updates, jammy-security)
5. ✅ Sync ~100GB of packages (2-4 hours)
6. ✅ Create initial snapshots
7. ✅ Publish repository
8. ✅ Configure Nginx web server
9. ✅ Set up daily update cron (6:00 AM)
10. ✅ Set up daily cleanup cron (7:00 AM)
11. ✅ Create client configuration script

## Post-Installation

### Verify Installation

```bash
# Check services
systemctl status nginx

# Check repository
curl -I http://localhost/dists/jammy/Release

# Check logs
tail -f /var/log/aptly-update.log
```

### Configure Clients

On client machines:

```bash
wget http://your-server/configure-apt-client.sh
chmod +x configure-apt-client.sh
sudo ./configure-apt-client.sh
```

### Maintenance

```bash
# Manual update
sudo -u aptly /home/aptly/aptly-daily-update.sh

# View snapshots
sudo -u aptly aptly snapshot list

# Revert to previous snapshot
sudo -u aptly aptly publish switch jammy jammy-YYYYMMDD-merged
```

## Upgrading to HA Cluster

When you're ready for production, migrate to the full HA cluster:

```bash
# 1. Deploy 6 additional servers using ha-cluster/
# 2. Copy Aptly data to new nodes
# 3. Configure HAProxy and proxies
# 4. Update client sources to use VIP
# 5. Decommission standalone node

See docs/ha-cluster-setup.md for details.
```

## Files

- `deploy.sh` - Main deployment script
- `../config/aptly.conf.example` - Aptly configuration template
- `../docs/` - Full documentation

## Support

See [../docs/troubleshooting.md](../docs/troubleshooting.md) for common issues.
