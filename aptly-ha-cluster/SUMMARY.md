# Aptly HA Cluster - Project Summary

## 📦 What's Included

This repository contains everything needed to deploy a production-ready, highly available Ubuntu package repository infrastructure.

### Repository Structure

```
aptly-ha-cluster/
├── README.md                          # Main project documentation
├── LICENSE                            # MIT License
├── CONTRIBUTING.md                    # Contribution guidelines
├── .gitignore                         # Git ignore rules
│
├── config/                            # Configuration templates
│   ├── cluster.conf.example          # Cluster configuration
│   ├── aptly.conf.example            # Aptly settings
│   ├── haproxy.cfg.example           # HAProxy config
│   └── keepalived-master.conf.example # Keepalived for master node
│
├── docs/                              # Documentation
│   ├── ha-cluster-setup.md           # Full HA cluster guide
│   ├── client-setup.md               # Client configuration
│   └── troubleshooting.md            # Problem solving guide
│
└── standalone/                        # Single-node deployment
    ├── README.md                      # Standalone guide
    └── deploy.sh                      # Automated deployment script
```

## 🚀 Quick Start Options

### Option 1: Standalone (Single Node)

**Best for**: Development, testing, small environments

```bash
git clone https://github.com/TazoTandilashvili/aptly-ha-cluster.git
cd aptly-ha-cluster/standalone
sudo ./deploy.sh
```

**Time**: ~4 hours (mostly package sync)
**Servers**: 1
**Availability**: None (single point of failure)

### Option 2: High Availability Cluster

**Best for**: Production, critical systems, high traffic

```bash
git clone https://github.com/TazoTandilashvili/aptly-ha-cluster.git
cd aptly-ha-cluster

# Configure your environment
cp config/cluster.conf.example config/cluster.conf
vim config/cluster.conf

# Follow docs/ha-cluster-setup.md for deployment
```

**Time**: ~6 hours
**Servers**: 7 (2 HAProxy, 2 Aptly, 2 Proxy, 1 VIP)
**Availability**: 99.9%+ with automatic failover

## 📋 Features Comparison

| Feature | Standalone | HA Cluster |
|---------|-----------|------------|
| Servers Required | 1 | 7 |
| Deployment Time | 4 hours | 6 hours |
| Load Balancing | ❌ | ✅ HAProxy |
| Failover | ❌ | ✅ Automatic |
| Backup Tier | ❌ | ✅ Proxy to Ubuntu |
| VIP (Floating IP) | ❌ | ✅ Keepalived |
| Maintenance | ⚠️ Downtime required | ✅ Zero-downtime |
| Best For | Dev/Test | Production |

## 🏗️ HA Cluster Architecture

```
┌─────────────────────────────────────────────────┐
│              Clients (apt-get)                  │
└────────────────────┬────────────────────────────┘
                     │
                     ▼
          ┌──────────────────────┐
          │    Virtual IP (VIP)   │
          │    10.80.11.140      │
          └──────────┬────────────┘
                     │
        ┌────────────┴────────────┐
        │                         │
   ┌────▼─────┐            ┌─────▼────┐
   │ HAProxy  │            │ HAProxy  │
   │ Master   │◄──VRRP────►│ Backup   │
   │  .141    │            │   .142   │
   └────┬─────┘            └─────┬────┘
        │                         │
        └────────────┬────────────┘
                     │
         ┌───────────┴───────────┐
         │                       │
    ┌────▼────┐            ┌─────▼────┐
    │ Tier 1: │            │ Tier 2:  │
    │ Aptly   │            │ Proxy    │
    └────┬────┘            └─────┬────┘
         │                        │
   ┌─────┴─────┐          ┌──────┴─────┐
   │           │          │            │
┌──▼──┐   ┌───▼─┐    ┌───▼──┐    ┌───▼──┐
│Aptly│   │Aptly│    │Proxy │    │Proxy │
│ .143│   │ .144│    │ .145 │    │ .146 │
└─────┘   └─────┘    └──────┘    └──────┘
```

## 🎯 Key Components

### 1. HAProxy Layer (Load Balancer)
- **Purpose**: Traffic distribution and health checking
- **Nodes**: 2 (Master + Backup)
- **Features**: 
  - Round-robin load balancing
  - Health checks every 5 seconds
  - Automatic backend failover
  - Statistics dashboard (:8080/stats)

### 2. Keepalived (VIP Management)
- **Purpose**: High availability for HAProxy
- **Protocol**: VRRP (Virtual Router Redundancy Protocol)
- **Features**:
  - Automatic VIP failover
  - HAProxy health monitoring
  - Sub-second failover

### 3. Aptly Nodes (Primary Tier)
- **Purpose**: Local Ubuntu package mirrors
- **Nodes**: 2
- **Features**:
  - Full Ubuntu 22.04 mirror (~100GB)
  - GPG package signing
  - Daily automated updates (6 AM)
  - Snapshot management
  - Load balanced serving

### 4. Proxy Nodes (Backup Tier)
- **Purpose**: Fallback to Ubuntu official archives
- **Nodes**: 2
- **Features**:
  - Transparent proxy to ubuntu.com
  - Activated only when both Aptly nodes fail
  - GPG key serving
  - No local storage required

## 📊 Technical Specifications

### Network Configuration

| Component | IP Address | Role |
|-----------|------------|------|
| VIP | 10.80.11.140 | Client entry point |
| haproxy-master | 10.80.11.141 | Primary load balancer |
| haproxy-backup | 10.80.11.142 | Secondary load balancer |
| aptly-01 | 10.80.11.143 | Primary mirror |
| aptly-02 | 10.80.11.144 | Secondary mirror |
| proxy-01 | 10.80.11.145 | Backup proxy |
| proxy-02 | 10.80.11.146 | Backup proxy |

### System Requirements

#### HAProxy Nodes
- **CPU**: 2 cores
- **RAM**: 2GB
- **Disk**: 20GB
- **OS**: Ubuntu 22.04 LTS

#### Aptly Nodes
- **CPU**: 4 cores (recommended)
- **RAM**: 8GB minimum
- **Disk**: 150GB (SSD recommended)
- **OS**: Ubuntu 22.04 LTS

#### Proxy Nodes
- **CPU**: 2 cores
- **RAM**: 2GB
- **Disk**: 20GB
- **OS**: Ubuntu 22.04 LTS

### Software Versions

- **Aptly**: 1.6.2
- **HAProxy**: Latest from Ubuntu 22.04
- **Keepalived**: Latest from Ubuntu 22.04
- **Nginx**: Latest from Ubuntu 22.04
- **Ubuntu Mirror**: 22.04 LTS (Jammy)

## 🔄 Automated Operations

### Daily Tasks (via cron)

**06:00 AM** - Repository Update
- Sync mirrors from upstream
- Create new snapshots
- Publish updated repository
- Log: `/var/log/aptly-update.log`

**07:00 AM** - Cleanup
- Remove old snapshots (keeps last 2)
- Free disk space
- Log: `/var/log/aptly-cleanup.log`

### Supported Components

- `jammy` (main, universe)
- `jammy-updates` (main, universe)
- `jammy-security` (main, universe)

### Architecture Support

- `amd64` (x86_64)

## 🛡️ High Availability Features

### Multi-Tier Failover

1. **Tier 1 Active**: Both Aptly nodes serve traffic (load balanced)
2. **Tier 1 Degraded**: One Aptly node down → Traffic to remaining node
3. **Tier 2 Active**: Both Aptly nodes down → Proxy nodes serve from Ubuntu official

### Redundancy Levels

- **Load Balancer**: Active/Passive (Master + Backup)
- **Aptly Tier**: Active/Active (Both serving)
- **Proxy Tier**: Active/Active (Backup tier)
- **Virtual IP**: Floating (VRRP managed)

### Health Checks

- **HAProxy → Backends**: Every 5 seconds
- **Keepalived → HAProxy**: Every 2 seconds
- **Expected Uptime**: 99.9%+

## 📝 Client Configuration

### Dual Keyring Support

Clients use both GPG keys for seamless failover:

```bash
deb [signed-by=/usr/share/keyrings/aptly-custom-keyring.gpg,/usr/share/keyrings/ubuntu-archive-keyring.gpg] \
    http://ubuntu.yourdomain.com jammy main universe
```

**Why both keys?**
- Aptly nodes sign packages with custom key
- Proxy nodes serve Ubuntu-signed packages
- Dual keyring allows failover without client reconfiguration

### Automated Client Setup

```bash
wget http://ubuntu.yourdomain.com/configure-apt-client.sh
sudo ./configure-apt-client.sh
```

This script:
- Downloads both GPG keys
- Configures `/etc/apt/sources.list`
- Enables release info changes
- Updates package lists

## 🔧 Maintenance

### Common Operations

```bash
# Manual repository update
sudo -u aptly /home/aptly/aptly-daily-update.sh

# View snapshots
sudo -u aptly aptly snapshot list

# Revert to previous snapshot
DATE=20251110
sudo -u aptly aptly publish switch jammy jammy-${DATE}-merged

# Check cluster health
curl http://10.80.11.140:8080/stats -u admin:changeme123

# Monitor logs
tail -f /var/log/aptly-update.log
tail -f /var/log/nginx/aptly-access.log
```

### Monitoring

**HAProxy Statistics**
- URL: `http://10.80.11.140:8080/stats`
- Username: `admin`
- Password: `changeme123` (change in production!)

**Logs**
- Aptly updates: `/var/log/aptly-update.log`
- Aptly cleanup: `/var/log/aptly-cleanup.log`
- Nginx access: `/var/log/nginx/aptly-access.log`
- Nginx errors: `/var/log/nginx/aptly-error.log`

## 🧪 Testing Failover

### Test 1: Single Aptly Node Failure

```bash
# Stop one Aptly node
ssh root@10.80.11.143 'systemctl stop nginx'

# Verify clients still work
apt-get update

# Check HAProxy shows node DOWN
curl http://10.80.11.140:8080/stats -u admin:changeme123

# Restore
ssh root@10.80.11.143 'systemctl start nginx'
```

### Test 2: Complete Aptly Failure

```bash
# Stop both Aptly nodes
ssh root@10.80.11.143 'systemctl stop nginx'
ssh root@10.80.11.144 'systemctl stop nginx'

# Verify proxy nodes take over
apt-get update
# Should still work via proxy

# Restore
ssh root@10.80.11.143 'systemctl start nginx'
ssh root@10.80.11.144 'systemctl start nginx'
```

### Test 3: HAProxy Failover

```bash
# Stop master HAProxy
ssh root@10.80.11.141 'systemctl stop haproxy'

# VIP should move to backup (takes ~3 seconds)
# Verify clients still work
apt-get update

# Restore
ssh root@10.80.11.141 'systemctl start haproxy'
```

## 📚 Documentation

| Document | Purpose |
|----------|---------|
| [README.md](README.md) | Project overview |
| [docs/ha-cluster-setup.md](docs/ha-cluster-setup.md) | Complete HA deployment guide |
| [docs/client-setup.md](docs/client-setup.md) | Client configuration |
| [docs/troubleshooting.md](docs/troubleshooting.md) | Problem solving |
| [standalone/README.md](standalone/README.md) | Single-node deployment |
| [CONTRIBUTING.md](CONTRIBUTING.md) | How to contribute |

## 🤝 Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md).

## 📄 License

MIT License - see [LICENSE](LICENSE) file.

## 🙏 Credits

Built with:
- [Aptly](https://www.aptly.info/) - Debian repository management
- [HAProxy](http://www.haproxy.org/) - Load balancer
- [Keepalived](https://www.keepalived.org/) - VRRP implementation
- [Nginx](https://nginx.org/) - Web server and proxy

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/TazoTandilashvili/aptly-ha-cluster/issues)
- **Documentation**: Full docs in `docs/` directory
- **Email**: support@yourdomain.com

## 🗺️ Roadmap

Future enhancements:

- [ ] Ubuntu 24.04 (Noble) support
- [ ] Debian repository support
- [ ] Ansible automation
- [ ] Docker containers
- [ ] Prometheus monitoring
- [ ] Grafana dashboards
- [ ] IPv6 support
- [ ] SSL/TLS configuration
- [ ] Custom package repository
- [ ] Webhook notifications

## ⚡ Quick Commands

```bash
# Clone repository
git clone https://github.com/TazoTandilashvili/aptly-ha-cluster.git

# Standalone deployment
cd aptly-ha-cluster/standalone && sudo ./deploy.sh

# View HA setup guide
cd aptly-ha-cluster && cat docs/ha-cluster-setup.md

# Check configuration examples
ls -l config/*.example

# Test deployment
curl -I http://10.80.11.140/dists/jammy/Release
```

---

**Built with ❤️ for DevOps and System Administrators**

**Last Updated**: November 14, 2025
