#!/bin/bash
#=============================================================================
# Aptly HA Cluster Deployment Script
# Description: Deploy complete 7-node HA cluster
# Usage: sudo ./deploy-ha.sh
#=============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration file
CONFIG_FILE="../config/cluster.conf"

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

log_section() {
    echo -e "\n${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║ $1${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}\n"
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

load_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        log_error "Configuration file not found: $CONFIG_FILE"
        log_info "Please copy and edit the configuration:"
        echo "  cp ../config/cluster.conf.example ../config/cluster.conf"
        echo "  vim ../config/cluster.conf"
        exit 1
    fi
    
    source "$CONFIG_FILE"
    log_info "Configuration loaded from $CONFIG_FILE"
}

check_dependencies() {
    log_info "Checking dependencies..."
    
    local deps=("ssh" "sshpass" "rsync")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        log_warn "Missing dependencies: ${missing[*]}"
        log_info "Installing dependencies..."
        apt-get update
        apt-get install -y "${missing[@]}"
    fi
    
    log_info "All dependencies satisfied"
}

test_ssh_connectivity() {
    log_info "Testing SSH connectivity to all nodes..."
    
    local nodes=(
        "$HAPROXY_MASTER_IP:HAProxy-Master"
        "$HAPROXY_BACKUP_IP:HAProxy-Backup"
        "$APTLY_NODE1_IP:Aptly-1"
        "$APTLY_NODE2_IP:Aptly-2"
        "$PROXY_NODE1_IP:Proxy-1"
        "$PROXY_NODE2_IP:Proxy-2"
    )
    
    local failed=()
    
    for node in "${nodes[@]}"; do
        IFS=':' read -r ip name <<< "$node"
        if ssh -o ConnectTimeout=5 -o BatchMode=yes "$SSH_USER@$ip" "echo 'OK'" &>/dev/null; then
            log_info "✓ $name ($ip) - Connected"
        else
            log_error "✗ $name ($ip) - Failed"
            failed+=("$name")
        fi
    done
    
    if [ ${#failed[@]} -gt 0 ]; then
        log_error "Cannot connect to: ${failed[*]}"
        log_info "Please ensure:"
        log_info "  1. SSH keys are set up (ssh-copy-id root@<ip>)"
        log_info "  2. All servers are accessible"
        log_info "  3. Firewall allows SSH (port 22)"
        exit 1
    fi
    
    log_info "All nodes are accessible via SSH"
}

#=============================================================================
# DEPLOYMENT FUNCTIONS
#=============================================================================

deploy_haproxy_master() {
    log_section "Deploying HAProxy Master ($HAPROXY_MASTER_IP)"
    
    ssh "$SSH_USER@$HAPROXY_MASTER_IP" bash <<'ENDSSH'
        set -e
        
        # Install packages
        apt-get update
        apt-get install -y haproxy keepalived
        
        echo "HAProxy and Keepalived installed"
ENDSSH
    
    # Copy HAProxy configuration
    log_info "Configuring HAProxy on master..."
    scp ../config/haproxy.cfg.example "$SSH_USER@$HAPROXY_MASTER_IP:/etc/haproxy/haproxy.cfg"
    
    # Update configuration with actual IPs
    ssh "$SSH_USER@$HAPROXY_MASTER_IP" bash <<ENDSSH
        sed -i 's/10.80.11.143/$APTLY_NODE1_IP/g' /etc/haproxy/haproxy.cfg
        sed -i 's/10.80.11.144/$APTLY_NODE2_IP/g' /etc/haproxy/haproxy.cfg
        sed -i 's/10.80.11.145/$PROXY_NODE1_IP/g' /etc/haproxy/haproxy.cfg
        sed -i 's/10.80.11.146/$PROXY_NODE2_IP/g' /etc/haproxy/haproxy.cfg
        sed -i 's/ubuntu.yourdomain.com/$DOMAIN/g' /etc/haproxy/haproxy.cfg
ENDSSH
    
    # Configure Keepalived
    log_info "Configuring Keepalived (MASTER)..."
    ssh "$SSH_USER@$HAPROXY_MASTER_IP" bash <<ENDSSH
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
    interface $VIP_INTERFACE
    virtual_router_id $VRRP_ROUTER_ID
    priority $VRRP_PRIORITY_MASTER
    unicast_src_ip $HAPROXY_MASTER_IP
    unicast_peer {
        $HAPROXY_BACKUP_IP
    }
    authentication {
        auth_type $VRRP_AUTH_TYPE
        auth_pass $VRRP_AUTH_PASS
    }
    virtual_ipaddress {
        $VIP/$VIP_NETMASK
    }
    track_script {
        chk_haproxy
    }
}
EOF
ENDSSH
    
    # Enable and start services
    ssh "$SSH_USER@$HAPROXY_MASTER_IP" bash <<'ENDSSH'
        systemctl enable haproxy keepalived
        systemctl restart haproxy keepalived
        
        echo "Services started"
        systemctl status haproxy --no-pager
        systemctl status keepalived --no-pager
ENDSSH
    
    log_info "✓ HAProxy Master deployed successfully"
}

deploy_haproxy_backup() {
    log_section "Deploying HAProxy Backup ($HAPROXY_BACKUP_IP)"
    
    ssh "$SSH_USER@$HAPROXY_BACKUP_IP" bash <<'ENDSSH'
        set -e
        
        apt-get update
        apt-get install -y haproxy keepalived
ENDSSH
    
    # Copy same HAProxy config
    scp ../config/haproxy.cfg.example "$SSH_USER@$HAPROXY_BACKUP_IP:/etc/haproxy/haproxy.cfg"
    
    ssh "$SSH_USER@$HAPROXY_BACKUP_IP" bash <<ENDSSH
        sed -i 's/10.80.11.143/$APTLY_NODE1_IP/g' /etc/haproxy/haproxy.cfg
        sed -i 's/10.80.11.144/$APTLY_NODE2_IP/g' /etc/haproxy/haproxy.cfg
        sed -i 's/10.80.11.145/$PROXY_NODE1_IP/g' /etc/haproxy/haproxy.cfg
        sed -i 's/10.80.11.146/$PROXY_NODE2_IP/g' /etc/haproxy/haproxy.cfg
        sed -i 's/ubuntu.yourdomain.com/$DOMAIN/g' /etc/haproxy/haproxy.cfg
ENDSSH
    
    # Configure Keepalived as BACKUP
    log_info "Configuring Keepalived (BACKUP)..."
    ssh "$SSH_USER@$HAPROXY_BACKUP_IP" bash <<ENDSSH
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
    interface $VIP_INTERFACE
    virtual_router_id $VRRP_ROUTER_ID
    priority $VRRP_PRIORITY_BACKUP
    unicast_src_ip $HAPROXY_BACKUP_IP
    unicast_peer {
        $HAPROXY_MASTER_IP
    }
    authentication {
        auth_type $VRRP_AUTH_TYPE
        auth_pass $VRRP_AUTH_PASS
    }
    virtual_ipaddress {
        $VIP/$VIP_NETMASK
    }
    track_script {
        chk_haproxy
    }
}
EOF
ENDSSH
    
    ssh "$SSH_USER@$HAPROXY_BACKUP_IP" bash <<'ENDSSH'
        systemctl enable haproxy keepalived
        systemctl restart haproxy keepalived
ENDSSH
    
    log_info "✓ HAProxy Backup deployed successfully"
}

deploy_aptly_node() {
    local node_ip=$1
    local node_name=$2
    
    log_section "Deploying Aptly Node: $node_name ($node_ip)"
    
    # Copy standalone deployment script
    log_info "Copying deployment script to $node_name..."
    scp ../standalone/deploy.sh "$SSH_USER@$node_ip:/tmp/"
    
    # Run deployment
    log_info "Running Aptly deployment (this will take 2-4 hours for initial sync)..."
    log_warn "You can monitor progress in another terminal: ssh $SSH_USER@$node_ip 'tail -f /tmp/aptly-deploy.log'"
    
    ssh "$SSH_USER@$node_ip" bash <<ENDSSH
        export DOMAIN="$DOMAIN"
        cd /tmp
        chmod +x deploy.sh
        ./deploy.sh 2>&1 | tee /tmp/aptly-deploy.log
ENDSSH
    
    log_info "✓ Aptly Node $node_name deployed successfully"
}

deploy_proxy_node() {
    local node_ip=$1
    local node_name=$2
    
    log_section "Deploying Proxy Node: $node_name ($node_ip)"
    
    ssh "$SSH_USER@$node_ip" bash <<'ENDSSH'
        set -e
        
        apt-get update
        apt-get install -y nginx
ENDSSH
    
    # Create nginx configuration
    log_info "Configuring Nginx proxy..."
    ssh "$SSH_USER@$node_ip" bash <<'ENDSSH'
        cat > /etc/nginx/sites-available/ubuntu-proxy <<'EOF'
server {
    listen 80;
    server_name _;
    
    access_log /var/log/nginx/ubuntu-proxy-access.log;
    error_log /var/log/nginx/ubuntu-proxy-error.log;
    
    # Health check for HAProxy
    location /health {
        access_log off;
        return 200 "OK\n";
        add_header Content-Type text/plain;
    }
    
    # Serve Ubuntu's official GPG key
    location = /repo-key.gpg {
        proxy_pass http://archive.ubuntu.com/ubuntu/project/ubuntu-archive-keyring.gpg;
        proxy_set_header Host archive.ubuntu.com;
    }
    
    location /ubuntu-official-keyring.gpg {
        proxy_pass http://archive.ubuntu.com/ubuntu/project/ubuntu-archive-keyring.gpg;
        proxy_set_header Host archive.ubuntu.com;
    }
    
    # Distribution metadata
    location ~ ^/dists/(jammy|jammy-updates|jammy-security)/ {
        proxy_pass http://archive.ubuntu.com/ubuntu$request_uri;
        proxy_set_header Host archive.ubuntu.com;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_buffering on;
        proxy_connect_timeout 30s;
        proxy_read_timeout 60s;
    }
    
    # Package pools
    location /pool/ {
        proxy_pass http://archive.ubuntu.com/ubuntu/pool/;
        proxy_set_header Host archive.ubuntu.com;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_buffering on;
    }
    
    # Catch-all
    location / {
        proxy_pass http://archive.ubuntu.com/ubuntu/;
        proxy_set_header Host archive.ubuntu.com;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
EOF

        ln -sf /etc/nginx/sites-available/ubuntu-proxy /etc/nginx/sites-enabled/
        rm -f /etc/nginx/sites-enabled/default
        
        nginx -t
        systemctl enable nginx
        systemctl restart nginx
ENDSSH
    
    log_info "✓ Proxy Node $node_name deployed successfully"
}

verify_deployment() {
    log_section "Verifying Deployment"
    
    # Check VIP
    log_info "Checking Virtual IP..."
    if ssh "$SSH_USER@$HAPROXY_MASTER_IP" "ip addr show $VIP_INTERFACE | grep -q $VIP"; then
        log_info "✓ VIP $VIP is assigned to HAProxy Master"
    else
        log_warn "VIP not on master, checking backup..."
        if ssh "$SSH_USER@$HAPROXY_BACKUP_IP" "ip addr show $VIP_INTERFACE | grep -q $VIP"; then
            log_info "✓ VIP $VIP is assigned to HAProxy Backup"
        else
            log_error "VIP is not assigned to any HAProxy node!"
        fi
    fi
    
    # Test VIP access
    log_info "Testing VIP access..."
    if curl -sf "http://$VIP/dists/jammy/Release" > /dev/null; then
        log_info "✓ VIP is responding to HTTP requests"
    else
        log_error "VIP is not responding to HTTP requests"
    fi
    
    # Check HAProxy stats
    log_info "Checking HAProxy stats..."
    if curl -sf "http://$VIP:8080/stats" -u "$HAPROXY_STATS_USER:$HAPROXY_STATS_PASS" > /dev/null; then
        log_info "✓ HAProxy statistics page is accessible"
        log_info "  Access at: http://$VIP:8080/stats"
        log_info "  Username: $HAPROXY_STATS_USER"
        log_info "  Password: $HAPROXY_STATS_PASS"
    else
        log_warn "Cannot access HAProxy stats page"
    fi
    
    # Test backend nodes
    log_info "Testing backend nodes..."
    
    local backends=(
        "$APTLY_NODE1_IP:Aptly-1"
        "$APTLY_NODE2_IP:Aptly-2"
        "$PROXY_NODE1_IP:Proxy-1"
        "$PROXY_NODE2_IP:Proxy-2"
    )
    
    for backend in "${backends[@]}"; do
        IFS=':' read -r ip name <<< "$backend"
        if curl -sf "http://$ip/dists/jammy/Release" > /dev/null; then
            log_info "✓ $name ($ip) - Responding"
        else
            log_warn "✗ $name ($ip) - Not responding"
        fi
    done
    
    log_info "Verification complete!"
}

print_summary() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║              HA Cluster Deployment Complete!                   ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "📊 Cluster Information:"
    echo "   Virtual IP: $VIP"
    echo "   Domain: $DOMAIN"
    echo ""
    echo "🖥️  Server Layout:"
    echo "   HAProxy Master: $HAPROXY_MASTER_IP"
    echo "   HAProxy Backup: $HAPROXY_BACKUP_IP"
    echo "   Aptly Node 1: $APTLY_NODE1_IP"
    echo "   Aptly Node 2: $APTLY_NODE2_IP"
    echo "   Proxy Node 1: $PROXY_NODE1_IP"
    echo "   Proxy Node 2: $PROXY_NODE2_IP"
    echo ""
    echo "🔍 Monitoring:"
    echo "   HAProxy Stats: http://$VIP:8080/stats"
    echo "   Username: $HAPROXY_STATS_USER"
    echo "   Password: $HAPROXY_STATS_PASS"
    echo ""
    echo "👥 Client Configuration:"
    echo "   wget http://$DOMAIN/configure-apt-client.sh"
    echo "   sudo ./configure-apt-client.sh"
    echo ""
    echo "📝 Next Steps:"
    echo "   1. Test failover scenarios (see docs/ha-cluster-setup.md)"
    echo "   2. Configure client machines"
    echo "   3. Set up monitoring and alerts"
    echo "   4. Change default passwords!"
    echo ""
    echo "✅ Your HA cluster is ready for production!"
    echo ""
}

#=============================================================================
# MAIN EXECUTION
#=============================================================================

main() {
    log_section "Aptly HA Cluster Deployment"
    
    check_root
    load_config
    check_dependencies
    test_ssh_connectivity
    
    echo ""
    log_warn "This will deploy a complete 7-node HA cluster:"
    echo "  - 2 HAProxy nodes (with Keepalived)"
    echo "  - 2 Aptly nodes (Ubuntu mirrors)"
    echo "  - 2 Proxy nodes (fallback)"
    echo ""
    log_warn "Aptly nodes will download ~100GB each (2-4 hours per node)"
    echo ""
    read -p "Continue with deployment? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Deployment cancelled"
        exit 0
    fi
    
    # Deploy in order
    deploy_haproxy_master
    deploy_haproxy_backup
    
    log_info "Waiting 10 seconds for Keepalived to stabilize..."
    sleep 10
    
    # Deploy Aptly nodes (can be done in parallel if you uncomment)
    deploy_aptly_node "$APTLY_NODE1_IP" "Aptly-1"
    deploy_aptly_node "$APTLY_NODE2_IP" "Aptly-2"
    
    # Deploy Proxy nodes
    deploy_proxy_node "$PROXY_NODE1_IP" "Proxy-1"
    deploy_proxy_node "$PROXY_NODE2_IP" "Proxy-2"
    
    # Verify everything
    verify_deployment
    
    # Print summary
    print_summary
}

# Run main function
main "$@"
