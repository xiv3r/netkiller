# About netkiller
netkiller - is a tool that kills the wifi clients internet connection without disconnecting them from the wifi AP.

<div align="center">
<img src="https://github.com/xiv3r/netkiller/blob/main/image/flow.jpg">
</div>

# Requirements
- Debian/Kali/Ubuntu/Parrot/Termux(root)
- Wireless or Built-in wifi Adapter

# Dependencies
```
sudo apt update && sudo apt upgrade -y && sudo apt install iptables dsniff ipcalc -y
```
# Features
- `Single Target` - 192.168.1.100
- `Multiple Targets` - 192.168.1.100 192.168.1.105 192.168.1.110 (Space-Separated)
- `All Targets` - 192.168.1.1/24 or 10.0.0.1/20

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
<details><summary></summary>
<div align="center">
<img src="https://github.com/xiv3r/netkiller/blob/main/image/setup.png">
</div></details>

## Restore the target wifi clients internet connection.
```
iptables -F
iptables -X
iptables -t nat -F
```

# Result
<div align="center">
<img src="https://github.com/xiv3r/netkiller/blob/main/image/error.png">
</div>

# ⚠️ DISCLAIMERS

`The Netkiller tool is intended solely for authorized testing, educational purposes, and network security auditing. Unauthorized use of this software against systems you do not own or have explicit permission to test is strictly prohibited and may be punishable by law.`

`The developers and distributors of the Netkiller tool shall not be held liable for any damage, loss of data, or legal consequences arising from the use or misuse of this software. You assume full responsibility for your actions and any outcomes resulting from its use.`
