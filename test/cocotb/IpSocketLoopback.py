# from scapy.all import *
# from TestUtils import get_default_ip_addr

# local_ip = get_default_ip_addr()
# remote_ip = ""
# port_num = 0
# log_file = open(f"IpSocketLoopback_{local_ip}.txt", "w")

# def packet_callback(pkt):
#     if pkt.haslayer(IP):
#         if (pkt[IP].dst == local_ip) & (pkt[IP].src == remote_ip):
#             print("Received:")
#             pkt.show()
#             pkt[IP].chksum = None
#             pkt[IP].src, pkt[IP].dst = pkt[IP].dst, pkt[IP].src
#             pkt[Ether].src, pkt[Ether].dst = pkt[Ether].dst, pkt[Ether].src
#             sendp(Ether(raw(pkt)))
#             print(f"IP Socket Loopback({local_ip}): receive and send one packet\n")
#             print(f"IP Socket Loopback({local_ip}): loopback {pkt}")

# if __name__ == "__main__":
#     assert len(sys.argv) == 3
#     remote_ip = sys.argv[1]
#     port_num = int(sys.argv[2])
#     print(f"Start IP Socket Loopback({local_ip})")
#     sniff(prn=packet_callback)

import sys
import socket
import struct

assert len(sys.argv) == 3
local_ip = sys.argv[1]
port_num = int(sys.argv[2])
raw_socket = socket.socket(socket.AF_INET, socket.SOCK_RAW, socket.IPPROTO_RAW)

# raw_socket.bind((local_ip, port_num))

while True:
    packet, addr = raw_socket.recvfrom(65535)
    print("Receive one packet")
    print(packet)
