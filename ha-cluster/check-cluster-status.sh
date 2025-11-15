#!/bin/bash
#=============================================================================
# HA Cluster Status Check
# Description: Check health and status of all cluster nodes
# Usage: ./check-cluster-status.sh
#=============================================================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Load configuration
CONFIG_FILE="../config/cluster.conf"
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    echo "Configuration file not found: $CONFIG_FILE"
    exit 1
fi

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║        Aptly HA Cluster Status Check                  ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

#=============================================================================
# CHECK FUNCTIONS
#=============================================================================

check_vip() {
    echo -e "${BLUE}[VIP Status]${NC}"
    
    # Check if VIP responds
    if curl -sf -m 5 "http://$VIP/dists/jammy/Release" > /dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} VIP $VIP is responding"
    else
        echo -e "  ${RED}✗${NC} VIP $VIP is NOT responding"
        return 1
    fi
    
    # Check which node has VIP
    if ssh "$SSH_USER@$HAPROXY_MASTER_IP" "ip addr show $VIP_INTERFACE 2>/dev/null | grep -q $VIP" 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} VIP assigned to: HAProxy Master ($HAPROXY_MASTER_IP)"
    elif ssh "$SSH_USER@$HAPROXY_BACKUP_IP" "ip addr show $VIP_INTERFACE 2>/dev/null | grep -q $VIP" 2>/dev/null; then
        echo -e "  ${YELLOW}⚠${NC} VIP assigned to: HAProxy Backup ($HAPROXY_BACKUP_IP)"
    else
        echo -e "  ${RED}✗${NC} VIP not found on any HAProxy node!"
        return 1
    fi
    
    echo ""
    return 0
}

check_haproxy() {
    echo -e "${BLUE}[HAProxy Nodes]${NC}"
    
    local nodes=(
        "$HAPROXY_MASTER_IP:Master"
        "$HAPROXY_BACKUP_IP:Backup"
    )
    
    for node in "${nodes[@]}"; do
        IFS=':' read -r ip name <<< "$node"
        
        # Check if SSH is accessible
        if ! ssh -o ConnectTimeout=5 "$SSH_USER@$ip" "exit" 2>/dev/null; then
            echo -e "  ${RED}✗${NC} HAProxy $name ($ip) - SSH failed"
            continue
        fi
        
        # Check HAProxy service
        if ssh "$SSH_USER@$ip" "systemctl is-active haproxy" 2>/dev/null | grep -q "active"; then
            echo -e "  ${GREEN}✓${NC} HAProxy $name ($ip) - Running"
        else
            echo -e "  ${RED}✗${NC} HAProxy $name ($ip) - Not running"
        fi
        
        # Check Keepalived service
        if ssh "$SSH_USER@$ip" "systemctl is-active keepalived" 2>/dev/null | grep -q "active"; then
            echo -e "  ${GREEN}✓${NC} Keepalived $name ($ip) - Running"
        else
            echo -e "  ${RED}✗${NC} Keepalived $name ($ip) - Not running"
        fi
    done
    
    echo ""
}

check_aptly_nodes() {
    echo -e "${BLUE}[Aptly Nodes]${NC}"
    
    local nodes=(
        "$APTLY_NODE1_IP:Aptly-1"
        "$APTLY_NODE2_IP:Aptly-2"
    )
    
    for node in "${nodes[@]}"; do
        IFS=':' read -r ip name <<< "$node"
        
        # Check if SSH is accessible
        if ! ssh -o ConnectTimeout=5 "$SSH_USER@$ip" "exit" 2>/dev/null; then
            echo -e "  ${RED}✗${NC} $name ($ip) - SSH failed"
            continue
        fi
        
        # Check Nginx service
        if ssh "$SSH_USER@$ip" "systemctl is-active nginx" 2>/dev/null | grep -q "active"; then
            echo -e "  ${GREEN}✓${NC} $name ($ip) - Nginx running"
        else
            echo -e "  ${RED}✗${NC} $name ($ip) - Nginx not running"
            continue
        fi
        
        # Check if repository is accessible
        if curl -sf -m 5 "http://$ip/dists/jammy/Release" > /dev/null 2>&1; then
            echo -e "  ${GREEN}✓${NC} $name ($ip) - Repository responding"
        else
            echo -e "  ${RED}✗${NC} $name ($ip) - Repository not responding"
        fi
        
        # Check disk usage
        local disk_usage=$(ssh "$SSH_USER@$ip" "df -h /var/aptly | tail -1 | awk '{print \$5}'" 2>/dev/null)
        if [ -n "$disk_usage" ]; then
            local usage_num=${disk_usage%\%}
            if [ "$usage_num" -gt 90 ]; then
                echo -e "  ${RED}⚠${NC} $name ($ip) - Disk usage: $disk_usage (LOW SPACE!)"
            elif [ "$usage_num" -gt 80 ]; then
                echo -e "  ${YELLOW}⚠${NC} $name ($ip) - Disk usage: $disk_usage"
            else
                echo -e "  ${GREEN}✓${NC} $name ($ip) - Disk usage: $disk_usage"
            fi
        fi
    done
    
    echo ""
}

check_proxy_nodes() {
    echo -e "${BLUE}[Proxy Nodes]${NC}"
    
    local nodes=(
        "$PROXY_NODE1_IP:Proxy-1"
        "$PROXY_NODE2_IP:Proxy-2"
    )
    
    for node in "${nodes[@]}"; do
        IFS=':' read -r ip name <<< "$node"
        
        # Check if SSH is accessible
        if ! ssh -o ConnectTimeout=5 "$SSH_USER@$ip" "exit" 2>/dev/null; then
            echo -e "  ${RED}✗${NC} $name ($ip) - SSH failed"
            continue
        fi
        
        # Check Nginx service
        if ssh "$SSH_USER@$ip" "systemctl is-active nginx" 2>/dev/null | grep -q "active"; then
            echo -e "  ${GREEN}✓${NC} $name ($ip) - Nginx running"
        else
            echo -e "  ${RED}✗${NC} $name ($ip) - Nginx not running"
            continue
        fi
        
        # Check health endpoint
        if curl -sf -m 5 "http://$ip/health" > /dev/null 2>&1; then
            echo -e "  ${GREEN}✓${NC} $name ($ip) - Health check OK"
        else
            echo -e "  ${RED}✗${NC} $name ($ip) - Health check failed"
        fi
    done
    
    echo ""
}

check_haproxy_stats() {
    echo -e "${BLUE}[HAProxy Backend Status]${NC}"
    
    # Try to get HAProxy stats
    local stats=$(curl -sf -m 5 "http://$VIP:8080/stats;csv" -u "$HAPROXY_STATS_USER:$HAPROXY_STATS_PASS" 2>/dev/null)
    
    if [ -z "$stats" ]; then
        echo -e "  ${RED}✗${NC} Cannot retrieve HAProxy stats"
        echo ""
        return 1
    fi
    
    # Parse backend status
    echo "$stats" | grep "ubuntu_servers" | grep -v "^#" | while IFS=',' read -r pxname svname status; do
        if echo "$svname" | grep -q "node"; then
            if echo "$status" | grep -q "UP"; then
                echo -e "  ${GREEN}✓${NC} Backend: $svname - UP"
            elif echo "$status" | grep -q "DOWN"; then
                echo -e "  ${RED}✗${NC} Backend: $svname - DOWN"
            else
                echo -e "  ${YELLOW}⚠${NC} Backend: $svname - $status"
            fi
        fi
    done
    
    echo ""
}

check_dns() {
    echo -e "${BLUE}[DNS Resolution]${NC}"
    
    if [ -n "$DOMAIN" ] && [ "$DOMAIN" != "ubuntu.yourdomain.com" ]; then
        local resolved_ip=$(dig +short "$DOMAIN" 2>/dev/null | tail -1)
        
        if [ "$resolved_ip" == "$VIP" ]; then
            echo -e "  ${GREEN}✓${NC} $DOMAIN resolves to $VIP"
        elif [ -n "$resolved_ip" ]; then
            echo -e "  ${YELLOW}⚠${NC} $DOMAIN resolves to $resolved_ip (expected: $VIP)"
        else
            echo -e "  ${RED}✗${NC} $DOMAIN does not resolve"
        fi
    else
        echo -e "  ${YELLOW}⚠${NC} Custom domain not configured (using default)"
    fi
    
    echo ""
}

print_summary() {
    echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                    Quick Access                        ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "📊 HAProxy Stats: http://$VIP:8080/stats"
    echo "   Username: $HAPROXY_STATS_USER"
    echo "   Password: $HAPROXY_STATS_PASS"
    echo ""
    echo "🔍 Test Repository:"
    echo "   curl -I http://$VIP/dists/jammy/Release"
    echo ""
    echo "👥 Client Setup:"
    echo "   wget http://$DOMAIN/configure-apt-client.sh"
    echo ""
}

#=============================================================================
# MAIN EXECUTION
#=============================================================================

main() {
    check_vip
    check_haproxy
    check_aptly_nodes
    check_proxy_nodes
    check_haproxy_stats
    check_dns
    print_summary
}

main "$@"
