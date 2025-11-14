# Failover Testing Documentation

This document outlines the procedures and steps for testing high availability (HA) scenarios in the Aptly High Availability Ubuntu Repository Cluster.

## Purpose

The purpose of failover testing is to ensure that the system can handle failures gracefully and that the failover mechanisms are functioning as intended. This includes testing the automatic failover of HAProxy and Keepalived, as well as the recovery of Aptly nodes.

## Testing Scenarios

### 1. HAProxy Failover

**Objective:** Verify that the backup HAProxy instance takes over when the master instance fails.

**Steps:**
1. Simulate a failure on the HAProxy master node:
   - Stop the HAProxy service on the master node.
   - `sudo systemctl stop haproxy`
2. Check the status of the Virtual IP (VIP):
   - Use `ping` to verify that the VIP is still reachable.
   - `ping 10.80.11.140`
3. Verify that the backup HAProxy instance has taken over:
   - Access the HAProxy statistics page on the backup node.
   - `http://10.80.11.142:8080/stats`
4. Restart the HAProxy service on the master node:
   - `sudo systemctl start haproxy`
5. Verify that the master node has regained control of the VIP.

### 2. Aptly Node Failover

**Objective:** Ensure that the system can switch to a backup Aptly node if the primary node fails.

**Steps:**
1. Simulate a failure on the primary Aptly node:
   - Stop the Aptly service on the primary node.
   - `sudo systemctl stop aptly`
2. Check the status of the repository:
   - Attempt to access the repository through the VIP.
   - `apt update`
3. Verify that the backup Aptly node is serving requests:
   - Check the logs on the backup node for incoming requests.
4. Restart the Aptly service on the primary node:
   - `sudo systemctl start aptly`
5. Verify that the primary node can serve requests again.

### 3. Network Partition Testing

**Objective:** Test the system's behavior during a network partition.

**Steps:**
1. Isolate one of the HAProxy nodes from the network:
   - Use `iptables` to block traffic temporarily.
   - `sudo iptables -A INPUT -s 10.80.11.141 -j DROP`
2. Verify that the remaining HAProxy node continues to serve traffic.
3. Restore network connectivity:
   - `sudo iptables -D INPUT -s 10.80.11.141 -j DROP`
4. Check that both HAProxy nodes are functioning correctly.

## Conclusion

Regular failover testing is crucial to ensure the reliability and availability of the Aptly High Availability Ubuntu Repository Cluster. Document any issues encountered during testing and update this document with new findings or procedures as necessary.
