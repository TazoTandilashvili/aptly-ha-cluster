# High Availability Cluster Setup Guide

This guide walks you through deploying a complete 7-node High Availability Ubuntu repository cluster.

## Architecture Components

The HA cluster consists of:

1. **HAProxy Layer** (2 nodes)
   - Load balancing
   - Health checking
   - VIP management via Keepalived

2. **Aptly Layer** (2 nodes)
   - Local Ubuntu mirrors
   - Package signing
   - Primary serving tier

3. **Proxy Layer** (2 nodes)
   - Fallback to Ubuntu official archives
   - Backup serving tier

## Prerequisites

### Hardware Requirements

| Node Type | CPU | RAM | Disk | Network |
|-----------|-----|-----|------|---------|
| HAProxy | 2 cores | 2GB | 20GB | 1Gbps |
| Aptly | 4 cores | 8GB | 150GB | 1Gbps |
| Proxy | 2 cores | 2GB | 20GB | 1Gbps |

### Software Requirements

- Ubuntu 22.04 LTS on all nodes
- Root access to all servers
- Network connectivity between all nodes
- DNS configured: `ubuntu.yourdomain.com` → `10.80.11.140` (VIP)

### Network Configuration

| Server | IP Address | Role |
|--------|------------|------|
| VIP | 10.80.11.140 | Virtual IP (floating) |
| haproxy-01 | 10.80.11.141 | HAProxy Master |
| haproxy-02 | 10.80.11.142 | HAProxy Backup |
| aptly-01 | 10.80.11.143 | Aptly Primary |
| aptly-02 | 10.80.11.144 | Aptly Secondary |
| proxy-01 | 10.80.11.145 | Proxy Primary |
| proxy-02 | 10.80.11.146 | Proxy Secondary |

## Deployment Steps

### Step 1: Prepare Configuration

```bash
# Clone repository
git clone https://github.com/TazoTandilashvili/aptly-ha-cluster.git
cd aptly-ha-cluster

# Copy and edit configuration
cp config/cluster.conf.example config/cluster.conf
vim config/cluster.conf
```

Update the IP addresses and domain to match your environment.

### Step 2: Deploy HAProxy Nodes

#### HAProxy Master (10.80.11.141)

```bash
# SSH to master node
ssh root@10.80.11.141

# Install packages
apt-get update
apt-get install -y haproxy keepalived

# Copy HAProxy configuration
cat > /etc/haproxy/haproxy.cfg <<'EOF'
[paste content from config/haproxy.cfg.example]
EOF

# Configure Keepalived (Master)
cat > /etc/keepalived/keepalived.conf <<'EOF'
global_defs {
}

vrrp_script chk_haproxy {
    script "killall -0 haproxy"
    interval 2
    weight 2
}

vrrp_instance VI_1 {
    state MASTER
    interface ens160
    virtual_router_id 51
    priority 101
    unicast_src_ip 10.80.11.141
    unicast_peer {
        10.80.11.142
    }
    authentication {
        auth_type PASS
        auth_pass 1qaz!QAZ
    }
    virtual_ipaddress {
        10.80.11.140/24
    }
    track_script {
        chk_haproxy
    }
}
EOF

# Enable and start services
systemctl enable haproxy keepalived
systemctl start haproxy keepalived

# Verify VIP is assigned
ip addr show ens160 | grep 10.80.11.140
```

#### HAProxy Backup (10.80.11.142)

```bash
# SSH to backup node
ssh root@10.80.11.142

# Install packages
apt-get update
apt-get install -y haproxy keepalived

# Copy same HAProxy configuration as master
cat > /etc/haproxy/haproxy.cfg <<'EOF'
[paste same content as master]
EOF

# Configure Keepalived (Backup)
cat > /etc/keepalived/keepalived.conf <<'EOF'
global_defs {
}

vrrp_script chk_haproxy {
    script "killall -0 haproxy"
    interval 2
    weight 2
}

vrrp_instance VI_1 {
    state BACKUP
    interface ens160
    virtual_router_id 51
    priority 100
    unicast_src_ip 10.80.11.142
    unicast_peer {
        10.80.11.141
    }
    authentication {
        auth_type PASS
        auth_pass 1qaz!QAZ
    }
    virtual_ipaddress {
        10.80.11.140/24
    }
    track_script {
        chk_haproxy
    }
}
EOF

# Enable and start services
systemctl enable haproxy keepalived
systemctl start haproxy keepalived

# Verify VIP is NOT on backup (should be on master)
ip addr show ens160 | grep 10.80.11.140
```

### Step 3: Deploy Aptly Nodes

#### Aptly Node 1 (10.80.11.143)

```bash
# SSH to aptly node
ssh root@10.80.11.143

# Use the deployment script from standalone
cd /tmp
git clone https://github.com/TazoTandilashvili/aptly-ha-cluster.git
cd aptly-ha-cluster/standalone

# Edit domain if needed
export DOMAIN="ubuntu.yourdomain.com"

# Run deployment
./deploy.sh
```

The script will:
- Install Aptly and Nginx
- Generate GPG keys
- Create mirrors
- Sync packages (takes 2-4 hours)
- Configure Nginx
- Setup cron jobs

#### Aptly Node 2 (10.80.11.144)

Option A: Full deployment (recommended for independence)
```bash
# Repeat same steps as Node 1
ssh root@10.80.11.144
[run same deployment]
```

Option B: Copy from Node 1 (faster, requires sync later)
```bash
# On Node 1, create backup
sudo -u aptly tar czf /tmp/aptly-backup.tar.gz /var/aptly /etc/aptly.conf

# Transfer to Node 2
scp /tmp/aptly-backup.tar.gz root@10.80.11.144:/tmp/

# On Node 2, restore
tar xzf /tmp/aptly-backup.tar.gz -C /
chown -R aptly:aptly /var/aptly

# Install packages
apt-get install -y nginx
[copy nginx config from Node 1]
```

### Step 4: Deploy Proxy Nodes

#### Proxy Node 1 (10.80.11.145)

```bash
# SSH to proxy node
ssh root@10.80.11.145

# Install Nginx
apt-get update
apt-get install -y nginx

# Configure Nginx proxy
cat > /etc/nginx/sites-available/ubuntu-proxy <<'EOF'
server {
    listen 80;
    server_name _;
    
    access_log /var/log/nginx/ubuntu-proxy-access.log;
    error_log /var/log/nginx/ubuntu-proxy-error.log;
    
    # Health check
    location /health {
        access_log off;
        return 200 "OK\n";
        add_header Content-Type text/plain;
    }
    
    # Ubuntu official GPG key
    location = /repo-key.gpg {
        proxy_pass http://ge.archive.ubuntu.com/ubuntu/project/ubuntu-archive-keyring.gpg;
        proxy_set_header Host ge.archive.ubuntu.com;
    }
    
    location /ubuntu-official-keyring.gpg {
        proxy_pass http://ge.archive.ubuntu.com/ubuntu/project/ubuntu-archive-keyring.gpg;
        proxy_set_header Host ge.archive.ubuntu.com;
    }
    
    # Distribution metadata
    location ~ ^/dists/(jammy|jammy-updates|jammy-security)/ {
        proxy_pass http://ge.archive.ubuntu.com/ubuntu$request_uri;
        proxy_set_header Host ge.archive.ubuntu.com;
        proxy_buffering on;
        proxy_connect_timeout 30s;
        proxy_read_timeout 60s;
    }
    
    # Package pools
    location /pool/ {
        proxy_pass http://ge.archive.ubuntu.com/ubuntu/pool/;
        proxy_set_header Host ge.archive.ubuntu.com;
        proxy_buffering on;
    }
    
    # Catch-all
    location / {
        proxy_pass http://ge.archive.ubuntu.com/ubuntu/;
        proxy_set_header Host ge.archive.ubuntu.com;
    }
}
EOF

# Enable site
ln -sf /etc/nginx/sites-available/ubuntu-proxy /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Test and start
nginx -t
systemctl enable nginx
systemctl restart nginx

# Verify
curl http://localhost/health
```

#### Proxy Node 2 (10.80.11.146)

```bash
# Copy configuration from Proxy Node 1
scp root@10.80.11.145:/etc/nginx/sites-available/ubuntu-proxy /etc/nginx/sites-available/

# Enable and start
ln -sf /etc/nginx/sites-available/ubuntu-proxy /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl enable nginx
systemctl restart nginx
```

### Step 5: Verification

#### Check HAProxy

```bash
# Check VIP
curl -I http://10.80.11.140/dists/jammy/Release

# Check HAProxy stats
curl http://10.80.11.140:8080/stats -u admin:changeme123

# Expected: All backends showing UP/green
```

#### Check Individual Backends

```bash
# Test Aptly nodes
curl -I http://10.80.11.143/dists/jammy/Release
curl -I http://10.80.11.144/dists/jammy/Release

# Test Proxy nodes
curl -I http://10.80.11.145/dists/jammy/Release
curl -I http://10.80.11.146/dists/jammy/Release

# All should return: HTTP/1.1 200 OK
```

#### Check GPG Keys

```bash
# Aptly custom keys
curl -s http://10.80.11.143/repo-key.gpg | wc -c
# Should show ~1400 bytes

# Ubuntu official keys via proxy
curl -s http://10.80.11.145/ubuntu-official-keyring.gpg | wc -c
# Should show ~3600 bytes
```

### Step 6: Client Configuration

Create the client configuration script on both Aptly nodes:

```bash
cat > /var/aptly/public/configure-apt-client.sh <<'EOF'
#!/bin/bash
set -e

REPO_URL="http://ubuntu.yourdomain.com"

echo "Configuring APT for HA repository..."

# Install dependencies
apt-get update >/dev/null 2>&1 || true
apt-get install -y gnupg wget ca-certificates

# Backup sources.list
if [ -f /etc/apt/sources.list ]; then
    cp /etc/apt/sources.list /etc/apt/sources.list.backup.$(date +%Y%m%d)
fi

# Download both keys
wget -q $REPO_URL/repo-key.gpg -O /tmp/aptly-key.gpg
wget -q $REPO_URL/ubuntu-official-keyring.gpg -O /tmp/ubuntu-key.gpg

# Install keys
gpg --dearmor < /tmp/aptly-key.gpg > /usr/share/keyrings/aptly-custom-keyring.gpg
gpg --dearmor < /tmp/ubuntu-key.gpg > /usr/share/keyrings/ubuntu-archive-keyring.gpg

# Configure APT
cat > /etc/apt/apt.conf.d/99allow-release-info-change <<'APTCONF'
Acquire::AllowReleaseInfoChange "true";
APTCONF

# Configure sources with dual keyring
cat > /etc/apt/sources.list <<'SOURCES'
deb [signed-by=/usr/share/keyrings/aptly-custom-keyring.gpg,/usr/share/keyrings/ubuntu-archive-keyring.gpg] http://ubuntu.yourdomain.com jammy main universe
deb [signed-by=/usr/share/keyrings/aptly-custom-keyring.gpg,/usr/share/keyrings/ubuntu-archive-keyring.gpg] http://ubuntu.yourdomain.com jammy-updates main universe
deb [signed-by=/usr/share/keyrings/aptly-custom-keyring.gpg,/usr/share/keyrings/ubuntu-archive-keyring.gpg] http://ubuntu.yourdomain.com jammy-security main universe
SOURCES

# Update
apt-get clean
rm -rf /var/lib/apt/lists/*
apt-get update

echo "✅ Configuration complete!"
EOF

chmod +x /var/aptly/public/configure-apt-client.sh
```

On client machines:

```bash
wget http://ubuntu.yourdomain.com/configure-apt-client.sh
chmod +x configure-apt-client.sh
sudo ./configure-apt-client.sh
```

## Failover Testing

### Test 1: Aptly Node Failure

```bash
# Stop one Aptly node
ssh root@10.80.11.143 'systemctl stop nginx'

# Verify traffic goes to other Aptly node
curl http://10.80.11.140/dists/jammy/Release

# Check HAProxy stats - node1-aptly should show DOWN
curl -s http://10.80.11.140:8080/stats | grep aptly

# Restore
ssh root@10.80.11.143 'systemctl start nginx'
```

### Test 2: Complete Aptly Failure (Proxy Fallback)

```bash
# Stop both Aptly nodes
ssh root@10.80.11.143 'systemctl stop nginx'
ssh root@10.80.11.144 'systemctl stop nginx'

# Verify traffic goes to proxy nodes
curl http://10.80.11.140/dists/jammy/Release

# Check HAProxy - proxy nodes should be active
curl -s http://10.80.11.140:8080/stats | grep proxy

# Restore Aptly nodes
ssh root@10.80.11.143 'systemctl start nginx'
ssh root@10.80.11.144 'systemctl start nginx'
```

### Test 3: HAProxy Failover

```bash
# Check VIP location
ssh root@10.80.11.141 'ip addr show ens160 | grep 10.80.11.140'

# Stop master HAProxy
ssh root@10.80.11.141 'systemctl stop haproxy'

# Wait 3 seconds for failover

# VIP should move to backup
ssh root@10.80.11.142 'ip addr show ens160 | grep 10.80.11.140'

# Test still works
curl http://10.80.11.140/dists/jammy/Release

# Restore master
ssh root@10.80.11.141 'systemctl start haproxy'
```

## Maintenance

### Daily Operations

The system runs automated tasks:
- **06:00 AM**: Repository update (mirrors sync, new snapshots)
- **07:00 AM**: Cleanup old snapshots (keeps last 2)

### Manual Update

```bash
# On any Aptly node
sudo -u aptly /home/aptly/aptly-daily-update.sh
```

### Rollback to Previous Snapshot

```bash
# List available snapshots
sudo -u aptly aptly snapshot list | grep merged

# Switch to specific date
sudo -u aptly aptly publish switch -skip-contents jammy jammy-YYYYMMDD-merged
```

### Monitoring

```bash
# Check logs
tail -f /var/log/aptly-update.log
tail -f /var/log/nginx/aptly-access.log

# Check HAProxy stats
curl http://10.80.11.140:8080/stats -u admin:changeme123

# Check disk usage
df -h /var/aptly
```

## Troubleshooting

### VIP Not Responding

```bash
# Check Keepalived on both HAProxy nodes
systemctl status keepalived

# Check logs
journalctl -u keepalived -f

# Verify VRRP traffic allowed (firewall)
iptables -L | grep VRRP
```

### GPG Signature Errors on Clients

```bash
# Re-run client configuration
wget http://ubuntu.yourdomain.com/configure-apt-client.sh
sudo ./configure-apt-client.sh

# Or manually verify keys
curl -I http://ubuntu.yourdomain.com/repo-key.gpg
curl -I http://ubuntu.yourdomain.com/ubuntu-official-keyring.gpg
```

### Aptly Mirror Sync Failed

```bash
# Check disk space
df -h /var/aptly

# Check connectivity
curl -I http://archive.ubuntu.com/ubuntu/dists/jammy/Release

# Check logs
tail -100 /var/log/aptly-update.log

# Manual sync
sudo -u aptly aptly mirror update jammy-main
```

### HAProxy All Backends DOWN

```bash
# Check health check endpoint
curl -I http://10.80.11.143/dists/jammy/Release
curl -I http://10.80.11.145/health

# Check backend services
ssh root@10.80.11.143 'systemctl status nginx'
ssh root@10.80.11.145 'systemctl status nginx'

# Check HAProxy logs
tail -f /var/log/haproxy.log
```

## Security Hardening

### Firewall Rules

```bash
# HAProxy nodes
ufw allow 80/tcp    # HTTP
ufw allow 8080/tcp  # Stats (restrict to internal)
ufw allow 22/tcp    # SSH
ufw enable

# Aptly/Proxy nodes
ufw allow 80/tcp    # HTTP
ufw allow 22/tcp    # SSH
ufw enable
```

### Change Default Passwords

```bash
# HAProxy stats password
vim /etc/haproxy/haproxy.cfg
# Change: stats auth admin:changeme123

# Keepalived VRRP password
vim /etc/keepalived/keepalived.conf
# Change: auth_pass 1qaz!QAZ
```

### SSL/TLS (Optional)

For HTTPS support, add certificate to HAProxy:

```bash
# Combine cert and key
cat cert.pem key.pem > /etc/haproxy/cert.pem

# Update HAProxy config
frontend ubuntu_repo
    bind *:443 ssl crt /etc/haproxy/cert.pem
    bind *:80
    redirect scheme https if !{ ssl_fc }
```

## Backup Strategy

### Aptly Data Backup

```bash
# Backup configuration and GPG keys
tar czf aptly-config-backup.tar.gz \
    /etc/aptly.conf \
    /home/aptly/.gnupg \
    /var/aptly/db

# Repository data (very large, selective backup)
sudo -u aptly aptly snapshot list > snapshots-list.txt
```

### Restore Procedure

```bash
# Restore configuration
tar xzf aptly-config-backup.tar.gz -C /

# Re-sync mirrors if needed
sudo -u aptly aptly mirror update jammy-main
```

## Performance Tuning

### Aptly Performance

```bash
# Increase download concurrency in /etc/aptly.conf
"downloadConcurrency": 8

# Use local mirror for faster sync
# Edit mirror URLs to use local/regional mirror
sudo -u aptly aptly mirror edit jammy-main
```

### Nginx Performance

```bash
# Enable caching in /etc/nginx/sites-available/aptly
proxy_cache_path /var/cache/nginx levels=1:2 keys_zone=aptly_cache:10m;

location / {
    proxy_cache aptly_cache;
    proxy_cache_valid 200 1h;
}
```

## Monitoring Integration

### Prometheus Metrics (Future Enhancement)

```bash
# HAProxy exporter
# Nginx exporter
# Custom Aptly metrics
```

## Conclusion

Your High Availability Aptly cluster is now complete and production-ready!

**Key Benefits:**
- 99.9%+ uptime
- Automatic failover at every layer
- Zero-downtime maintenance
- Bandwidth savings (local mirror)
- Control over package versions

**Next Steps:**
- Set up monitoring (Prometheus + Grafana)
- Configure backups
- Document your specific procedures
- Train team on failover procedures

For support, see [Troubleshooting Guide](troubleshooting.md) or open an issue on GitHub.
