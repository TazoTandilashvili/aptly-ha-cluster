#!/bin/bash
#=============================================================================
# Aptly Daily Update Script
# Description: Update mirrors and publish new snapshots
# Usage: Run as aptly user via cron
#=============================================================================

set -e
DATE=$(date +%Y%m%d)
UBUNTU_VERSION="jammy"

echo "[$(date)] Starting Aptly update for $DATE"

# Drop existing publications
echo "[$(date)] Dropping old publications..."
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
echo "[$(date)] Publishing repositories..."

# jammy (main + universe)
aptly publish snapshot \
  -distribution=${UBUNTU_VERSION} \
  -component=main,universe \
  -origin="Ubuntu" \
  -label="Ubuntu" \
  -architectures="amd64" \
  -skip-contents \
  ${UBUNTU_VERSION}-main-${DATE} \
  ${UBUNTU_VERSION}-universe-${DATE}

# jammy-security
aptly publish snapshot \
  -distribution=${UBUNTU_VERSION}-security \
  -component=main,universe \
  -origin="Ubuntu" \
  -label="Ubuntu" \
  -architectures="amd64" \
  -skip-contents \
  ${UBUNTU_VERSION}-security-${DATE} \
  ${UBUNTU_VERSION}-security-${DATE}

# jammy-updates
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
