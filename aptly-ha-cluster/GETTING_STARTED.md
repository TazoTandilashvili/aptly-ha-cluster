# Getting Started with Aptly HA Cluster

This guide will help you get started quickly with deploying your Aptly repository infrastructure.

## 📖 What is This Project?

This repository provides everything needed to deploy a **highly available Ubuntu package repository** using Aptly, HAProxy, Keepalived, and Nginx. It supports both:

1. **Standalone deployment** - Single server for development/testing
2. **HA cluster deployment** - 7-server production-ready infrastructure

## 🚀 Quick Decision Tree

```
Do you need high availability?
│
├─ NO  → Use Standalone Deployment
│         ├─ For: Dev, test, small environments
│         ├─ Servers: 1
│         └─ Time: ~4 hours
│
└─ YES → Use HA Cluster Deployment
          ├─ For: Production, critical systems
          ├─ Servers: 7
          └─ Time: ~6 hours
```

## 📦 Option 1: Standalone Deployment

### Prerequisites
- 1x Ubuntu 22.04 LTS server
- 150GB disk space
- 8GB RAM
- Root access
- Internet connectivity

### Deployment Steps

```bash
# 1. Clone repository
git clone https://github.com/TazoTandilashvili/aptly-ha-cluster.git
cd aptly-ha-cluster/standalone

# 2. (Optional) Set custom domain
export DOMAIN="repo.example.com"

# 3. Run deployment script
sudo ./deploy.sh

# The script will:
# - Install Aptly and dependencies
# - Generate GPG keys
# - Create Ubuntu mirrors
# - Sync packages (~100GB download, 2-4 hours)
# - Configure Nginx
# - Set up automated updates

# 4. Verify installation
curl -I http://localhost/dists/jammy/Release
# Should return: HTTP/1.1 200 OK

# 5. Configure clients
# The script creates: /var/aptly/public/configure-apt-client.sh
# Share this with your clients to configure their APT sources
```

### Next Steps

1. **Test the repository**: Install a package on a test client
2. **Monitor updates**: Check `/var/log/aptly-update.log`
3. **Plan migration**: When ready, migrate to HA cluster

## 🏗️ Option 2: HA Cluster Deployment

### Prerequisites
- 7x Ubuntu 22.04 LTS servers
- Network connectivity between all servers
- DNS: `ubuntu.yourdomain.com` → `10.80.11.140`
- Root access to all servers

### Server Allocation

| Count | Type | Purpose | Resources |
|-------|------|---------|-----------|
| 2 | HAProxy | Load balancing | 2 CPU, 2GB RAM, 20GB disk |
| 2 | Aptly | Package mirrors | 4 CPU, 8GB RAM, 150GB disk |
| 2 | Proxy | Backup fallback | 2 CPU, 2GB RAM, 20GB disk |
| 1 | VIP | Virtual IP | (Floating between HAProxy nodes) |

### Deployment Steps

```bash
# 1. Clone repository
git clone https://github.com/TazoTandilashvili/aptly-ha-cluster.git
cd aptly-ha-cluster

# 2. Configure your environment
cp config/cluster.conf.example config/cluster.conf
vim config/cluster.conf

# Update these values:
# - VIP="10.80.11.140"
# - HAPROXY_MASTER_IP="10.80.11.141"
# - HAPROXY_BACKUP_IP="10.80.11.142"
# - APTLY_NODE1_IP="10.80.11.143"
# - APTLY_NODE2_IP="10.80.11.144"
# - PROXY_NODE1_IP="10.80.11.145"
# - PROXY_NODE2_IP="10.80.11.146"
# - DOMAIN="ubuntu.yourdomain.com"

# 3. Follow detailed deployment guide
cat docs/ha-cluster-setup.md

# Or follow these abbreviated steps:

# 3a. Deploy HAProxy nodes (141, 142)
#     - Install HAProxy + Keepalived
#     - Configure VIP
#     - Set up health checks

# 3b. Deploy Aptly nodes (143, 144)
#     - Use standalone/deploy.sh on each
#     - Sync packages
#     - Publish repositories

# 3c. Deploy Proxy nodes (145, 146)
#     - Install Nginx
#     - Configure proxy to Ubuntu archives
#     - Set up GPG key proxying

# 3d. Test failover scenarios
#     - Stop one Aptly node → traffic continues
#     - Stop both Aptly nodes → proxy takes over
#     - Stop HAProxy master → VIP fails to backup
```

### Verification

```bash
# Check VIP responds
curl -I http://10.80.11.140/dists/jammy/Release

# Check HAProxy stats
curl http://10.80.11.140:8080/stats -u admin:changeme123

# Test individual backends
curl -I http://10.80.11.143/dists/jammy/Release  # Aptly 1
curl -I http://10.80.11.144/dists/jammy/Release  # Aptly 2
curl -I http://10.80.11.145/dists/jammy/Release  # Proxy 1
curl -I http://10.80.11.146/dists/jammy/Release  # Proxy 2
```

## 🖥️ Client Configuration

### Automated Setup

```bash
# Download and run configuration script
wget http://ubuntu.yourdomain.com/configure-apt-client.sh
chmod +x configure-apt-client.sh
sudo ./configure-apt-client.sh
```

### Manual Setup

```bash
# 1. Download GPG keys
wget http://ubuntu.yourdomain.com/repo-key.gpg -O /tmp/aptly-key.gpg
wget http://ubuntu.yourdomain.com/ubuntu-official-keyring.gpg -O /tmp/ubuntu-key.gpg

# 2. Install keys
sudo gpg --dearmor < /tmp/aptly-key.gpg > /usr/share/keyrings/aptly-custom-keyring.gpg
sudo gpg --dearmor < /tmp/ubuntu-key.gpg > /usr/share/keyrings/ubuntu-archive-keyring.gpg

# 3. Configure sources
sudo tee /etc/apt/sources.list <<'EOF'
deb [signed-by=/usr/share/keyrings/aptly-custom-keyring.gpg,/usr/share/keyrings/ubuntu-archive-keyring.gpg] http://ubuntu.yourdomain.com jammy main universe
deb [signed-by=/usr/share/keyrings/aptly-custom-keyring.gpg,/usr/share/keyrings/ubuntu-archive-keyring.gpg] http://ubuntu.yourdomain.com jammy-updates main universe
deb [signed-by=/usr/share/keyrings/aptly-custom-keyring.gpg,/usr/share/keyrings/ubuntu-archive-keyring.gpg] http://ubuntu.yourdomain.com jammy-security main universe
EOF

# 4. Update
sudo apt-get update
```

## 📚 Documentation Structure

| Document | Purpose | When to Read |
|----------|---------|--------------|
| [README.md](README.md) | Project overview | Start here |
| [SUMMARY.md](SUMMARY.md) | Quick reference | Quick lookup |
| [PROJECT_STRUCTURE.txt](PROJECT_STRUCTURE.txt) | File organization | Understanding layout |
| [docs/ha-cluster-setup.md](docs/ha-cluster-setup.md) | HA deployment | Production setup |
| [docs/client-setup.md](docs/client-setup.md) | Client config | After server setup |
| [docs/troubleshooting.md](docs/troubleshooting.md) | Problem solving | When issues occur |
| [standalone/README.md](standalone/README.md) | Single node | Dev/test deployment |
| [CONTRIBUTING.md](CONTRIBUTING.md) | How to contribute | Want to help? |

## 🔧 Common Tasks

### Check Repository Status

```bash
# On Aptly node
sudo -u aptly aptly publish list
sudo -u aptly aptly snapshot list

# On any node
curl http://10.80.11.140/dists/jammy/Release
```

### Manual Repository Update

```bash
# On Aptly node
sudo -u aptly /home/aptly/aptly-daily-update.sh
```

### View Logs

```bash
# Aptly updates
tail -f /var/log/aptly-update.log

# Nginx access
tail -f /var/log/nginx/aptly-access.log

# HAProxy
journalctl -u haproxy -f
```

### Revert to Previous Snapshot

```bash
# List snapshots
sudo -u aptly aptly snapshot list

# Switch to specific date
sudo -u aptly aptly publish switch jammy jammy-20251110-merged
```

## 🧪 Testing Your Setup

### Test 1: Basic Functionality

```bash
# On a test client
apt-get update
apt-cache search htop
apt-get install -y htop
```

### Test 2: Failover (HA only)

```bash
# Stop one Aptly node
ssh root@10.80.11.143 'systemctl stop nginx'

# Clients should still work
apt-get update

# Restore
ssh root@10.80.11.143 'systemctl start nginx'
```

### Test 3: Performance

```bash
# Download a package
time apt-get install --download-only -y linux-image-generic

# Check HAProxy stats
curl http://10.80.11.140:8080/stats -u admin:changeme123
```

## 📊 Monitoring

### HAProxy Statistics

Access the web interface:
- URL: `http://10.80.11.140:8080/stats`
- Username: `admin`
- Password: `changeme123` (change in production!)

### Key Metrics to Monitor

- Backend status (UP/DOWN)
- Request rate
- Error rate
- Server load
- Disk usage on Aptly nodes

## 🆘 Getting Help

### Self-Service

1. Check [troubleshooting guide](docs/troubleshooting.md)
2. Review logs:
   - `/var/log/aptly-update.log`
   - `/var/log/nginx/aptly-error.log`
   - `journalctl -u haproxy`
3. Verify configuration files
4. Test connectivity

### Support Channels

- **GitHub Issues**: Report bugs or request features
- **Documentation**: Read all docs in `docs/` directory
- **Email**: support@yourdomain.com

### When Reporting Issues

Include:
- Deployment type (standalone or HA)
- Server information (OS version, resources)
- Error messages and logs
- Steps to reproduce
- What you've tried

## 🎯 Next Steps

After successful deployment:

1. ✅ **Security hardening**
   - Change default passwords
   - Configure firewall rules
   - Set up SSL/TLS (if needed)

2. ✅ **Monitoring**
   - Set up log aggregation
   - Configure alerts
   - Monitor disk usage

3. ✅ **Documentation**
   - Document your specific configuration
   - Create runbooks for your team
   - Update contact information

4. ✅ **Backup**
   - Set up configuration backups
   - Document recovery procedures
   - Test restore process

5. ✅ **Optimization**
   - Tune HAProxy settings
   - Optimize Aptly performance
   - Review retention policies

## 📝 Customization

### Change Repository Domain

```bash
# Update DNS
# A record: repo.example.com → 10.80.11.140

# Update HAProxy health checks
vim /etc/haproxy/haproxy.cfg
# Change: hdr Host ubuntu.yourdomain.com

# Update client scripts
vim /var/aptly/public/configure-apt-client.sh
# Change: REPO_URL="http://repo.example.com"
```

### Add More Components

To add restricted/multiverse:

```bash
# On Aptly nodes
sudo -u aptly aptly mirror create jammy-restricted \
  http://archive.ubuntu.com/ubuntu jammy restricted

sudo -u aptly aptly mirror update jammy-restricted

# Update publish command to include new component
```

### Change Update Schedule

```bash
# Edit cron
vim /etc/cron.d/aptly-tasks

# Change from 6:00 AM to 2:00 AM
0 2 * * * aptly /home/aptly/aptly-daily-update.sh ...
```

## ⚠️ Important Notes

1. **Initial sync takes time**: First repository sync downloads ~100GB and takes 2-4 hours
2. **Disk space**: Aptly nodes need 150GB+ for Ubuntu 22.04 complete mirror
3. **Internet required**: Initial setup requires internet for package download
4. **GPG keys**: Both keys (Aptly + Ubuntu) required for seamless failover
5. **DNS propagation**: Allow time for DNS changes to propagate
6. **Testing**: Always test in non-production before deploying to production

## 🎓 Learning Resources

- [Aptly Documentation](https://www.aptly.info/doc/overview/)
- [HAProxy Documentation](http://docs.haproxy.org/)
- [Keepalived User Guide](https://www.keepalived.org/manpage.html)
- [Nginx Documentation](https://nginx.org/en/docs/)

## 🔄 Updates and Maintenance

### Daily Automated Tasks

- **06:00 AM**: Repository update and snapshot creation
- **07:00 AM**: Cleanup old snapshots (keeps last 2)

### Manual Maintenance

```bash
# Force update
sudo -u aptly /home/aptly/aptly-daily-update.sh

# Cleanup
sudo -u aptly /home/aptly/aptly-cleanup-daily.sh

# Check status
sudo -u aptly aptly publish list
sudo -u aptly aptly snapshot list
```

---

**Ready to deploy? Choose your path:**

- 🏃 **Quick start**: `cd standalone && sudo ./deploy.sh`
- 🏗️ **Production**: Read `docs/ha-cluster-setup.md`
- 🤔 **Questions**: Check `docs/troubleshooting.md`

**Good luck with your deployment! 🚀**
