# ⚠️ Cut wifi users internet connection remotely using iptables ttl limiter

# Features:
- Single Target IP
- Multiple Target IP's
- All IP's in Subnet

# Dependencies
```
sudo apt update && sudo apt install wget dsniff iptables ipcalc -y
```

# Auto Install
```
wget https://raw.githubusercontent.com/xiv3r/netkiller/refs/heads/main/ttl-blocker/ttl-blocker.sh -O ttl-blocker.sh && chmod 755 ttl-blocker.sh && ./ttl-blocker.sh
```

# Usage
<div align="center">

<img src="https://github.com/xiv3r/netkiller/blob/main/ttl-blocker/ttl.png">
</div>
<br>

- `Interface`: wlan0 - wifi interface
- `Device IP`: 10.0.0.125 - Your Device DHCP IP (exemption for blocking)
- `Gateway`: 10.0.0.1 - Target Gateway
- `Target IP`: 10.0.0.150 - Target a single wifi user
- `Multiple Target IP`: 10.0.0.160 10.0.0.170 10.0.0.180 - Target multiple wifi users
- `Subnet`: 10.0.0.1/20 - Target all except your Device IP in the subnet

# Stop
```
sudo ttl-stop
```

# How it works 
- `----------------Bidirectional------------------------`
- `Wifi AP  ->  MITM (arp spoofing) -> Wifi clients` 
- `TTL=1|64 -> iptables --ttl-set 0 -> Dead connection for Wifi clients`
- `10.0.0.1 ->                      -> Unreachable`
