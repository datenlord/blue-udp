from scapy.all import *
import random

while True:
    payload = random.randbytes(1024)
    packet = IP(dst="10.1.1.64") / UDP(sport=88, dport=88) / Raw(payload)
    # print("Send:")
    # packet = Ether(raw(packet))
    # packet.show()
    resp, _ = sr(packet, verbose=True)
    for _, r in resp:
        recv_pkt = r

    print(f"Scapy Send and Recv Packet:")
    recv_pkt.show()
    time.sleep(5)
