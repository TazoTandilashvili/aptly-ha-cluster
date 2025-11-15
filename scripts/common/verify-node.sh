#!/bin/bash
#=============================================================================
# Node Verification Script
# Description: Verify a single node is properly configured
# Usage: ./verify-node.sh <node-ip> <node-type>
#        node-type: haproxy|aptly|proxy
#=============================================================================

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

if [ $# -ne 2 ]; then
    echo "Usage: $0 <node-ip> <node-type>"
    echo "  node-type: haproxy|aptly|proxy"
    exit 1
fi

NODE_IP="$1"
NODE_TYPE="$2"

echo "Verifying $NODE_TYPE node at $NODE_IP..."
echo ""

# Test SSH connectivity
echo -n "SSH connectivity... "
if ssh -o ConnectTimeout=5 -o BatchMode=yes "root@$NODE_IP" "exit" 2>/dev/null; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗ FAILED${NC}"
    exit 1
fi

case "$NODE_TYPE" in
    haproxy)
        # Check HAProxy
        echo -n "HAProxy service... "
        if ssh "root@$NODE_IP" "systemctl is-active haproxy" 2>/dev/null | grep -q "active"; then
            echo -e "${GREEN}✓${NC}"
        else
            echo -e "${RED}✗${NC}"
        fi
        
        # Check Keepalived
        echo -n "Keepalived service... "
        if ssh "root@$NODE_IP" "systemctl is-active keepalived" 2>/dev/null | grep -q "active"; then
            echo -e "${GREEN}✓${NC}"
        else
            echo -e "${RED}✗${NC}"
        fi
        
        # Check stats page
        echo -n "HAProxy stats page... "
        if curl -sf -m 5 "http://$NODE_IP:8080/stats" -u "admin:changeme123" >/dev/null 2>&1; then
            echo -e "${GREEN}✓${NC}"
        else
            echo -e "${RED}✗${NC}"
        fi
        ;;
        
    aptly)
        # Check Nginx
        echo -n "Nginx service... "
        if ssh "root@$NODE_IP" "systemctl is-active nginx" 2>/dev/null | grep -q "active"; then
            echo -e "${GREEN}✓${NC}"
        else
            echo -e "${RED}✗${NC}"
        fi
        
        # Check repository access
        echo -n "Repository access... "
        if curl -sf -m 5 "http://$NODE_IP/dists/jammy/Release" >/dev/null 2>&1; then
            echo -e "${GREEN}✓${NC}"
        else
            echo -e "${RED}✗${NC}"
        fi
        
        # Check GPG key
        echo -n "GPG key available... "
        if curl -sf -m 5 "http://$NODE_IP/repo-key.gpg" >/dev/null 2>&1; then
            echo -e "${GREEN}✓${NC}"
        else
            echo -e "${RED}✗${NC}"
        fi
        
        # Check disk space
        echo -n "Disk space... "
        DISK_USAGE=$(ssh "root@$NODE_IP" "df -h /var/aptly | tail -1 | awk '{print \$5}'" 2>/dev/null)
        if [ -n "$DISK_USAGE" ]; then
            USAGE_NUM=${DISK_USAGE%\%}
            if [ "$USAGE_NUM" -gt 90 ]; then
                echo -e "${RED}$DISK_USAGE (LOW!)${NC}"
            elif [ "$USAGE_NUM" -gt 80 ]; then
                echo -e "${YELLOW}$DISK_USAGE${NC}"
            else
                echo -e "${GREEN}$DISK_USAGE${NC}"
            fi
        else
            echo -e "${RED}✗${NC}"
        fi
        ;;
        
    proxy)
        # Check Nginx
        echo -n "Nginx service... "
        if ssh "root@$NODE_IP" "systemctl is-active nginx" 2>/dev/null | grep -q "active"; then
            echo -e "${GREEN}✓${NC}"
        else
            echo -e "${RED}✗${NC}"
        fi
        
        # Check health endpoint
        echo -n "Health endpoint... "
        if curl -sf -m 5 "http://$NODE_IP/health" 2>&1 | grep -q "OK"; then
            echo -e "${GREEN}✓${NC}"
        else
            echo -e "${RED}✗${NC}"
        fi
        
        # Check proxy function
        echo -n "Proxy function... "
        if curl -sf -m 5 "http://$NODE_IP/dists/jammy/Release" >/dev/null 2>&1; then
            echo -e "${GREEN}✓${NC}"
        else
            echo -e "${RED}✗${NC}"
        fi
        ;;
        
    *)
        echo "Unknown node type: $NODE_TYPE"
        exit 1
        ;;
esac

echo ""
echo "Verification complete for $NODE_TYPE node at $NODE_IP"
