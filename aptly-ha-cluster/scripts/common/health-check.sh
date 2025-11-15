#!/bin/bash
#=============================================================================
# Health Check Script
# Description: Quick health check for all cluster components
# Usage: ./health-check.sh [vip]
#=============================================================================

# Configuration
VIP="${1:-10.80.11.140}"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "Aptly HA Cluster Health Check"
echo "=============================="
echo ""

# Check VIP
echo -n "VIP ($VIP) responding... "
if curl -sf -m 5 "http://$VIP/dists/jammy/Release" >/dev/null 2>&1; then
    echo -e "${GREEN}✓ OK${NC}"
else
    echo -e "${RED}✗ FAILED${NC}"
    echo "VIP is not responding!"
    exit 1
fi

# Check HAProxy stats
echo -n "HAProxy stats page... "
if curl -sf -m 5 "http://$VIP:8080/stats" -u "admin:changeme123" >/dev/null 2>&1; then
    echo -e "${GREEN}✓ OK${NC}"
else
    echo -e "${YELLOW}⚠ Not accessible${NC}"
fi

# Check repository content
echo -n "Repository metadata... "
RELEASE=$(curl -sf -m 5 "http://$VIP/dists/jammy/Release" 2>/dev/null)
if echo "$RELEASE" | grep -q "Ubuntu"; then
    echo -e "${GREEN}✓ OK${NC}"
else
    echo -e "${RED}✗ Invalid${NC}"
fi

# Check GPG keys
echo -n "Aptly GPG key... "
if curl -sf -m 5 "http://$VIP/repo-key.gpg" >/dev/null 2>&1; then
    echo -e "${GREEN}✓ OK${NC}"
else
    echo -e "${YELLOW}⚠ Not found${NC}"
fi

echo -n "Ubuntu GPG key... "
if curl -sf -m 5 "http://$VIP/ubuntu-official-keyring.gpg" >/dev/null 2>&1; then
    echo -e "${GREEN}✓ OK${NC}"
else
    echo -e "${YELLOW}⚠ Not found${NC}"
fi

# Test package download
echo -n "Package download test... "
if curl -sf -m 10 -I "http://$VIP/pool/main/c/curl/curl_7.81.0-1ubuntu1_amd64.deb" >/dev/null 2>&1; then
    echo -e "${GREEN}✓ OK${NC}"
else
    echo -e "${YELLOW}⚠ Package not found (may be normal)${NC}"
fi

echo ""
echo "=============================="
echo "Health check complete!"
echo ""
echo "For detailed status: cd ha-cluster && ./check-cluster-status.sh"
