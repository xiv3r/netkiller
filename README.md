<h1 align="center"> NETKILLER </h1>

<h3 align="center">Netkiller can block or restrict any device on your WiFi network with surgical precision. Whether you’re managing home users, wifi vending machine or testing network security, NetKiller gives you the power to disconnect unwanted clients instantly with no admin access needed. </h3>
 
<div align="center">
<img src="https://github.com/xiv3r/netkiller/blob/main/image/netkill.png">
</div>
<br>

# Requirements
- Debian/Kali/Ubuntu/Parrot/[Kali Termux (root)](https://github.com/xiv3r/Kali-Linux-Termux)
- External or Built-in WiFi Adapter
<br>

# Features
- ▶️`single target`
- 🔀`multiple targets`
- 🔁`all subnet targets`
- 📵`block internet traffic`
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
sudo ./netkiller-multi.sh
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

# ⚠️ Notes
- If you don't know the target ip, you must execute `sudo ./scan.sh`
- Subnet must start with e.g., `10.0.0.1/20`
- Multiple target IP's is separated by comma e.g., `10.0.0.123,10.0.0.124`
- Remember the ⚠️ DISCLAIMER 🤭
<br>

# Scanning the target
<details>
 <img src="https://github.com/xiv3r/netkiller/blob/main/image/scan.png">
</details>

```
sudo bash scan.sh
```
<br>

# Attack the target
```
sudo bash netkiller-multi.sh
```
<br>

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
> Impact of the remote attack on the target wifi clients connection.
<div align="center">
<img src="https://github.com/xiv3r/netkiller/blob/main/image/error.png">
<img src="https://github.com/xiv3r/netkiller/blob/main/image/noinet.png">

<details><summary>Expand</summary>
  
<img src="https://github.com/xiv3r/netkiller/blob/main/image/proc.png">
<img src="https://github.com/xiv3r/netkiller/blob/main/image/dhcpstarvation.png">
</details></div>
<br>

# Stop
> Remotely restore the target wifi client internet connection.
```
sudo netkiller-stop
```
<br>

# About netkiller
netkiller - is a tool that blocks the wifi clients internet connection remotely without disconnecting them from the wifi AP.

<div align="center">
<img src="https://github.com/xiv3r/netkiller/blob/main/image/flow.jpg">
</div>
<br>

## ⚠️ DISCLAIMER

`The Netkiller tool is intended solely for authorized testing, educational purposes, and network security auditing. Unauthorized use of this software against systems you do not own or have explicit permission to test is strictly prohibited and may be punishable by law.`

`The developers and distributors of the Netkiller tool shall not be held liable for any damage, loss of data, or legal consequences arising from the use or misuse of this software. You assume full responsibility for your actions and any outcomes resulting from its use.`
