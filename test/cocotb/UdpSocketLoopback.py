import socket
import time
import sys

if __name__ == "__main__":
    assert len(sys.argv) == 3
    ip_addr = sys.argv[1]
    port_num = int(sys.argv[2])
    bind_addr = (ip_addr, port_num)
    print(f"Start packet loopback from {bind_addr} port")
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.bind(bind_addr)
    pkt_count = 0
    while True:
        pkt, pkt_addr = sock.recvfrom(4096)
        print(f"Recv {pkt_count} packet from {pkt_addr}")
        time.sleep(3)
        sock.sendto(pkt, pkt_addr)
        print(f"Send {pkt_count} packet back to {pkt_addr}")
        pkt_count = pkt_count + 1
