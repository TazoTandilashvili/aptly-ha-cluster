# HA Cluster Deployment

Automated deployment scripts for the complete 7-node High Availability cluster.

## Quick Start

```bash
# 1. Configure your environment
cp ../config/cluster.conf.example ../config/cluster.conf
vim ../config/cluster.conf

# 2. Set up SSH keys to all nodes
ssh-copy-id root@10.80.11.141  # HAProxy Master
ssh-copy-id root@10.80.11.142  # HAProxy Backup
ssh-copy-id root@10.80.11.143  # Aptly 1
ssh-copy-id root@10.80.11.144  # Aptly 2
ssh-copy-id root@10.80.11.145  # Proxy 1
ssh-copy-id root@10.80.11.146  # Proxy 2

# 3. Run automated deployment
sudo ./deploy-ha.sh
```

## What It Does

The `deploy-ha.sh` script automatically:

1. ✅ **Verifies prerequisites**
   - Checks SSH connectivity to all nodes
   - Installs required tools (ssh, rsync)
   - Validates configuration

2. ✅ **Deploys HAProxy nodes**
   - Installs HAProxy + Keepalived
   - Configures load balancing
   - Sets up VIP with VRRP failover

3. ✅ **Deploys Aptly nodes**
   - Runs standalone deployment on each
   - Syncs Ubuntu mirrors (~100GB each)
   - Configures Nginx web server

4. ✅ **Deploys Proxy nodes**
   - Installs and configures Nginx
   - Sets up proxy to Ubuntu archives
   - Configures health checks

5. ✅ **Verifies deployment**
   - Tests VIP connectivity
   - Checks all backend nodes
   - Validates HAProxy stats

## Prerequisites

### SSH Access
You must have SSH key-based authentication set up to all nodes:

```bash
# Generate SSH key if you don't have one
ssh-keygen -t rsa -b 4096

# Copy to all nodes
for ip in 10.80.11.{141..146}; do
    ssh-copy-id root@$ip
done
```

### Configuration
Edit `../config/cluster.conf` with your specific settings:

```bash
cp ../config/cluster.conf.example ../config/cluster.conf
vim ../config/cluster.conf
```

Key settings to update:
- VIP and network interface
- Server IP addresses
- Domain name
- Passwords (change defaults!)

### Network Requirements
- All nodes must be on the same network segment
- VRRP traffic must be allowed (IP protocol 112)
- Ports to open:
  - 22 (SSH)
  - 80 (HTTP)
  - 8080 (HAProxy stats)

## Deployment Time

- **HAProxy nodes**: ~5 minutes each
- **Proxy nodes**: ~5 minutes each
- **Aptly nodes**: ~4 hours each (initial sync)

**Total estimated time**: ~8 hours (if Aptly nodes run sequentially)

### Parallel Deployment

To speed up Aptly deployment, you can run both nodes in parallel:

```bash
# Edit deploy-ha.sh and uncomment parallel execution section
# Or manually deploy Aptly nodes simultaneously in different terminals:

# Terminal 1
ssh root@10.80.11.143
cd /tmp && wget http://your-repo/standalone/deploy.sh
chmod +x deploy.sh && ./deploy.sh

# Terminal 2  
ssh root@10.80.11.144
cd /tmp && wget http://your-repo/standalone/deploy.sh
chmod +x deploy.sh && ./deploy.sh
```

## Monitoring Deployment

### Watch Progress

```bash
# HAProxy logs
ssh root@10.80.11.141 'journalctl -u haproxy -f'

# Aptly deployment log
ssh root@10.80.11.143 'tail -f /tmp/aptly-deploy.log'

# Check VIP status
watch -n 5 'curl -I http://10.80.11.140/dists/jammy/Release'
```

### Check Status

```bash
# Check all services
./check-cluster-status.sh

# Or manually
ssh root@10.80.11.141 'systemctl status haproxy keepalived'
ssh root@10.80.11.143 'systemctl status nginx'
```

## Troubleshooting

### SSH Connection Failed

```bash
# Verify connectivity
ping 10.80.11.141

# Test SSH manually
ssh root@10.80.11.141

# Check SSH key
ssh-add -l
```

### VIP Not Assigned

```bash
# Check Keepalived on both HAProxy nodes
ssh root@10.80.11.141 'systemctl status keepalived'
ssh root@10.80.11.142 'systemctl status keepalived'

# Check VRRP logs
ssh root@10.80.11.141 'journalctl -u keepalived | grep MASTER'
```

### Aptly Deployment Failed

```bash
# Check logs
ssh root@10.80.11.143 'tail -100 /tmp/aptly-deploy.log'

# Check disk space
ssh root@10.80.11.143 'df -h'

# Manually retry
ssh root@10.80.11.143
cd /tmp && ./deploy.sh
```

## Manual Deployment

If you prefer manual deployment or need to troubleshoot:

1. **Follow the detailed guide**: `../docs/ha-cluster-setup.md`
2. **Deploy each node type separately**:
   - Start with HAProxy nodes
   - Then Aptly nodes
   - Finally Proxy nodes

## Post-Deployment

### Verify Cluster

```bash
# Test VIP
curl -I http://10.80.11.140/dists/jammy/Release

# Check HAProxy stats
curl http://10.80.11.140:8080/stats -u admin:changeme123

# Test failover
ssh root@10.80.11.143 'systemctl stop nginx'
curl -I http://10.80.11.140/dists/jammy/Release  # Should still work
```

### Configure Clients

```bash
# Download client script
wget http://ubuntu.yourdomain.com/configure-apt-client.sh

# Run on each client
sudo ./configure-apt-client.sh
```

### Security Hardening

```bash
# Change HAProxy stats password
ssh root@10.80.11.141 'vim /etc/haproxy/haproxy.cfg'
# Update: stats auth admin:NEW_PASSWORD

# Change Keepalived VRRP password
ssh root@10.80.11.141 'vim /etc/keepalived/keepalived.conf'
# Update: auth_pass NEW_PASSWORD

# Restart services
ssh root@10.80.11.141 'systemctl restart haproxy keepalived'
```

## Files

- `deploy-ha.sh` - Main automated deployment script
- `check-cluster-status.sh` - Health check script (create this)
- `README.md` - This file

## Support

- **Documentation**: `../docs/ha-cluster-setup.md`
- **Troubleshooting**: `../docs/troubleshooting.md`
- **Issues**: https://github.com/TazoTandilashvili/aptly-ha-cluster/issues

## Tips

1. **Test SSH first**: Ensure passwordless SSH works before running deployment
2. **Use screen/tmux**: Deployment takes hours, use a terminal multiplexer
3. **Monitor disk space**: Aptly nodes need 150GB+ free
4. **Check logs**: If something fails, logs are your friend
5. **Be patient**: Initial Aptly sync takes time (~4 hours per node)

---

**Ready to deploy? Run `sudo ./deploy-ha.sh`** 🚀
