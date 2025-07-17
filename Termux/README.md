# Python Arp spoofer for termux

# Requirements
- Rooted Phone
- Termux App

# Dependencies
```
pkg update && pkg install git python -y && pip install scapy
```

# Functions
` Allow to spoof all the host in the subnet`

# Installation
```
git clone https://github.com/xiv3r/netkiller.git
```
```
cd netkiller/Termux
```
```
chmod +x mitm.py
```

# IP Forwarding
```
echo 1 > /proc/sys/net/ipv4/ip_forward
```

# Run
```
./mitm.py
```

# Attacks
Block all the traffic using iptables
```
iptables -F FORWARD 
iptables -I FORWARD -i wlan0 -j DROP
iptables -I FORWARD -o wlan0 -j DROP
```

# Stop
```
iptables -F FORWARD
pkill scapy
```
