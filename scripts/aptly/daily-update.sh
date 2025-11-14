#!/bin/bash

# Daily update script for Aptly

# Set the date for the snapshot
DATE=$(date +%Y%m%d)

# Update the Aptly mirror
aptly mirror update my-mirror

# Create a new snapshot
aptly snapshot create jammy-$DATE from mirror my-mirror

# Publish the snapshot
aptly publish snapshot jammy-$DATE

# Clean up old snapshots, keeping the last 2
aptly snapshot delete $(aptly snapshot list | awk '{print $1}' | tail -n +3)
