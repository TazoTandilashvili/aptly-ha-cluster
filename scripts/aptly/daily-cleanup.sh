#!/bin/bash

# Daily cleanup script for Aptly
# This script removes old snapshots and performs cleanup tasks.

# Set the directory for Aptly
APTLY_DIR="/home/aptly"

# Change to the Aptly directory
cd $APTLY_DIR || exit

# Remove snapshots older than 2 days
aptly snapshot remove $(aptly snapshot list | awk '{if(NR>1) print $1}' | head -n -2)

# Perform cleanup of old packages
aptly db cleanup

# Log the cleanup action
echo "Daily cleanup completed on $(date)" >> $APTLY_DIR/cleanup.log
