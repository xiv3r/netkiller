#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}IP-based Rate Limiting Setup${NC}"
echo "=================================="

# Get user input
read -p "Enter network interface (e.g., eth0): " INTERFACE
read -p "Enter CIDR subnet (e.g., 192.168.1.0/24): " SUBNET
read -p "Enter rate limit (e.g., 1mb/sec): " RATE_LIMIT
read -p "Enter burst rate (e.g., 1mb): " BURST_RATE

# Get device IP automatically
DEVICE_IP=$(ip addr show $INTERFACE 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d/ -f1)

if [ -z "$DEVICE_IP" ]; then
    echo -e "${RED}Error: Could not determine IP address for interface $INTERFACE${NC}"
    exit 1
fi

echo -e "\n${YELLOW}Device IP detected: $DEVICE_IP${NC}"
echo -e "${YELLOW}This IP will be exempted from rate limiting${NC}"

# Flush existing mangle FORWARD chain rules
echo -e "\n${YELLOW}Flushing existing mangle FORWARD rules...${NC}"
iptables -t mangle -F FORWARD

# Generate IP list from subnet using ipcalc
echo -e "\n${YELLOW}Generating IP list from subnet $SUBNET...${NC}"
IP_LIST=$(ipcalc -n $SUBNET | grep "^Address:" | awk '{print $2}')

if [ -z "$IP_LIST" ]; then
    echo -e "${RED}Error: Could not generate IP list from subnet $SUBNET${NC}"
    echo "Please ensure ipcalc is installed and the subnet is valid"
    exit 1
fi

# Convert subnet to individual IPs
IPS=$(ipcalc $SUBNET | grep "^Address:" | awk '{print $2}')

# Alternative method if the above doesn't work for all IPs
# This gets the network address and calculates the range
NETWORK=$(ipcalc -n $SUBNET | grep "^Network:" | awk '{print $2}' | cut -d/ -f1)
BROADCAST=$(ipcalc -b $SUBNET | grep "^Broadcast:" | awk '{print $2}')

echo -e "${GREEN}Network: $NETWORK${NC}"
echo -e "${GREEN}Broadcast: $BROADCAST${NC}"

# Create rate limiting rules for each IP
COUNTER=1
for ip in $(ipcalc $SUBNET | grep "^HostMin:\|^HostMax:" | awk '{print $2}' | sort -u); do
    # Skip if this is the device IP
    if [ "$ip" = "$DEVICE_IP" ]; then
        echo -e "${YELLOW}Skipping device IP: $ip${NC}"
        continue
    fi
    
    # Skip network and broadcast addresses
    if [ "$ip" = "$NETWORK" ] || [ "$ip" = "$BROADCAST" ]; then
        echo -e "${YELLOW}Skipping network/broadcast address: $ip${NC}"
        continue
    fi
    
    echo -e "${GREEN}Adding rate limit for IP: $ip${NC}"
    
    # Create hashlimit rule
    iptables -t mangle -A FORWARD -s $ip -m hashlimit --hashlimit-name "ip$COUNTER" --hashlimit-upto $RATE_LIMIT --hashlimit-burst $BURST_RATE -j RETURN
    
    # Create drop rule for exceeding limit
    iptables -t mangle -A FORWARD -s $ip -j DROP
    
    COUNTER=$((COUNTER + 1))
done

# Final accept rule for other packets
echo -e "\n${YELLOW}Adding final ACCEPT rule...${NC}"
iptables -t mangle -A FORWARD -j ACCEPT

echo -e "\n${GREEN}Rate limiting setup completed!${NC}"
echo -e "${GREEN}Rules applied for subnet: $SUBNET${NC}"
echo -e "${GREEN}Rate limit: $RATE_LIMIT with burst: $BURST_RATE${NC}"
echo -e "${GREEN}Device IP ($DEVICE_IP) was exempted${NC}"
echo -e "${GREEN}Total IPs processed: $((COUNTER - 1))${NC}"

# Show current rules
echo -e "\n${YELLOW}Current mangle FORWARD rules:${NC}"
iptables -t mangle -L FORWARD -n --line-numbers
