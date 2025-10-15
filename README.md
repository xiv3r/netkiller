<h1 align="center"> NETKILLER </h1>

<h3 align="center">Netkiller is a tool that can remotely disconnect the internet access of any device in a WiFi network without admin access privilege. </h3>
 
<div align="center">
<img src="https://github.com/xiv3r/netkiller/blob/main/image/wifikill.png">
</div>
<br>

# ⚠️ WARNING ⚠️

`This tool can disrupt your system routing connections` you can check your system by running
```
iptables -S
iptables -t mangle -S
iptables -t nat -S
```
if there's any existing iptables rules do a backup 
```
iptables-save > /etc/iptables/rules.v4
```
to restore you're connections
```
iptables-restore < /etc/iptables/rules.v4
```

# Requirements
- Debian/Kali/Ubuntu/Parrot/[Kali Termux (root)](https://github.com/xiv3r/Kali-Linux-Termux)
- External or Built-in WiFi Adapter
- [Device i'm used](https://github.com/xiv3r/uz801-usb-pentest)

# Features
- ▶️`single target`
- 🔀`multiple targets`
- 🔁`all subnet targets`
- 📵`disconnect the internet`
- 🚫`intercept and drop traffic`
- ❗`block all device with multiple exemption`
- ☢️`dhcp starvation`
- ☣️`arp spoofing`
- 💪`accuracy rate 95%`

<details><summary></summary>
<br>
 
# Dependencies
```
sudo apt update && sudo apt upgrade -y && sudo apt install arp-scan iptables dsniff ipcalc -y
```

# Git clone
```
git clone https://github.com/xiv3r/netkiller.git
cd netkiller
sudo chmod +x *.sh
```
# Run
```
sudo bash netkiller.sh
```
</details>
<br>

# Auto install
<details><summary>Install logs</summary>
<img src="https://github.com/xiv3r/netkiller/blob/main/image/install.png">
</details>

```
sudo apt update && sudo apt install wget -y && wget -qO- https://raw.githubusercontent.com/xiv3r/netkiller/refs/heads/main/install.sh | sudo sh && sudo chmod 755 netkiller/*.sh && cd netkiller && ls
```
<details><summary>Kali Termux (root)</summary>
 <img src="https://github.com/xiv3r/netkiller/blob/main/image/kali-termux.png">
</details>
<br>

# Run
```
sudo bash netkiller.sh
```
<br>

# Stop
> Restore the target connection.
```
sudo netkiller-stop
```
<br>

# Show ARP/Iptables/htop
```
sudo arp -e
```
```
sudo iptables -t mangle -S
```
```
htop
```

# Update
```
cd netkiller
```
```
git fetch --all
git reset --hard origin/main
```
<br>

# Impact
> ping 10.0.0.1 says ttl limit exceeded
<div align="center">
<img src="https://github.com/xiv3r/netkiller/blob/main/image/error.png">
<img src="https://github.com/xiv3r/netkiller/blob/main/image/noinet.png">

<details><summary>Expand</summary>
  
<img src="https://github.com/xiv3r/netkiller/blob/main/image/proc.png">
<img src="https://github.com/xiv3r/netkiller/blob/main/image/dhcpstarvation.png">
</details></div>
<br>

# About netkiller
netkiller - is a tool that remotely disconnect the wifi clients internet connection without deauthentication from the wifi AP. Netkiller uses dsniff arpspoof to mimic the target address resolution protocol and manipulate the traffic using iptables mangle PREROUTING ttl limit 0.

<div align="center">
<img src="https://github.com/xiv3r/netkiller/blob/main/image/flow.jpg">
</div>
<br>

## ⚠️ DISCLAIMER

`The Netkiller tool is intended solely for authorized testing, educational purposes, and network security auditing. Unauthorized use of this software against systems you do not own or have explicit permission to test is strictly prohibited and may be punishable by law.`

`The developers and distributors of the Netkiller tool shall not be held liable for any damage, loss of data, or legal consequences arising from the use or misuse of this software. You assume full responsibility for your actions and any outcomes resulting from its use.`
