# Troubleshooting Guide

Common issues and their solutions for the Aptly HA Cluster.

## Quick Diagnostic Commands

```bash
# Check all services status
for host in 10.80.11.141 10.80.11.142; do
  echo "=== HAProxy $host ==="
  ssh root@$host "systemctl status haproxy keepalived"
done

for host in 10.80.11.143 10.80.11.144; do
  echo "=== Aptly $host ==="
  ssh root@$host "systemctl status nginx"
done

for host in 10.80.11.145 10.80.11.146; do
  echo "=== Proxy $host ==="
  ssh root@$host "systemctl status nginx"
done

# Check VIP location
ssh root@10.80.11.141 "ip addr show ens160 | grep 10.80.11.140" && echo "VIP on Master" || \
ssh root@10.80.11.142 "ip addr show ens160 | grep 10.80.11.140" && echo "VIP on Backup"

# Check HAProxy backend status
curl -s http://10.80.11.140:8080/stats | grep -E "aptly|proxy"
```

---

## HAProxy Issues

### Issue: VIP Not Responding

**Symptoms:**
- Cannot reach http://10.80.11.140
- Ping fails to VIP
- Clients cannot update packages

**Diagnosis:**
```bash
# Check if VIP is assigned anywhere
ssh root@10.80.11.141 "ip addr | grep 10.80.11.140"
ssh root@10.80.11.142 "ip addr | grep 10.80.11.140"

# Check Keepalived status
ssh root@10.80.11.141 "systemctl status keepalived"
ssh root@10.80.11.142 "systemctl status keepalived"

# Check Keepalived logs
ssh root@10.80.11.141 "journalctl -u keepalived -n 50"
```

**Solutions:**

1. **Keepalived not running:**
   ```bash
   systemctl start keepalived
   systemctl enable keepalived
   ```

2. **Both nodes in BACKUP state:**
   ```bash
   # On master node
   vim /etc/keepalived/keepalived.conf
   # Ensure: state MASTER, priority 101
   
   systemctl restart keepalived
   ```

3. **Firewall blocking VRRP:**
   ```bash
   # Allow VRRP protocol (IP protocol 112)
   iptables -A INPUT -p vrrp -j ACCEPT
   ufw allow proto vrrp
   ```

4. **Network issue between nodes:**
   ```bash
   # Test connectivity
   ping 10.80.11.142  # from master
   ping 10.80.11.141  # from backup
   ```

### Issue: HAProxy All Backends DOWN

**Symptoms:**
- HAProxy stats show all backends red/DOWN
- 503 Service Unavailable errors

**Diagnosis:**
```bash
# Check HAProxy stats
curl http://10.80.11.140:8080/stats -u admin:changeme123

# Test backends directly
curl -I http://10.80.11.143/dists/jammy/Release
curl -I http://10.80.11.144/dists/jammy/Release
curl -I http://10.80.11.145/dists/jammy/Release
curl -I http://10.80.11.146/dists/jammy/Release

# Check HAProxy health checks
tail -f /var/log/haproxy.log
```

**Solutions:**

1. **All backend services down:**
   ```bash
   # Start Aptly nodes
   ssh root@10.80.11.143 "systemctl start nginx"
   ssh root@10.80.11.144 "systemctl start nginx"
   ```

2. **Health check endpoint missing:**
   ```bash
   # Verify health check path exists
   curl -I http://10.80.11.143/dists/jammy/Release
   
   # Should return 200 OK
   ```

3. **Wrong health check configuration:**
   ```bash
   vim /etc/haproxy/haproxy.cfg
   
   # Verify:
   option httpchk GET /dists/jammy/Release
   http-check expect status 200
   
   systemctl restart haproxy
   ```

4. **Firewall blocking health checks:**
   ```bash
   # On backend nodes
   ufw allow from 10.80.11.141 to any port 80
   ufw allow from 10.80.11.142 to any port 80
   ```

---

## Aptly Node Issues

### Issue: Aptly Mirror Sync Failed

**Symptoms:**
- Daily update script fails
- Logs show mirror update errors
- Old packages in repository

**Diagnosis:**
```bash
# Check logs
tail -100 /var/log/aptly-update.log

# Check disk space
df -h /var/aptly

# Test upstream connectivity
curl -I http://archive.ubuntu.com/ubuntu/dists/jammy/Release

# Check mirrors
sudo -u aptly aptly mirror list
sudo -u aptly aptly mirror show jammy-main
```

**Solutions:**

1. **Insufficient disk space:**
   ```bash
   # Clean old snapshots
   sudo -u aptly /home/aptly/aptly-cleanup-daily.sh
   
   # Or manually drop old snapshots
   sudo -u aptly aptly snapshot list
   sudo -u aptly aptly snapshot drop <old-snapshot-name>
   ```

2. **Network/connectivity issue:**
   ```bash
   # Change to faster mirror
   sudo -u aptly aptly mirror edit jammy-main
   # Update URL to local mirror: http://ge.archive.ubuntu.com/ubuntu
   
   # Test connectivity
   curl -I http://ge.archive.ubuntu.com/ubuntu/dists/jammy/Release
   ```

3. **GPG verification failure:**
   ```bash
   # Update Ubuntu keyring
   sudo -u aptly gpg --keyserver keyserver.ubuntu.com --recv-keys <KEY-ID>
   
   # Or disable verification temporarily (not recommended)
   # "gpgDisableVerify": true in /etc/aptly.conf
   ```

4. **Mirror locked (another update running):**
   ```bash
   # Check for running update process
   ps aux | grep aptly
   
   # If stuck, kill and retry
   pkill -f "aptly mirror update"
   sudo -u aptly aptly mirror update jammy-main
   ```

### Issue: GPG Signing Errors

**Symptoms:**
- Cannot publish snapshots
- Errors mentioning GPG key
- Unsigned packages

**Diagnosis:**
```bash
# Check GPG key
sudo -u aptly gpg --list-keys

# Verify key ID in config matches
cat /etc/aptly.conf | grep gpgKey

# Test signing
sudo -u aptly gpg --clearsign <<< "test"
```

**Solutions:**

1. **GPG key mismatch:**
   ```bash
   # Get correct key ID
   KEY_ID=$(sudo -u aptly gpg --list-keys --keyid-format LONG | grep -A 1 "pub" | tail -1 | awk '{print $1}')
   
   # Update config
   vim /etc/aptly.conf
   # Set: "gpgKey": "$KEY_ID"
   ```

2. **GPG key expired:**
   ```bash
   # Extend expiration
   sudo -u aptly gpg --edit-key <KEY-ID>
   gpg> expire
   gpg> save
   
   # Re-export public key
   sudo -u aptly gpg --armor --export > /var/aptly/public/repo-key.gpg
   ```

3. **Missing GPG key:**
   ```bash
   # Regenerate key
   sudo -u aptly gpg --quick-generate-key "Aptly Repository <aptly@yourdomain.local>" rsa3072 sign 2y
   
   # Update config with new key ID
   # Re-export and redistribute to clients
   ```

### Issue: Nginx Not Serving Repository

**Symptoms:**
- 404 errors accessing repository
- Cannot download packages
- Directory listing shows empty

**Diagnosis:**
```bash
# Check Nginx status
systemctl status nginx

# Check Nginx config
nginx -t

# Check repository files
ls -lh /var/aptly/public/dists/jammy/

# Check Nginx error log
tail -50 /var/log/nginx/aptly-error.log
```

**Solutions:**

1. **Repository not published:**
   ```bash
   # Check published repos
   sudo -u aptly aptly publish list
   
   # If empty, publish latest snapshot
   DATE=$(date +%Y%m%d)
   sudo -u aptly aptly publish snapshot -skip-contents -distribution=jammy jammy-${DATE}-merged
   ```

2. **Wrong document root:**
   ```bash
   vim /etc/nginx/sites-available/aptly
   # Verify: root /var/aptly/public;
   
   systemctl restart nginx
   ```

3. **Permission issues:**
   ```bash
   # Fix permissions
   chown -R aptly:aptly /var/aptly
   chmod -R 755 /var/aptly/public
   ```

4. **Nginx misconfiguration:**
   ```bash
   # Restore working config
   cp /etc/nginx/sites-available/aptly /etc/nginx/sites-available/aptly.backup
   
   # Copy from working node
   scp root@10.80.11.143:/etc/nginx/sites-available/aptly /etc/nginx/sites-available/
   
   nginx -t && systemctl restart nginx
   ```

---

## Proxy Node Issues

### Issue: Proxy Returns 502/504 Errors

**Symptoms:**
- Intermittent 502 Bad Gateway or 504 Gateway Timeout
- Slow package downloads when on proxy

**Diagnosis:**
```bash
# Check Nginx status
systemctl status nginx

# Test upstream
curl -I http://ge.archive.ubuntu.com/ubuntu/dists/jammy/Release

# Check Nginx error log
tail -50 /var/log/nginx/ubuntu-proxy-error.log

# Check timeouts
grep timeout /etc/nginx/sites-available/ubuntu-proxy
```

**Solutions:**

1. **Upstream Ubuntu mirrors slow/down:**
   ```bash
   # Change to faster mirror
   vim /etc/nginx/sites-available/ubuntu-proxy
   # Change: ge.archive.ubuntu.com → archive.ubuntu.com
   # Or: archive.ubuntu.com → mirrors.edge.kernel.org
   
   systemctl restart nginx
   ```

2. **Increase timeouts:**
   ```bash
   vim /etc/nginx/sites-available/ubuntu-proxy
   
   # Add/update:
   proxy_connect_timeout 60s;
   proxy_read_timeout 120s;
   proxy_send_timeout 60s;
   
   systemctl restart nginx
   ```

3. **DNS resolution issues:**
   ```bash
   # Test DNS
   nslookup ge.archive.ubuntu.com
   
   # Use Google DNS if needed
   echo "nameserver 8.8.8.8" > /etc/resolv.conf
   ```

### Issue: Missing GPG Keys on Proxy

**Symptoms:**
- Clients get GPG errors when proxy is active
- Cannot verify package signatures

**Diagnosis:**
```bash
# Check key endpoints
curl -I http://10.80.11.145/repo-key.gpg
curl -I http://10.80.11.145/ubuntu-official-keyring.gpg

# Check Nginx config
grep keyring /etc/nginx/sites-available/ubuntu-proxy
```

**Solutions:**

1. **Add GPG key proxying:**
   ```bash
   vim /etc/nginx/sites-available/ubuntu-proxy
   
   # Add:
   location = /repo-key.gpg {
       proxy_pass http://ge.archive.ubuntu.com/ubuntu/project/ubuntu-archive-keyring.gpg;
   }
   
   location /ubuntu-official-keyring.gpg {
       proxy_pass http://ge.archive.ubuntu.com/ubuntu/project/ubuntu-archive-keyring.gpg;
   }
   
   systemctl restart nginx
   ```

2. **Verify keys are accessible:**
   ```bash
   curl -I http://10.80.11.145/ubuntu-official-keyring.gpg
   # Should return: HTTP/1.1 200 OK
   ```

---

## Client Issues

### Issue: GPG Signature Verification Errors

**Symptoms:**
```
The following signatures couldn't be verified because the public key is not available
NO_PUBKEY XXXXXXXXXXXXXXXX
```

**Diagnosis:**
```bash
# Check which keys are installed
ls -lh /usr/share/keyrings/

# Check sources.list
cat /etc/apt/sources.list | grep signed-by

# Test key download
curl -I http://ubuntu.yourdomain.com/repo-key.gpg
```

**Solutions:**

1. **Missing or corrupted keys:**
   ```bash
   # Re-run client configuration
   wget http://ubuntu.yourdomain.com/configure-apt-client.sh
   chmod +x configure-apt-client.sh
   sudo ./configure-apt-client.sh
   ```

2. **Wrong key format:**
   ```bash
   # Convert ASCII-armored to binary
   gpg --dearmor < /tmp/repo-key.gpg > /usr/share/keyrings/aptly-custom-keyring.gpg
   ```

3. **Key mismatch after repository update:**
   ```bash
   # Download fresh keys
   wget http://ubuntu.yourdomain.com/repo-key.gpg -O /tmp/new-key.gpg
   sudo gpg --dearmor < /tmp/new-key.gpg > /usr/share/keyrings/aptly-custom-keyring.gpg
   sudo apt-get update
   ```

### Issue: apt-get update Slow or Hanging

**Symptoms:**
- apt-get update takes very long
- Hangs on "Waiting for headers"
- Timeouts during package downloads

**Diagnosis:**
```bash
# Test repository connectivity
curl -I http://ubuntu.yourdomain.com/dists/jammy/Release

# Test with verbose
apt-get update -o Debug::Acquire::http=true

# Check which backend is serving
curl -v http://ubuntu.yourdomain.com/dists/jammy/Release 2>&1 | grep -i server
```

**Solutions:**

1. **Proxy nodes active (slower than Aptly):**
   ```bash
   # Check HAProxy stats
   curl http://ubuntu.yourdomain.com:8080/stats -u admin:changeme123
   
   # If Aptly nodes are down, restart them
   ssh root@10.80.11.143 "systemctl restart nginx"
   ```

2. **Network issues:**
   ```bash
   # Test latency
   ping ubuntu.yourdomain.com
   
   # Traceroute
   traceroute ubuntu.yourdomain.com
   
   # Try using IP directly
   sudo sed -i 's/ubuntu.yourdomain.com/10.80.11.140/g' /etc/apt/sources.list
   ```

3. **Increase APT timeouts:**
   ```bash
   sudo tee /etc/apt/apt.conf.d/99timeouts <<'EOF'
   Acquire::http::Timeout "30";
   Acquire::ftp::Timeout "30";
   EOF
   ```

---

## Failover Issues

### Issue: Failover Not Working

**Symptoms:**
- Service interruption when backend fails
- Manual intervention required
- Clients stuck during failover

**Diagnosis:**
```bash
# Check HAProxy health checks
curl -s http://10.80.11.140:8080/stats | grep -A 5 "backend\|aptly\|proxy"

# Test failover manually
ssh root@10.80.11.143 "systemctl stop nginx"
curl http://10.80.11.140/dists/jammy/Release
# Should still work via Node 2

# Check backup tier activation
curl -s http://10.80.11.140:8080/stats | grep proxy
```

**Solutions:**

1. **Health checks not configured:**
   ```bash
   vim /etc/haproxy/haproxy.cfg
   
   # Ensure:
   option httpchk GET /dists/jammy/Release
   http-check expect status 200
   
   systemctl restart haproxy
   ```

2. **Backup servers not marked:**
   ```bash
   vim /etc/haproxy/haproxy.cfg
   
   # Proxy nodes should have 'backup' keyword:
   server node1-proxy 10.80.11.145:80 check ... backup
   server node2-proxy 10.80.11.146:80 check ... backup
   
   systemctl restart haproxy
   ```

3. **Dual keyring not configured on clients:**
   ```bash
   # Update sources.list to include both keys
   sudo vim /etc/apt/sources.list
   
   # Should have:
   [signed-by=/usr/share/keyrings/aptly-custom-keyring.gpg,/usr/share/keyrings/ubuntu-archive-keyring.gpg]
   ```

---

## Performance Issues

### Issue: Slow Package Downloads

**Diagnosis:**
```bash
# Test download speed
wget -O /dev/null http://ubuntu.yourdomain.com/pool/main/c/curl/curl_7.81.0-1ubuntu1_amd64.deb

# Check server load
ssh root@10.80.11.143 "uptime; iostat"

# Check bandwidth usage
ssh root@10.80.11.143 "iftop -i ens160"

# Check HAProxy connection stats
curl -s http://10.80.11.140:8080/stats | grep "Session rate"
```

**Solutions:**

1. **High server load:**
   ```bash
   # Increase resources (CPU/RAM)
   # Or add more backend nodes
   ```

2. **Disk I/O bottleneck:**
   ```bash
   # Check disk performance
   iostat -x 5
   
   # Consider moving to SSD
   # Or add read cache
   ```

3. **Network saturation:**
   ```bash
   # Check bandwidth
   iftop
   
   # Enable HAProxy compression
   vim /etc/haproxy/haproxy.cfg
   # Add: compression algo gzip
   ```

4. **Too many concurrent connections:**
   ```bash
   # Increase HAProxy maxconn
   vim /etc/haproxy/haproxy.cfg
   # global section: maxconn 10000
   
   # Increase backend connections
   # backend section: maxconn 5000
   ```

---

## Logging and Monitoring

### Enable Debug Logging

```bash
# HAProxy debug
vim /etc/haproxy/haproxy.cfg
# Change: log /dev/log local0 debug

# Nginx debug
vim /etc/nginx/sites-available/aptly
# error_log /var/log/nginx/aptly-error.log debug;

# Aptly verbose logging
sudo -u aptly aptly -v mirror update jammy-main
```

### Centralized Logging

```bash
# Forward logs to central syslog server
vim /etc/rsyslog.d/50-default.conf

# Add:
*.* @@syslog-server.example.com:514
```

### Health Check Script

```bash
cat > /usr/local/bin/aptly-health-check.sh <<'EOF'
#!/bin/bash
ERRORS=0

# Check VIP
if ! curl -sf http://10.80.11.140/dists/jammy/Release > /dev/null; then
    echo "ERROR: VIP not responding"
    ((ERRORS++))
fi

# Check HAProxy
if ! systemctl is-active --quiet haproxy; then
    echo "ERROR: HAProxy not running"
    ((ERRORS++))
fi

# Check Aptly nodes
for ip in 10.80.11.143 10.80.11.144; do
    if ! curl -sf http://$ip/dists/jammy/Release > /dev/null; then
        echo "WARNING: Aptly node $ip not responding"
    fi
done

exit $ERRORS
EOF

chmod +x /usr/local/bin/aptly-health-check.sh

# Run from cron
echo "*/5 * * * * /usr/local/bin/aptly-health-check.sh" | crontab -
```

---

## Recovery Procedures

### Complete Cluster Failure

If entire cluster fails:

```bash
# 1. Start HAProxy master
ssh root@10.80.11.141 "systemctl start haproxy keepalived"

# 2. Start at least one Aptly node
ssh root@10.80.11.143 "systemctl start nginx"

# 3. Verify VIP assigned
ssh root@10.80.11.141 "ip addr | grep 10.80.11.140"

# 4. Test access
curl http://10.80.11.140/dists/jammy/Release

# 5. Start remaining nodes
ssh root@10.80.11.142 "systemctl start haproxy keepalived"
ssh root@10.80.11.144 "systemctl start nginx"
ssh root@10.80.11.145 "systemctl start nginx"
ssh root@10.80.11.146 "systemctl start nginx"
```

### Disaster Recovery

If Aptly data corrupted:

```bash
# 1. Stop services
systemctl stop nginx

# 2. Restore from backup (if available)
tar xzf /backup/aptly-data.tar.gz -C /

# 3. Or resync from scratch
sudo -u aptly aptly mirror update jammy-main
sudo -u aptly aptly mirror update jammy-universe
sudo -u aptly aptly mirror update jammy-security
sudo -u aptly aptly mirror update jammy-updates

# 4. Create new snapshots
DATE=$(date +%Y%m%d)
sudo -u aptly aptly snapshot create jammy-main-${DATE} from mirror jammy-main
# ... repeat for other mirrors

# 5. Publish
sudo -u aptly aptly publish snapshot -skip-contents -distribution=jammy jammy-${DATE}-merged

# 6. Restart service
systemctl start nginx
```

---

## Getting Help

### Information to Collect

When reporting issues, gather:

```bash
# System info
uname -a
cat /etc/os-release

# Service status
systemctl status haproxy keepalived nginx

# Logs
journalctl -u haproxy -n 100
tail -100 /var/log/aptly-update.log
tail -100 /var/log/nginx/aptly-error.log

# Configuration
cat /etc/haproxy/haproxy.cfg
cat /etc/nginx/sites-available/aptly
cat /etc/aptly.conf

# HAProxy stats
curl http://10.80.11.140:8080/stats -u admin:changeme123

# Network
ip addr
ip route
ss -tulnp
```

### Support Channels

- GitHub Issues: https://github.com/TazoTandilashvili/aptly-ha-cluster/issues
- Documentation: https://github.com/TazoTandilashvili/aptly-ha-cluster/wiki
- Email: support@yourdomain.com
