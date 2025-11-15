# Scripts Directory

Collection of utility scripts for managing the Aptly HA cluster.

## Directory Structure

```
scripts/
├── aptly/              # Aptly-specific scripts
├── haproxy/            # HAProxy and Keepalived scripts
├── proxy/              # Nginx proxy scripts
├── client/             # Client configuration scripts
└── common/             # Common utility scripts
```

## Aptly Scripts

### setup-aptly.sh
Install and configure Aptly on a single node.

```bash
sudo ./aptly/setup-aptly.sh
```

### create-gpg-key.sh
Generate GPG signing key for package signing.

```bash
sudo -u aptly ./aptly/create-gpg-key.sh
```

### daily-update.sh
Update mirrors and publish new snapshots (run via cron).

```bash
sudo -u aptly ./aptly/daily-update.sh
```

### daily-cleanup.sh
Remove old snapshots, keeping only recent ones (run via cron).

```bash
sudo -u aptly ./aptly/daily-cleanup.sh
```

## HAProxy Scripts

### setup-haproxy.sh
Install HAProxy.

```bash
sudo ./haproxy/setup-haproxy.sh
```

### configure-keepalived.sh
Install and configure Keepalived for VRRP.

```bash
sudo ./haproxy/configure-keepalived.sh [master|backup]
```

## Proxy Scripts

### setup-nginx-proxy.sh
Install and configure Nginx as a proxy to Ubuntu archives.

```bash
sudo ./proxy/setup-nginx-proxy.sh
```

## Client Scripts

### configure-apt-client.sh
Configure Ubuntu client to use the Aptly HA repository.

```bash
# On client machine
wget http://ubuntu.yourdomain.com/configure-apt-client.sh
sudo ./configure-apt-client.sh
```

Or with custom settings:

```bash
REPO_URL="http://ubuntu.yourdomain.com" \
REPO_VIP="10.80.11.140" \
sudo ./client/configure-apt-client.sh
```

## Common Scripts

### verify-node.sh
Verify a single node is properly configured.

```bash
./common/verify-node.sh 10.80.11.143 aptly
./common/verify-node.sh 10.80.11.141 haproxy
./common/verify-node.sh 10.80.11.145 proxy
```

### health-check.sh
Quick health check for all cluster components.

```bash
./common/health-check.sh
# or with custom VIP
./common/health-check.sh 10.80.11.140
```

## Usage Patterns

### Manual Node-by-Node Deployment

Instead of using the automated `ha-cluster/deploy-ha.sh`, you can deploy manually:

```bash
# HAProxy nodes
ssh root@10.80.11.141
./scripts/haproxy/setup-haproxy.sh
./scripts/haproxy/configure-keepalived.sh master
# Copy config from config/haproxy.cfg.example
# Copy config from config/keepalived-master.conf.example

# Aptly nodes
ssh root@10.80.11.143
./scripts/aptly/setup-aptly.sh
./scripts/aptly/create-gpg-key.sh
# Configure mirrors and publish

# Proxy nodes
ssh root@10.80.11.145
./scripts/proxy/setup-nginx-proxy.sh
```

### Verification

```bash
# Verify each node
./scripts/common/verify-node.sh 10.80.11.141 haproxy
./scripts/common/verify-node.sh 10.80.11.143 aptly
./scripts/common/verify-node.sh 10.80.11.145 proxy

# Quick health check
./scripts/common/health-check.sh
```

### Maintenance

```bash
# Manual update on Aptly node
ssh root@10.80.11.143
sudo -u aptly /home/aptly/scripts/aptly/daily-update.sh

# Manual cleanup
sudo -u aptly /home/aptly/scripts/aptly/daily-cleanup.sh
```

## Script Permissions

All scripts should be executable:

```bash
chmod +x scripts/*/*.sh
```

## Notes

- **Aptly scripts** should be run as the `aptly` user
- **HAProxy/Proxy scripts** require root privileges
- **Client script** should be run as root on client machines
- **Common scripts** can be run by any user with appropriate access

## Integration with Automated Deployment

These scripts are used internally by `ha-cluster/deploy-ha.sh` but can also be used independently for:

- Manual deployments
- Troubleshooting
- Custom automation
- Step-by-step learning

## Customization

Most scripts use configuration from:
- Environment variables
- `config/cluster.conf`
- Inline configuration sections

Edit the scripts directly or provide environment variables to customize behavior.
