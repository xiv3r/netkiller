# About netkiller
netkiller - is a tool that kills the wifi clients internet connection without disconnecting them from the wifi AP.

# Requirements
- Debian/Kali/Ubuntu/Termux(root)
- Wireless or Built-in wifi Adapter

# Dependencies
```
sudo apt update && sudo apt upgrade -y && sudo apt install iptables dsniff -y
```
# Git clone
```
git clone https://github.com/xiv3r/netkiller.git
cd netkiller
chmod +x netkiller.sh
```
# Run
```
./netkiller.sh
```

### To restore the target wifi clients internet connection.
```
iptables -F
iptables -X
iptables -t nat -F
```
