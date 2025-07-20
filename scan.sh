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

# Prompt user for network interface
echo "Enter network interface (e.g., wlan0)"
read -p "> " interface

# Prompt user for subnet (e.g., 10.0.0.1/20)
echo "Enter subnet (e.g., 10.0.0.0/20)"
read -p "> " subnet

# Validate inputs are not empty
if [ -z "$interface" ] || [ -z "$subnet" ]; then
  echo "Error: Interface and subnet cannot be empty."
  exit 1
fi

# Run arp-scan with provided inputs
arp-scan -I"$interface" --retry=3 --timeout=1000 --bandwidth=100000 "$subnet"
