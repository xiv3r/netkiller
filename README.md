<div align="center">
<img src="https://github.com/xiv3r/netkiller/blob/main/image/gui.png">
</div>

# Requirements
- Debian/Kali/Ubuntu/Parrot
- [Kali Termux (root)](https://github.com/xiv3r/Kali-Linux-Termux)
- External or Built-in WiFi Adapter

# Features
- `single target`
- `multiple targets`
- `all subnet targets`
- `block internet traffic`
- `intercept and drop traffic`
- `block all device with multiple exemption`
- `dhcp starvation`
- `arp spoofing`

<details><summary></summary>

# Dependencies
```
sudo apt update && sudo apt upgrade -y && sudo apt install iptables dsniff ipcalc -y
```

# Git clone
```
git clone https://github.com/xiv3r/netkiller.git
cd netkiller
sudo chmod +x *.sh
```
</details>

# Auto install

<details><summary></summary>
<img src="https://github.com/xiv3r/netkiller/blob/main/image/install.png">
</details>

```
sudo apt update && sudo apt install wget -y && wget -qO- https://raw.githubusercontent.com/xiv3r/netkiller/refs/heads/main/install.sh | sudo sh && sudo chmod 755 ~/netkiller/*.sh && cd netkiller
```

# Run
```
sudo bash netkiller-multi.sh
```

# Usage

<div align="center">
<img src="https://github.com/xiv3r/netkiller/blob/main/image/cmd.png.jpg">
</div>

# Result
> Impact of the remote attack on the target wifi clients connection.
<div align="center">
<img src="https://github.com/xiv3r/netkiller/blob/main/image/error.png">
<img src="https://github.com/xiv3r/netkiller/blob/main/image/noinet.png">

<details><summary>Expand</summary>
  
<img src="https://github.com/xiv3r/netkiller/blob/main/image/proc.png">
<img src="https://github.com/xiv3r/netkiller/blob/main/image/dhcpstarvation.png">
</details></div>

# Restore
> Restore the target wifi clients internet connection remotely.
```
sudo netkiller-stop
```
# About netkiller
netkiller - is a tool that blocks the wifi clients internet connection remotely without disconnecting them from the wifi AP.

<div align="center">
<img src="https://github.com/xiv3r/netkiller/blob/main/image/flow.jpg">
</div>

# ⚠️ DISCLAIMER

`The Netkiller tool is intended solely for authorized testing, educational purposes, and network security auditing. Unauthorized use of this software against systems you do not own or have explicit permission to test is strictly prohibited and may be punishable by law.`

`The developers and distributors of the Netkiller tool shall not be held liable for any damage, loss of data, or legal consequences arising from the use or misuse of this software. You assume full responsibility for your actions and any outcomes resulting from its use.`
