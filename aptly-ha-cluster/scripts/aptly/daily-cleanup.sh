#!/bin/bash
#=============================================================================
# Aptly Daily Cleanup Script
# Description: Remove old snapshots, keep only recent ones
# Usage: Run as aptly user via cron
#=============================================================================

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
