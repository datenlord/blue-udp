import logging
import os
import random

from scapy.all import *
from scapy.contrib.roce import *

import cocotb_test.simulator
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge

from cocotbext.axi import AxiStreamBus, AxiStreamSource, AxiStreamSink, AxiStreamFrame
from cocotbext.axi.stream import define_stream

IP_ADDR_LEN = 4
MAC_ADDR_LEN = 6
UDP_PORT_LEN = 2
MIN_PAYLOAD_LEN = 1024
MAX_PAYLOAD_LEN = 2048
CASES_NUM = 32

UdpConfigBus, UdpConfigTransation, UdpConfigSource, UdpConfigSink, UdpConfigMonitor = define_stream(
    "UdpConfig", signals=["valid", "ready", "mac_addr", "ip_addr", "net_mask", "gate_way"]
)

UdpIpMetaBus, UdpIpMetaTransation, UdpIpMetaSource, UdpIpMetaSink, UdpIpMetaMonitor = define_stream(
    "UdpIpMeta", signals=["valid", "ready", "ip_addr", "dst_port", "src_port", "data_len"]
)

MacMetaBus, MacMetaTransaction, MacMetaSource, MacMetaSink, MacMetaMonitor = define_stream(
    "MacMeta", signals=["valid", "ready", "mac_addr", "eth_type"]
)

class RdmaUdpIpEthTxTester:
    def __init__(self, dut, cases_num, min_payload_len, max_payload_len):
        self.dut = dut
        
        self.log = logging.getLogger("cocotb.tb")
        self.log.setLevel(logging.DEBUG)
        
        self.cases_num = cases_num
        self.min_payload_len = min_payload_len
        self.max_payload_len = max_payload_len
        self.ref_buffer = Queue(maxsize = self.cases_num)
        self.local_ip = random.randbytes(IP_ADDR_LEN)
        self.local_mac = random.randbytes(MAC_ADDR_LEN)
        
        self.clock = dut.CLK
        self.resetn = dut.RST_N

        self.udp_config_src = UdpConfigSource(UdpConfigBus.from_prefix(dut, "s_udp_config"), self.clock, self.resetn, False)
        self.udp_meta_src = UdpIpMetaSource(UdpIpMetaBus.from_prefix(dut, "s_udp_meta"), self.clock, self.resetn, False)
        self.mac_meta_src = MacMetaSource(MacMetaBus.from_prefix(dut, "s_mac_meta"), self.clock, self.resetn, False)
        
        self.data_stream_src = AxiStreamSource(AxiStreamBus.from_prefix(dut, "s_data_stream"), self.clock, self.resetn, False)
        self.axi_stream_sink = AxiStreamSink(AxiStreamBus.from_prefix(dut, "m_axis"), self.clock, self.resetn, False)
        
    async def gen_clock(self):
        await cocotb.start(Clock(self.clock, 10, 'ns').start())
        
    async def gen_reset(self):
        self.resetn.value = 0
        await RisingEdge(self.clock)
        await RisingEdge(self.clock)
        self.resetn.value = 1
        await RisingEdge(self.clock)
        await RisingEdge(self.clock)
    
    async def config_udp(self):
        udp_config_trans = UdpConfigTransation()
        udp_config_trans.ip_addr  = int.from_bytes(self.local_ip, 'big')
        udp_config_trans.mac_addr = int.from_bytes(self.local_mac, 'big')
        udp_config_trans.net_mask = int.from_bytes(random.randbytes(IP_ADDR_LEN), 'big')
        udp_config_trans.gate_way = int.from_bytes(random.randbytes(IP_ADDR_LEN), 'big')
        print(f"Udp Config: src_mac = {str2mac(self.local_mac)} src_ip = {ltoa(udp_config_trans.ip_addr)}")
        await self.udp_config_src.send(udp_config_trans)
        

    async def send(self, pkt):
        payload = raw(pkt[UDP].payload)[:-4]
        
        udp_meta = UdpIpMetaTransation()
        udp_meta.ip_addr  = atol(pkt[IP].dst)
        udp_meta.dst_port = pkt[UDP].dport
        udp_meta.src_port = pkt[UDP].sport
        udp_meta.data_len = len(payload)
        
        mac_meta = MacMetaTransaction()
        mac_meta.mac_addr = int.from_bytes(mac2str(pkt[Ether].dst), 'big')
        mac_meta.eth_type = pkt[Ether].type
        
        await self.udp_meta_src.send(udp_meta)
        await self.mac_meta_src.send(mac_meta)
        frame = AxiStreamFrame()
        frame.tdata = payload
        await self.data_stream_src.send(frame)

    async def recv(self):
        frame = await self.axi_stream_sink.recv()
        return bytes(frame.tdata)
    
    def gen_random_pkt(self):
        bind_layers(UDP, BTH)
        
        dst_mac = random.randbytes(MAC_ADDR_LEN)
        dst_ip_int = int.from_bytes(random.randbytes(IP_ADDR_LEN), 'big')
        src_ip_int = int.from_bytes(self.local_ip, 'big')
        dst_port_int = int.from_bytes(random.randbytes(UDP_PORT_LEN), 'big')
        src_port_int = int.from_bytes(random.randbytes(UDP_PORT_LEN), 'big')
        header = Ether(dst=str2mac(dst_mac), src=str2mac(self.local_mac))
        header = header / IP(dst=ltoa(dst_ip_int), src=ltoa(src_ip_int))
        header = header / UDP(dport=dst_port_int, sport=src_port_int, chksum=0)
        header = header / BTH()
        
        payload_size = random.randint(self.min_payload_len, self.max_payload_len - 1)
        payload = random.randbytes(payload_size)

        packet = Ether(raw(header/Raw(payload)))
        return packet

    async def drive_dut_input(self):
        for case_idx in range(self.cases_num):
            packet = self.gen_random_pkt()
            await self.send(packet)
            self.ref_buffer.put(raw(packet))
            print(f"Send {case_idx} Packet: ", packet)
    
    async def check_dut_output(self):
        bind_layers(UDP, BTH)
        for case_idx in range(self.cases_num):
            dut_packet = await self.recv()
            ref_packet = self.ref_buffer.get()
            
            if(dut_packet != ref_packet):
                print(f"DUT Packet {case_idx}: ", dut_packet.hex("-"))
                print(f"REF Packet {case_idx}: ", ref_packet.hex("-"))
                Ether(dut_packet).show()
                Ether(ref_packet).show()
            assert raw(dut_packet)==raw(ref_packet), f"Test Case {case_idx} Fail"


@cocotb.test(timeout_time=500000, timeout_unit="ns")
async def runRdmaUdpIpEthTxTester(dut):
    
    tester = RdmaUdpIpEthTxTester(dut, CASES_NUM, MIN_PAYLOAD_LEN, MAX_PAYLOAD_LEN)
    await tester.gen_clock()
    await tester.gen_reset()
    await tester.config_udp()
    drive_thread = cocotb.start_soon(tester.drive_dut_input())
    check_thread = cocotb.start_soon(tester.check_dut_output())
    print("Start testing!")
    await check_thread
    print(f"Pass all {tester.cases_num} successfully")


def test_RdmaUdpIpEthTx():
    toplevel = "mkRawRdmaUdpIpEthTx"
    module = os.path.splitext(os.path.basename(__file__))[0]
    test_dir = os.path.abspath(os.path.dirname(__file__))
    sim_build = os.path.join(test_dir, "build")
    v_top_file = os.path.join(test_dir, "verilog", f"{toplevel}.v")
    verilog_sources = [v_top_file]
    cocotb_test.simulator.run(
        toplevel = toplevel,
        module = module,
        verilog_sources = verilog_sources,
        python_search = test_dir,
        sim_build = sim_build,
        work_dir = test_dir,
        timescale="1ns/1ps"
    )

if __name__ == "__main__":
    test_RdmaUdpIpEthTx()

