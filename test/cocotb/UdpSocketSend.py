import sys
import time
import socket

if __name__ == "__main__":
    assert len(sys.argv) == 3
    dst_ip = sys.argv[1]
    dst_port = int(sys.argv[2])
    pkt_num = 36
    udp_socket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    dst_addr = (dst_ip, dst_port)
    while True:
        udp_socket.sendto(b'Hello World!! Hello World!!', dst_addr)
        time.sleep(6)
        print("Send one packet to: ", dst_addr)