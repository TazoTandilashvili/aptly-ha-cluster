# Client Setup Guide

This guide explains how to configure Ubuntu 22.04 clients to use your Aptly HA repository.

## Prerequisites

- Ubuntu 22.04 LTS client
- Root/sudo access
- Network connectivity to repository (http://ubuntu.yourdomain.com or 10.80.11.140)

## Quick Setup (Automated)

The easiest way to configure a client is using the automated script:

```bash
# Download configuration script
wget http://ubuntu.yourdomain.com/configure-apt-client.sh

# Make executable
chmod +x configure-apt-client.sh

# Run as root
sudo ./configure-apt-client.sh
```

The script will:
1. Backup your existing `/etc/apt/sources.list`
2. Download and install GPG keys (both Aptly and Ubuntu official)
3. Configure APT sources
4. Update package lists

## Manual Setup

If you prefer to configure manually:

### Step 1: Download GPG Keys

```bash
# Download Aptly custom key
wget http://ubuntu.yourdomain.com/repo-key.gpg -O /tmp/aptly-key.gpg

# Download Ubuntu official key (for proxy fallback)
wget http://ubuntu.yourdomain.com/ubuntu-official-keyring.gpg -O /tmp/ubuntu-key.gpg

# Install both keys
sudo gpg --dearmor < /tmp/aptly-key.gpg > /usr/share/keyrings/aptly-custom-keyring.gpg
sudo gpg --dearmor < /tmp/ubuntu-key.gpg > /usr/share/keyrings/ubuntu-archive-keyring.gpg

# Set permissions
sudo chmod 644 /usr/share/keyrings/aptly-custom-keyring.gpg
sudo chmod 644 /usr/share/keyrings/ubuntu-archive-keyring.gpg
```

### Step 2: Backup Existing Configuration

```bash
sudo cp /etc/apt/sources.list /etc/apt/sources.list.backup.$(date +%Y%m%d)
```

### Step 3: Configure APT

Create APT configuration for release info changes:

```bash
sudo tee /etc/apt/apt.conf.d/99allow-release-info-change <<'EOF'
# Allow repository metadata changes during HA failover
Acquire::AllowReleaseInfoChange "true";
EOF
```

### Step 4: Configure Sources

Replace your `/etc/apt/sources.list` with:

```bash
sudo tee /etc/apt/sources.list <<'EOF'
# High Availability Ubuntu Repository
# Dual keyring support for seamless failover between Aptly and Proxy nodes
deb [signed-by=/usr/share/keyrings/aptly-custom-keyring.gpg,/usr/share/keyrings/ubuntu-archive-keyring.gpg] http://ubuntu.yourdomain.com jammy main universe
deb [signed-by=/usr/share/keyrings/aptly-custom-keyring.gpg,/usr/share/keyrings/ubuntu-archive-keyring.gpg] http://ubuntu.yourdomain.com jammy-updates main universe
deb [signed-by=/usr/share/keyrings/aptly-custom-keyring.gpg,/usr/share/keyrings/ubuntu-archive-keyring.gpg] http://ubuntu.yourdomain.com jammy-security main universe
EOF
```

### Step 5: Update Package Lists

```bash
sudo apt-get clean
sudo rm -rf /var/lib/apt/lists/*
sudo apt-get update
```

## Verification

### Verify Configuration

```bash
# Check that update works
sudo apt-get update

# Should see lines like:
# Get:1 http://ubuntu.yourdomain.com jammy InRelease [4,350 B]
# Get:2 http://ubuntu.yourdomain.com jammy-updates InRelease [128 kB]
# Get:3 http://ubuntu.yourdomain.com jammy-security InRelease [129 kB]
```

### Test Package Installation

```bash
# Search for a package
apt-cache policy curl

# Should show repository: ubuntu.yourdomain.com

# Install a package
sudo apt-get install -y curl

# Verify it came from your repository
apt-cache policy curl
```

### Check GPG Keys

```bash
# List installed keys
ls -lh /usr/share/keyrings/ | grep -E "aptly|ubuntu-archive"

# Should show both:
# aptly-custom-keyring.gpg    (~1.4 KB)
# ubuntu-archive-keyring.gpg  (~3.6 KB)
```

## Configuration Options

### Using IP Address Instead of Domain

If DNS is not available, use the VIP directly:

```bash
deb [signed-by=/usr/share/keyrings/aptly-custom-keyring.gpg,/usr/share/keyrings/ubuntu-archive-keyring.gpg] http://10.80.11.140 jammy main universe
deb [signed-by=/usr/share/keyrings/aptly-custom-keyring.gpg,/usr/share/keyrings/ubuntu-archive-keyring.gpg] http://10.80.11.140 jammy-updates main universe
deb [signed-by=/usr/share/keyrings/aptly-custom-keyring.gpg,/usr/share/keyrings/ubuntu-archive-keyring.gpg] http://10.80.11.140 jammy-security main universe
```

### Components

The repository includes:
- **main**: Officially supported open-source software
- **universe**: Community-maintained open-source software

To add restricted/multiverse (if your Aptly mirrors them):

```bash
deb [...] http://ubuntu.yourdomain.com jammy main universe restricted multiverse
```

## Troubleshooting

### GPG Errors

If you see GPG signature errors:

```
The following signatures couldn't be verified because the public key is not available
```

**Solution**: Re-download and install the GPG keys

```bash
# Remove old keys
sudo rm /usr/share/keyrings/aptly-custom-keyring.gpg
sudo rm /usr/share/keyrings/ubuntu-archive-keyring.gpg

# Re-download
wget http://ubuntu.yourdomain.com/repo-key.gpg -O /tmp/aptly-key.gpg
wget http://ubuntu.yourdomain.com/ubuntu-official-keyring.gpg -O /tmp/ubuntu-key.gpg

# Re-install
sudo gpg --dearmor < /tmp/aptly-key.gpg > /usr/share/keyrings/aptly-custom-keyring.gpg
sudo gpg --dearmor < /tmp/ubuntu-key.gpg > /usr/share/keyrings/ubuntu-archive-keyring.gpg

# Update
sudo apt-get update
```

### Connection Errors

If apt-get update fails with connection errors:

```bash
# Test repository connectivity
curl -I http://ubuntu.yourdomain.com/dists/jammy/Release

# Test VIP directly
curl -I http://10.80.11.140/dists/jammy/Release

# Check DNS
nslookup ubuntu.yourdomain.com

# Check network
ping ubuntu.yourdomain.com
```

### Release Info Changes

If you see warnings about release info changes:

```
Release info changed: Suite: 'stable' -> 'jammy'
```

This happens during failover. It's safe and expected. The configuration in `/etc/apt/apt.conf.d/99allow-release-info-change` allows this automatically.

### Slow Package Downloads

If downloads are slow:

1. Check network bandwidth
2. Verify repository health: `curl http://ubuntu.yourdomain.com:8080/stats -u admin:changeme123`
3. Check if proxy nodes are active (slower than Aptly)

### Package Not Found

If a package isn't available:

1. Verify it's in the repository:
   ```bash
   apt-cache search <package-name>
   ```

2. Check which components are mirrored
3. Verify the package exists in Ubuntu 22.04

## Advanced Configuration

### Multiple Repositories

You can use both your local repository and Ubuntu official:

```bash
# Local repository (preferred)
deb [signed-by=/usr/share/keyrings/aptly-custom-keyring.gpg] http://ubuntu.yourdomain.com jammy main universe

# Ubuntu official (fallback)
deb [signed-by=/usr/share/keyrings/ubuntu-archive-keyring.gpg] http://archive.ubuntu.com/ubuntu jammy main universe
```

### APT Preferences (Pinning)

Prefer local repository:

```bash
sudo tee /etc/apt/preferences.d/local-repo <<'EOF'
Package: *
Pin: origin ubuntu.yourdomain.com
Pin-Priority: 1000

Package: *
Pin: origin archive.ubuntu.com
Pin-Priority: 500
EOF
```

### Proxy Configuration

If clients are behind a proxy:

```bash
sudo tee /etc/apt/apt.conf.d/80proxy <<'EOF'
Acquire::http::Proxy "http://proxy.example.com:8080";
EOF
```

## Ansible Playbook

For automated deployment across multiple clients:

```yaml
---
- name: Configure Aptly Repository
  hosts: ubuntu_clients
  become: yes
  tasks:
    - name: Download configuration script
      get_url:
        url: http://ubuntu.yourdomain.com/configure-apt-client.sh
        dest: /tmp/configure-apt-client.sh
        mode: '0755'

    - name: Run configuration script
      command: /tmp/configure-apt-client.sh
      args:
        creates: /usr/share/keyrings/aptly-custom-keyring.gpg
```

## Monitoring Client Health

### Check Repository Usage

```bash
# See where packages are coming from
apt-cache policy

# Check specific package source
apt-cache policy <package-name>
```

### Test Failover

```bash
# Before: Note which backend is serving
apt-get update -o Debug::Acquire::http=true 2>&1 | grep "Connecting to"

# Simulate backend failure (on server)
# Then update again to see failover
apt-get update
```

## Best Practices

1. **Always backup** `/etc/apt/sources.list` before changes
2. **Test on one client** before rolling out to all
3. **Monitor repository health** via HAProxy stats
4. **Keep both keyrings** for seamless failover
5. **Document your setup** for your team

## Rollback

To revert to Ubuntu official repositories:

```bash
# Restore backup
sudo cp /etc/apt/sources.list.backup.YYYYMMDD /etc/apt/sources.list

# Or use default Ubuntu sources
sudo tee /etc/apt/sources.list <<'EOF'
deb http://archive.ubuntu.com/ubuntu jammy main universe
deb http://archive.ubuntu.com/ubuntu jammy-updates main universe
deb http://security.ubuntu.com/ubuntu jammy-security main universe
EOF

# Update
sudo apt-get update
```

## Support

If you encounter issues:

1. Check [Troubleshooting Guide](troubleshooting.md)
2. Verify repository health: `curl http://ubuntu.yourdomain.com/dists/jammy/Release`
3. Check HAProxy stats: `http://ubuntu.yourdomain.com:8080/stats`
4. Review logs: `/var/log/apt/term.log`

For repository administrators, see [Maintenance Guide](maintenance.md).
