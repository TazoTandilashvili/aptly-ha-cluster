# Aptly High Availability Ubuntu Repository Cluster

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-22.04%20LTS-orange.svg)](https://ubuntu.com)
[![Aptly](https://img.shields.io/badge/Aptly-1.6.2-blue.svg)](https://www.aptly.info/)

A production-ready, highly available Ubuntu package repository infrastructure using Aptly, HAProxy, Keepalived, and Nginx proxy fallback.

## 🏗️ Architecture Overview

```
                          ┌─────────────────┐
                          │   Virtual IP    │
                          │  10.80.11.140  │
                          └────────┬────────┘
                                   │
                    ┌──────────────┴──────────────┐
                    │                             │
          ┌─────────▼─────────┐       ┌──────────▼────────┐
          │  HAProxy Master   │       │  HAProxy Backup   │
          │  10.80.11.141    │◄─────►│  10.80.11.142    │
          └─────────┬─────────┘       └──────────┬────────┘
                    │                             │
          ┌─────────┴─────────────────────────────┴─────────┐
          │              Load Balancer Layer                │
          └──────┬───────────────────────────────┬───────────┘
                 │                               │
     ┌───────────▼──────────┐       ┌───────────▼──────────┐
     │   Tier 1: Aptly      │       │   Tier 2: Proxy      │
     │   Primary Servers    │       │   Backup Fallback    │
     └───────────┬──────────┘       └───────────┬──────────┘
                 │                               │
        ┌────────┴────────┐            ┌────────┴────────┐
        │                 │            │                 │
   ┌────▼────┐      ┌─────▼───┐  ┌────▼────┐      ┌─────▼───┐
   │ Aptly-1 │      │ Aptly-2 │  │ Proxy-1 │      │ Proxy-2 │
   │ .143    │      │ .144    │  │ .145    │      │ .146    │
   └─────────┘      └─────────┘  └─────────┘      └─────────┘
```

## ✨ Features

- **High Availability**: 99.9%+ uptime with automatic failover
- **Multi-Tier Architecture**: Aptly primary servers with proxy fallback
- **Load Balancing**: HAProxy with health checks and round-robin distribution
- **VRRP Failover**: Keepalived for Virtual IP management
- **Dual GPG Support**: Seamless switching between Aptly and Ubuntu official keys
- **Automated Updates**: Daily repository synchronization at 6:00 AM
- **Automatic Cleanup**: Retention of last 2 snapshots (configurable)
- **Zero-Downtime Maintenance**: Rolling updates without service interruption

## 📋 Prerequisites

- **7 Ubuntu 22.04 LTS servers** (or 1 for standalone deployment)
- Root access to all servers
- Network connectivity between all nodes
- DNS: `ubuntu.yourdomain.com` → `10.80.11.140` (VIP)
- ~150GB disk space per Aptly node
- Internet access for initial mirror sync

## 🚀 Quick Start

### Standalone Deployment (Single Node)

```bash
# Clone the repository
git clone https://github.com/TazoTandilashvili/aptly-ha-cluster.git
cd aptly-ha-cluster

# Run the standalone setup
cd standalone
sudo ./deploy.sh
```

### High Availability Cluster (7 Nodes)

```bash
# Clone the repository
git clone https://github.com/TazoTandilashvili/aptly-ha-cluster.git
cd aptly-ha-cluster

# Configure your environment
cp config/cluster.conf.example config/cluster.conf
vim config/cluster.conf

# Deploy the HA cluster
cd ha-cluster
sudo ./deploy-ha.sh
```

## 📚 Documentation

- **[Standalone Setup](docs/standalone-setup.md)** - Single node Aptly repository
- **[HA Cluster Setup](docs/ha-cluster-setup.md)** - Full 7-node HA configuration
- **[Configuration Guide](docs/configuration.md)** - Detailed configuration options
- **[Client Configuration](docs/client-setup.md)** - APT client setup instructions
- **[Maintenance Guide](docs/maintenance.md)** - Daily operations and troubleshooting
- **[Failover Testing](docs/failover-testing.md)** - Testing HA scenarios
- **[Troubleshooting](docs/troubleshooting.md)** - Common issues and solutions

## 🗂️ Repository Structure

```
aptly-ha-cluster/
├── README.md
├── LICENSE
├── docs/
│   ├── standalone-setup.md
│   ├── ha-cluster-setup.md
│   ├── configuration.md
│   ├── client-setup.md
│   ├── maintenance.md
│   ├── failover-testing.md
│   └── troubleshooting.md
├── config/
│   ├── cluster.conf.example
│   ├── aptly.conf.example
│   ├── haproxy.cfg.example
│   └── keepalived.conf.example
├── scripts/
│   ├── aptly/
│   │   ├── setup-aptly.sh
│   │   ├── daily-update.sh
│   │   ├── daily-cleanup.sh
│   │   └── create-gpg-key.sh
│   ├── haproxy/
│   │   ├── setup-haproxy.sh
│   │   └── configure-keepalived.sh
│   ├── proxy/
│   │   └── setup-nginx-proxy.sh
│   ├── client/
│   │   └── configure-apt-client.sh
│   └── common/
│       ├── verify-node.sh
│       └── health-check.sh
├── standalone/
│   ├── deploy.sh
│   └── README.md
└── ha-cluster/
    ├── deploy-ha.sh
    ├── deploy-node.sh
    └── README.md
```

## 🔧 Infrastructure Components

| Component | Count | Purpose |
|-----------|-------|---------|
| HAProxy + Keepalived | 2 | Load balancing and VIP management |
| Aptly Nodes | 2 | Primary Ubuntu package mirrors |
| Nginx Proxy | 2 | Fallback to Ubuntu official archives |
| Virtual IP | 1 | Single entry point (10.80.11.140) |

## 📊 System Requirements

### Aptly Nodes
- **CPU**: 4 cores
- **RAM**: 8GB
- **Disk**: 150GB (SSD recommended)
- **Network**: 1Gbps

### HAProxy Nodes
- **CPU**: 2 cores
- **RAM**: 2GB
- **Disk**: 20GB
- **Network**: 1Gbps

### Proxy Nodes
- **CPU**: 2 cores
- **RAM**: 2GB
- **Disk**: 20GB
- **Network**: 1Gbps

## ⚙️ Configuration

### Network Configuration

```bash
# Edit cluster configuration
vim config/cluster.conf
```

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

### Aptly Configuration

Supports Ubuntu 22.04 (Jammy) with the following components:
- `jammy` (main, universe)
- `jammy-updates` (main, universe)
- `jammy-security` (main, universe)

## 🎯 Deployment Options

### Option 1: Standalone (Development/Testing)
- Single Aptly node
- No load balancer
- Direct Nginx serving
- Setup time: ~4 hours (mostly sync)

### Option 2: High Availability (Production)
- Full 7-node cluster
- HAProxy load balancing
- Keepalived VRRP
- Nginx proxy fallback
- Setup time: ~6 hours

## 🧪 Testing

Run the verification suite:

```bash
# Test standalone deployment
cd standalone
./verify-deployment.sh

# Test HA cluster
cd ha-cluster
./verify-ha-cluster.sh

# Failover testing
./scripts/common/test-failover.sh
```

## 📈 Monitoring

Access HAProxy statistics:

```
http://10.80.11.140:8080/stats
Username: admin
Password: changeme123
```

## 🔄 Daily Operations

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

## 🛡️ Security Considerations

- GPG signing for all packages
- Nginx access restrictions
- HAProxy stats authentication
- VRRP authentication (PSK)
- Firewall rules recommended

## 🐛 Troubleshooting

Common issues and solutions:

| Issue | Solution |
|-------|----------|
| VIP not responding | Check Keepalived status |
| GPG signature errors | Re-run client configuration script |
| Mirror sync failed | Check disk space and internet connectivity |
| HAProxy backend DOWN | Verify service status on backend nodes |

See [Troubleshooting Guide](docs/troubleshooting.md) for detailed solutions.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 👥 Authors

- **Your Name** - Initial work

## 🙏 Acknowledgments

- [Aptly](https://www.aptly.info/) - Debian repository management tool
- [HAProxy](http://www.haproxy.org/) - Reliable, high performance load balancer
- [Keepalived](https://www.keepalived.org/) - Load balancing and high availability
- Ubuntu community for the excellent documentation

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/TazoTandilashvili/aptly-ha-cluster/issues)
- **Documentation**: [Wiki](https://github.com/TazoTandilashvili/aptly-ha-cluster/wiki)
- **Email**: support@yourdomain.com

## 🗺️ Roadmap

- [ ] Ubuntu 24.04 (Noble) support
- [ ] Debian repository support
- [ ] Ansible playbooks for automated deployment
- [ ] Docker containerization
- [ ] Prometheus monitoring integration
- [ ] Grafana dashboards
- [ ] Automated backup/restore procedures

---

**⭐ Star this repository if you find it helpful!**

**Last Updated**: November 14, 2025
