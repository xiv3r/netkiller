# Dependencies
```
sudo apt-get update && sudo apt-get install -y wget dsniff iptables iptables-persistent ipcalc -y
```

# Install
```
wget -O arpdns-portal.sh https://raw.githubusercontent.com/xiv3r/netkiller/refs/heads/main/arpdns_captive_portal/arpdns-portal.sh && chmod 755 arpdns-portal.sh && ./arpdns-portal.sh
```

# How it works?
- Redirect wifi users dns request to your captive portal gateway.
- WIFI -> MITM (you) -> Wifi Users
