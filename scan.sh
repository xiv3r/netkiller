#!/bin/bash

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo "Error: This script must be run as root (use sudo)."
  exit 1
fi

# Check if arp-scan is installed, install if not
if ! command -v arp-scan &> /dev/null; then
  echo "arp-scan not found. Installing arp-scan..."
  if [ -f /etc/debian_version ]; then
    apt update && apt install -y arp-scan
  else
    echo "Error: This script only supports Debian-based systems (e.g., Kali,Ubuntu). Please install arp-scan manually."
    exit 1
  fi
fi

# Detect first interface
WLAN=$(ip link show | awk -F': ' '/^[0-9]+: wl/{print $2}' | head -n 1)
echo ""

# Prompt user for network interface
echo "Enter Wireless Interface: Skip for default"
read -r -p "> $WLAN " WLN
interface="${WLN:-$WLAN}"
echo ""

# Validate inputs are not empty
if [ -z "$interface" ]; then
  echo "Error: Interface and subnet cannot be empty."
  exit 1
fi

# Run arp-scan with provided inputs
arp-scan --retry=5 --bandwidth=100000 --random --localnet --interface="$interface"
