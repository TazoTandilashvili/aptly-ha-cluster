#!/bin/bash
#=============================================================================
# Aptly Standalone Deployment Script
# Description: Deploy a single-node Aptly repository for Ubuntu 22.04
# Usage: sudo ./deploy.sh
#=============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
DOMAIN="${DOMAIN:-ubuntu.yourdomain.com}"
SERVER_IP=$(hostname -I | awk '{print $1}')
UBUNTU_VERSION="jammy"
GPG_KEY_NAME="Aptly Repository Signing Key"
GPG_KEY_EMAIL="aptly@yourdomain.local"

#=============================================================================
# HELPER FUNCTIONS
#=============================================================================

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

check_os() {
    if ! grep -q "Ubuntu 22.04" /etc/os-release; then
        log_warn "This script is designed for Ubuntu 22.04"
        read -p "Continue anyway? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

check_disk_space() {
    local required_space=150  # GB
    local available_space=$(df -BG /var | tail -1 | awk '{print $4}' | sed 's/G//')
    
    if [ "$available_space" -lt "$required_space" ]; then
        log_error "Insufficient disk space. Required: ${required_space}GB, Available: ${available_space}GB"
        exit 1
    fi
    log_info "Disk space check passed: ${available_space}GB available"
}

#=============================================================================
# INSTALLATION FUNCTIONS
#=============================================================================

install_aptly() {
    log_info "Installing Aptly and dependencies..."
    
    apt update
    apt install -y gnupg unzip nginx wget curl
    
    cd /tmp
    wget -q https://github.com/aptly-dev/aptly/releases/download/v1.6.2/aptly_1.6.2_linux_amd64.zip
    unzip -q aptly_1.6.2_linux_amd64.zip
    mv aptly_1.6.2_linux_amd64/aptly /usr/local/bin/
    chmod +x /usr/local/bin/aptly
    rm -rf aptly_1.6.2_linux_amd64*
    
    log_info "Aptly $(aptly version | head -1) installed successfully"
}

create_aptly_user() {
    log_info "Creating Aptly user and directories..."
    
    if ! id -u aptly &>/dev/null; then
        useradd -r -m -d /home/aptly -s /usr/sbin/nologin -c "Aptly Repository User" aptly
    fi
    
    mkdir -p /var/aptly/tmp
    chown -R aptly:aptly /var/aptly
}

generate_gpg_key() {
    log_info "Generating GPG key for package signing..."
    
    # Check if key already exists
    if sudo -u aptly gpg --list-keys | grep -q "$GPG_KEY_EMAIL"; then
        log_warn "GPG key already exists, skipping generation"
        GPG_KEY_ID=$(sudo -u aptly gpg --list-keys --keyid-format LONG "$GPG_KEY_EMAIL" | grep -A 1 "pub" | tail -1 | awk '{print $1}')
        return
    fi
    
    # Generate key
    sudo -u aptly gpg --batch --quick-generate-key "$GPG_KEY_NAME <$GPG_KEY_EMAIL>" rsa3072 sign 2y
    
    # Get key ID
    GPG_KEY_ID=$(sudo -u aptly gpg --list-keys --keyid-format LONG "$GPG_KEY_EMAIL" | grep -A 1 "pub" | tail -1 | awk '{print $1}')
    
    log_info "GPG Key generated: $GPG_KEY_ID"
    
    # Export public key
    mkdir -p /var/aptly/public
    sudo -u aptly gpg --armor --export > /var/aptly/public/repo-key.gpg
    chmod 644 /var/aptly/public/repo-key.gpg
    
    log_info "Public key exported to /var/aptly/public/repo-key.gpg"
}

configure_aptly() {
    log_info "Configuring Aptly..."
    
    cat > /etc/aptly.conf <<EOF
{
    "rootDir": "/var/aptly",
    "downloadConcurrency": 4,
    "architectures": ["amd64"],
    "downloadSourcePackages": false,
    "gpgDisableVerify": false,
    "gpgDisableSign": false,
    "gpgProvider": "gpg",
    "gpgKey": "$GPG_KEY_ID",
    "tempDir": "/var/aptly/tmp"
}
EOF
    
    log_info "Aptly configuration written to /etc/aptly.conf"
}

create_mirrors() {
    log_info "Creating Aptly mirrors (this step is quick)..."
    
    sudo -u aptly aptly mirror create ${UBUNTU_VERSION}-main \
        http://archive.ubuntu.com/ubuntu ${UBUNTU_VERSION} main
    
    sudo -u aptly aptly mirror create ${UBUNTU_VERSION}-universe \
        http://archive.ubuntu.com/ubuntu ${UBUNTU_VERSION} universe
    
    sudo -u aptly aptly mirror create ${UBUNTU_VERSION}-security \
        http://security.ubuntu.com/ubuntu ${UBUNTU_VERSION}-security main universe
    
    sudo -u aptly aptly mirror create ${UBUNTU_VERSION}-updates \
        http://archive.ubuntu.com/ubuntu ${UBUNTU_VERSION}-updates main universe
    
    log_info "Mirrors created successfully"
}

sync_mirrors() {
    log_info "Starting initial mirror sync..."
    log_warn "This will download ~100GB+ and take 2-4 hours depending on your connection"
    read -p "Continue? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Skipping mirror sync. You can run it later with: sudo -u aptly aptly mirror update <mirror-name>"
        return
    fi
    
    log_info "Updating ${UBUNTU_VERSION}-main..."
    sudo -u aptly aptly mirror update ${UBUNTU_VERSION}-main
    
    log_info "Updating ${UBUNTU_VERSION}-universe..."
    sudo -u aptly aptly mirror update ${UBUNTU_VERSION}-universe
    
    log_info "Updating ${UBUNTU_VERSION}-security..."
    sudo -u aptly aptly mirror update ${UBUNTU_VERSION}-security
    
    log_info "Updating ${UBUNTU_VERSION}-updates..."
    sudo -u aptly aptly mirror update ${UBUNTU_VERSION}-updates
    
    log_info "Mirror sync completed!"
}

create_snapshots() {
    log_info "Creating initial snapshots..."
    
    DATE=$(date +%Y%m%d)
    
    sudo -u aptly aptly snapshot create ${UBUNTU_VERSION}-main-${DATE} from mirror ${UBUNTU_VERSION}-main
    sudo -u aptly aptly snapshot create ${UBUNTU_VERSION}-universe-${DATE} from mirror ${UBUNTU_VERSION}-universe
    sudo -u aptly aptly snapshot create ${UBUNTU_VERSION}-security-${DATE} from mirror ${UBUNTU_VERSION}-security
    sudo -u aptly aptly snapshot create ${UBUNTU_VERSION}-updates-${DATE} from mirror ${UBUNTU_VERSION}-updates
    
    log_info "Snapshots created for date: $DATE"
}

publish_repository() {
    log_info "Publishing repository..."
    
    DATE=$(date +%Y%m%d)
    
    # Publish jammy (main + universe)
    sudo -u aptly aptly publish snapshot \
      -distribution=${UBUNTU_VERSION} \
      -component=main,universe \
      -origin="Ubuntu" \
      -label="Ubuntu" \
      -architectures="amd64" \
      -skip-contents \
      ${UBUNTU_VERSION}-main-${DATE} \
      ${UBUNTU_VERSION}-universe-${DATE}

    # Publish jammy-security
    sudo -u aptly aptly publish snapshot \
      -distribution=${UBUNTU_VERSION}-security \
      -component=main,universe \
      -origin="Ubuntu" \
      -label="Ubuntu" \
      -architectures="amd64" \
      -skip-contents \
      ${UBUNTU_VERSION}-security-${DATE} \
      ${UBUNTU_VERSION}-security-${DATE}

    # Publish jammy-updates
    sudo -u aptly aptly publish snapshot \
      -distribution=${UBUNTU_VERSION}-updates \
      -component=main,universe \
      -origin="Ubuntu" \
      -label="Ubuntu" \
      -architectures="amd64" \
      -skip-contents \
      ${UBUNTU_VERSION}-updates-${DATE} \
      ${UBUNTU_VERSION}-updates-${DATE}
    
    log_info "Repository published successfully"
}

configure_nginx() {
    log_info "Configuring Nginx..."
    
    cat > /etc/nginx/sites-available/aptly <<'EOF'
server {
    listen 0.0.0.0:80;
    server_name _;

    root /var/aptly/public;
    autoindex on;

    # Disable gzip/compression
    gzip off;
    tcp_nopush on;
    sendfile on;

    # Correct MIME types
    types {
        text/plain gpg;
        text/plain InRelease;
        text/plain Release;
    }

    location / {
        autoindex on;
        default_type application/octet-stream;
        add_header Cache-Control "no-transform";
    }

    # Restrict access to internal dirs
    location ~ /(.*)/(conf|db) {
        deny all;
    }

    access_log /var/log/nginx/aptly-access.log;
    error_log  /var/log/nginx/aptly-error.log;
}
EOF
    
    ln -sf /etc/nginx/sites-available/aptly /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
    
    # Disable gzip globally
    sed -i 's/gzip on;/gzip off;/' /etc/nginx/nginx.conf
    
    nginx -t && systemctl restart nginx
    systemctl enable nginx
    
    log_info "Nginx configured and started"
}

create_update_script() {
    log_info "Creating daily update script..."
    
    cat > /home/aptly/aptly-daily-update.sh <<'EOFSCRIPT'
#!/bin/bash
set -e
DATE=$(date +%Y%m%d)
UBUNTU_VERSION="jammy"

echo "[$(date)] Starting Aptly update for $DATE"

# Drop existing publications
aptly publish drop ${UBUNTU_VERSION}           2>/dev/null || true
aptly publish drop ${UBUNTU_VERSION}-security  2>/dev/null || true
aptly publish drop ${UBUNTU_VERSION}-updates   2>/dev/null || true

# Update mirrors
echo "[$(date)] Updating mirrors..."
aptly mirror update ${UBUNTU_VERSION}-main
aptly mirror update ${UBUNTU_VERSION}-universe
aptly mirror update ${UBUNTU_VERSION}-security
aptly mirror update ${UBUNTU_VERSION}-updates

# Create snapshots
echo "[$(date)] Creating snapshots..."
aptly snapshot create ${UBUNTU_VERSION}-main-${DATE}     from mirror ${UBUNTU_VERSION}-main
aptly snapshot create ${UBUNTU_VERSION}-universe-${DATE} from mirror ${UBUNTU_VERSION}-universe
aptly snapshot create ${UBUNTU_VERSION}-security-${DATE} from mirror ${UBUNTU_VERSION}-security
aptly snapshot create ${UBUNTU_VERSION}-updates-${DATE}  from mirror ${UBUNTU_VERSION}-updates

# Publish
echo "[$(date)] Publishing..."

aptly publish snapshot \
  -distribution=${UBUNTU_VERSION} \
  -component=main,universe \
  -origin="Ubuntu" \
  -label="Ubuntu" \
  -architectures="amd64" \
  -skip-contents \
  ${UBUNTU_VERSION}-main-${DATE} \
  ${UBUNTU_VERSION}-universe-${DATE}

aptly publish snapshot \
  -distribution=${UBUNTU_VERSION}-security \
  -component=main,universe \
  -origin="Ubuntu" \
  -label="Ubuntu" \
  -architectures="amd64" \
  -skip-contents \
  ${UBUNTU_VERSION}-security-${DATE} \
  ${UBUNTU_VERSION}-security-${DATE}

aptly publish snapshot \
  -distribution=${UBUNTU_VERSION}-updates \
  -component=main,universe \
  -origin="Ubuntu" \
  -label="Ubuntu" \
  -architectures="amd64" \
  -skip-contents \
  ${UBUNTU_VERSION}-updates-${DATE} \
  ${UBUNTU_VERSION}-updates-${DATE}

echo "[$(date)] Update completed successfully"
EOFSCRIPT
    
    chmod +x /home/aptly/aptly-daily-update.sh
    chown aptly:aptly /home/aptly/aptly-daily-update.sh
    
    log_info "Update script created: /home/aptly/aptly-daily-update.sh"
}

create_cleanup_script() {
    log_info "Creating daily cleanup script..."
    
    cat > /home/aptly/aptly-cleanup-daily.sh <<'EOFSCRIPT'
#!/bin/bash
set -euo pipefail

KEEP=2
UBUNTU_VERSION="jammy"

echo "[$(date)] Starting cleanup..."

# Get all unique dates from snapshots
DATES=$(aptly snapshot list -raw | grep -oE '[0-9]{8}' | sort -u | sort -r)
DATE_COUNT=$(echo "$DATES" | wc -l)

if [ "$DATE_COUNT" -le "$KEEP" ]; then
    echo "[$(date)] Only $DATE_COUNT dates found. No cleanup needed."
    exit 0
fi

# Delete old snapshots
DELETE_DATES=$(echo "$DATES" | tail -n +$((KEEP + 1)))

for SNAP_DATE in $DELETE_DATES; do
    echo "[$(date)] Deleting snapshots from $SNAP_DATE"
    aptly snapshot list -raw | grep "$SNAP_DATE" | while read -r SNAP_NAME; do
        echo "  -> Dropping: $SNAP_NAME"
        aptly snapshot drop -force "$SNAP_NAME" || true
    done
done

echo "[$(date)] Cleanup complete. Kept $KEEP most recent dates."
EOFSCRIPT
    
    chmod +x /home/aptly/aptly-cleanup-daily.sh
    chown aptly:aptly /home/aptly/aptly-cleanup-daily.sh
    
    log_info "Cleanup script created: /home/aptly/aptly-cleanup-daily.sh"
}

setup_cron() {
    log_info "Setting up cron jobs..."
    
    touch /var/log/aptly-update.log /var/log/aptly-cleanup.log
    chown aptly:aptly /var/log/aptly-update.log /var/log/aptly-cleanup.log
    
    cat > /etc/cron.d/aptly-tasks <<'EOF'
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

# Daily update at 6:00 AM
0 6 * * * aptly /home/aptly/aptly-daily-update.sh >> /var/log/aptly-update.log 2>&1

# Daily cleanup at 7:00 AM
0 7 * * * aptly /home/aptly/aptly-cleanup-daily.sh >> /var/log/aptly-cleanup.log 2>&1
EOF
    
    chmod 644 /etc/cron.d/aptly-tasks
    
    log_info "Cron jobs configured"
}

create_client_script() {
    log_info "Creating client configuration script..."
    
    cat > /var/aptly/public/configure-apt-client.sh <<EOFCLIENT
#!/bin/bash
set -e

REPO_URL="http://$DOMAIN"

echo "=================================================="
echo "Aptly Repository Client Configuration"
echo "=================================================="
echo "Repository: \$REPO_URL"
echo ""

apt-get update >/dev/null 2>&1 || true
apt-get install -y gnupg wget ca-certificates >/dev/null 2>&1

# Backup existing sources.list
if [ -f /etc/apt/sources.list ]; then
    BACKUP="/etc/apt/sources.list.backup.\$(date +%Y%m%d-%H%M%S)"
    cp /etc/apt/sources.list "\$BACKUP"
    echo "✅ Backed up sources.list to: \$BACKUP"
fi

echo "Downloading GPG key..."
wget -q \$REPO_URL/repo-key.gpg -O /tmp/repo-key.gpg

if [ -f /tmp/repo-key.gpg ] && [ -s /tmp/repo-key.gpg ]; then
    if file /tmp/repo-key.gpg 2>/dev/null | grep -q "PGP\|ASCII"; then
        gpg --dearmor < /tmp/repo-key.gpg > /usr/share/keyrings/aptly-keyring.gpg 2>/dev/null
    else
        cp /tmp/repo-key.gpg /usr/share/keyrings/aptly-keyring.gpg
    fi
    chmod 644 /usr/share/keyrings/aptly-keyring.gpg
    echo "✅ GPG key installed"
else
    echo "❌ Failed to download GPG key"
    exit 1
fi

# Configure APT
cat > /etc/apt/apt.conf.d/99allow-release-info-change <<'EOFAPT'
Acquire::AllowReleaseInfoChange "true";
EOFAPT

# Configure sources.list
cat > /etc/apt/sources.list <<'EOFSOURCES'
# Aptly Local Repository
deb [signed-by=/usr/share/keyrings/aptly-keyring.gpg] http://$DOMAIN jammy main universe
deb [signed-by=/usr/share/keyrings/aptly-keyring.gpg] http://$DOMAIN jammy-updates main universe
deb [signed-by=/usr/share/keyrings/aptly-keyring.gpg] http://$DOMAIN jammy-security main universe
EOFSOURCES

apt-get clean
rm -rf /var/lib/apt/lists/*

if apt-get update --allow-releaseinfo-change; then
    echo ""
    echo "=================================================="
    echo "✅ Configuration completed successfully!"
    echo "=================================================="
    echo "You can now use: apt install <package>"
else
    echo "❌ Configuration failed"
    exit 1
fi
EOFCLIENT
    
    chmod +x /var/aptly/public/configure-apt-client.sh
    chown aptly:aptly /var/aptly/public/configure-apt-client.sh
    
    log_info "Client script created: /var/aptly/public/configure-apt-client.sh"
}

verify_installation() {
    log_info "Verifying installation..."
    
    # Check services
    if ! systemctl is-active --quiet nginx; then
        log_error "Nginx is not running"
        return 1
    fi
    
    # Check repository access
    if ! curl -f -s http://localhost/dists/${UBUNTU_VERSION}/Release > /dev/null; then
        log_error "Repository is not accessible"
        return 1
    fi
    
    # Check GPG key
    if ! curl -f -s http://localhost/repo-key.gpg > /dev/null; then
        log_error "GPG key is not accessible"
        return 1
    fi
    
    log_info "✅ All checks passed!"
    return 0
}

print_summary() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║          Aptly Standalone Deployment Complete!            ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
    echo "📦 Repository URL: http://$DOMAIN"
    echo "🖥️  Server IP: $SERVER_IP"
    echo "🔑 GPG Key ID: $GPG_KEY_ID"
    echo ""
    echo "📝 Important Files:"
    echo "   - Configuration: /etc/aptly.conf"
    echo "   - Repository: /var/aptly/public"
    echo "   - GPG Key: /var/aptly/public/repo-key.gpg"
    echo "   - Update Script: /home/aptly/aptly-daily-update.sh"
    echo "   - Cleanup Script: /home/aptly/aptly-cleanup-daily.sh"
    echo ""
    echo "⚙️  Scheduled Tasks:"
    echo "   - Daily Update: 06:00 AM"
    echo "   - Daily Cleanup: 07:00 AM"
    echo ""
    echo "🔧 Client Configuration:"
    echo "   wget http://$DOMAIN/configure-apt-client.sh"
    echo "   chmod +x configure-apt-client.sh"
    echo "   sudo ./configure-apt-client.sh"
    echo ""
    echo "📊 Useful Commands:"
    echo "   - Check status: sudo -u aptly aptly publish list"
    echo "   - Manual update: sudo -u aptly /home/aptly/aptly-daily-update.sh"
    echo "   - View logs: tail -f /var/log/aptly-update.log"
    echo ""
    echo "✅ Installation complete! Your repository is ready to use."
    echo ""
}

#=============================================================================
# MAIN EXECUTION
#=============================================================================

main() {
    log_info "Starting Aptly Standalone Deployment"
    echo ""
    
    check_root
    check_os
    check_disk_space
    
    install_aptly
    create_aptly_user
    generate_gpg_key
    configure_aptly
    create_mirrors
    sync_mirrors
    create_snapshots
    publish_repository
    configure_nginx
    create_update_script
    create_cleanup_script
    setup_cron
    create_client_script
    verify_installation
    
    print_summary
}

# Run main function
main "$@"
