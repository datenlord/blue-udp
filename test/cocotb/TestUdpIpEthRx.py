import logging
import os
import random

import cocotb_test.simulator
import cocotb

import scapy.all

from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
from cocotb.regression import TestFactory

from cocotbext.axi import AxiStreamBus, AxiStreamSource, AxiStreamSink, AxiStreamFrame
from cocotbext.axi.stream import define_stream


UdpConfigBus, UdpConfigTransation, UdpConfigSource, UdpConfigSink, UdpConfigMonitor = define_stream(
    "UdpConfig", signals=["valid", "ready", "mac_addr", "ip_addr", "net_mask", "gate_way"]
)

UdpMetaBus, UdpMetaTransation, UdpMetaSource, UdpMetaSink, UdpMetaMonitor = define_stream(
    "UdpMeta", signals=["valid", "ready", "ip_addr", "dst_port", "src_port", "data_len"]
)

MacMetaBus, MacMetaTransaction, MacMetaSource, MacMetaSink, MacMetaMonitor = define_stream(
    "MacMeta", signals=["valid", "ready", "mac_addr", "eth_type"]
)
        

class UdpIpEthRxTester:
    def __init__(self, dut):
        self.dut = dut
        
        self.log = logging.getLogger("cocotb.tb")
        self.log.setLevel(logging.DEBUG)
        
        self.cases_num = 512
        self.max_payload_size = 512
        self.ref_udp_meta_buf = Queue(maxsize = self.cases_num)
        self.ref_mac_meta_buf = Queue(maxsize = self.cases_num)
        self.ref_data_stream_buf = Queue(maxsize = self.cases_num)

        self.clock = self.dut.CLK
        self.resetn = self.dut.RST_N
        self.udp_config_src = UdpConfigSource(UdpConfigBus.from_prefix(dut, "s_udp_config"), self.clock, self.resetn, False)
        self.axi_stream_src = AxiStreamSource(AxiStreamBus.from_prefix(dut, "s_axis"), self.clock, self.resetn, False)
        
        self.data_stream_sink = AxiStreamSink(AxiStreamBus.from_prefix(dut, "m_data_stream"), self.clock, self.resetn, False)
        self.udp_meta_sink = UdpMetaSink(UdpMetaBus.from_prefix(dut, "m_udp_meta"), self.clock, self.resetn, False)
        self.mac_meta_sink = MacMetaSink(MacMetaBus.from_prefix(dut, "m_mac_meta"), self.clock, self.resetn, False)
        
    async def gen_clock(self):
        await cocotb.start(Clock(self.clock, 10, 'ns').start())
        
    async def gen_reset(self):
        self.resetn.value = 0
        await RisingEdge(self.clock)
        await RisingEdge(self.clock)
        await RisingEdge(self.clock)
        self.resetn.value = 1
        await RisingEdge(self.clock)
        await RisingEdge(self.clock)
        await RisingEdge(self.clock)
        
    async def config(self):
        self.local_mac = random.randbytes(6)
        self.local_ip  = random.randbytes(4)
        self.net_mask = random.randbytes(4)
        self.gate_way = random.randbytes(4)
        udpConfig = UdpConfigTransation()
        udpConfig.mac_addr = int.from_bytes(self.local_mac, 'big')
        udpConfig.ip_addr  = int.from_bytes(self.local_ip, 'big')
        udpConfig.net_mask = int.from_bytes(self.net_mask, 'big')
        udpConfig.gate_way = int.from_bytes(self.gate_way, 'big')
        await self.udp_config_src.send(udpConfig)
        
    def gen_random_packet(self):
        src_mac = random.randbytes(6)
        src_ip = random.randbytes(4)
        sport = random.randbytes(2)
        dport = random.randbytes(2)
        payload_size = random.randint(46, self.max_payload_size - 1)
        payload = random.randbytes(payload_size)
        
        header = Ether(dst=str2mac(self.local_mac), src=str2mac(src_mac))
        dst_ip_int = int.from_bytes(self.local_ip, 'big')
        src_ip_int = int.from_bytes(src_ip, 'big')
        header = header / IP(dst=ltoa(dst_ip_int), src=ltoa(src_ip_int))
        header = header / UDP(dport=int.from_bytes(dport, 'big'), sport=int.from_bytes(sport, 'big'))
        packet = Ether(raw(header/Raw(load=payload)))
        packet[UDP].chksum = 0
        
        return packet, payload
    
    def is_udp_meta_equal(self, dut, ref):
        is_equal = (dut.ip_addr == ref.ip_addr)
        is_equal = is_equal & (dut.dst_port == ref.dst_port)
        is_equal = is_equal & (dut.src_port == ref.src_port)
        is_equal = is_equal & (dut.data_len == ref.data_len)
        return is_equal
    
    def is_mac_meta_equal(self, dut, ref):
        return (dut.mac_addr == ref.mac_addr) & (dut.eth_type == ref.eth_type)

    async def drive_dut_input(self):
        for case_idx in range(self.cases_num):
            packet, payload = self.gen_random_packet()
            axi_frame = AxiStreamFrame(tdata=raw(packet))
            await self.axi_stream_src.send(axi_frame)
            
            mac_meta_trans = MacMetaTransaction()
            mac_meta_trans.mac_addr = int.from_bytes(mac2str(packet[Ether].src), 'big')
            mac_meta_trans.eth_type = packet[Ether].type
            self.ref_mac_meta_buf.put(mac_meta_trans)
            
            udp_meta_trans = UdpMetaTransation()
            udp_meta_trans.ip_addr = atol(packet[IP].src)
            udp_meta_trans.dst_port = packet[UDP].dport
            udp_meta_trans.src_port = packet[UDP].sport
            udp_meta_trans.data_len = len(payload)
            self.ref_udp_meta_buf.put(udp_meta_trans)
            self.ref_data_stream_buf.put(payload)
            self.log.info(f"Send Packet {case_idx}: {packet}")
            

    async def check_mac_meta(self):
        self.mac_meta_sink.clear()
        for case_idx in range(self.cases_num):
            dut_mac_meta = await self.mac_meta_sink.recv()
            ref_mac_meta = self.ref_mac_meta_buf.get()
            equal = self.is_mac_meta_equal(dut_mac_meta, ref_mac_meta)
            if not equal:
                print("Dut Mac Meta: ", dut_mac_meta)
                print("Ref Mac Meta: ", ref_mac_meta)
            assert equal, f"Test Case {case_idx}: check mac meta failed"
            self.log.info(f"Test Case {case_idx}: Pass mac meta check")
    
    async def check_udp_meta(self):
        self.udp_meta_sink.clear()
        for case_idx in range(self.cases_num):
            dut_udp_meta = await self.udp_meta_sink.recv()
            ref_udp_meta = self.ref_udp_meta_buf.get()
            equal = self.is_udp_meta_equal(dut_udp_meta, ref_udp_meta)
            if not equal:
                print("Dut Udp Meta: ", dut_udp_meta)
                print("Ref Udp Meta: ", ref_udp_meta)
            assert equal, f"Test Case {case_idx}: check udp meta failed"
            self.log.info(f"Test Case {case_idx}: Pass udp meta check")

    async def check_data_stream(self):
        for case_idx in range(self.cases_num):
            dut_data_stream = await self.data_stream_sink.recv()
            dut_data_stream = bytes(dut_data_stream.tdata)
            ref_data_stream = self.ref_data_stream_buf.get()
            if(dut_data_stream != ref_data_stream):
                print(f"Dut Data Stream Size {len(dut_data_stream)}")
                print("Dut Data Stream: ", dut_data_stream.hex('-'))
                print(f"Ref Data Stream Size {len(ref_data_stream)}")
                print("Ref Data Stream: ", ref_data_stream.hex('-'))
                print(f"Test Case {case_idx}: check data stream failed")
            
            assert dut_data_stream == ref_data_stream    
            self.log.info(f"Test Case {case_idx}: Pass data stream check")
    
    async def check_dut_output(self):
        check_mac_meta = await cocotb.start(self.check_mac_meta())
        check_udp_meta = await cocotb.start(self.check_udp_meta())
        check_data_stream = await cocotb.start(self.check_data_stream())
        await check_data_stream

@cocotb.test(timeout_time=500000, timeout_unit="ns")
async def runUdpIpEthRxTester(dut):
    
    tester = UdpIpEthRxTester(dut)
    await tester.gen_clock()
    await tester.gen_reset()
    await tester.config()
    drive_thread = cocotb.start_soon(tester.drive_dut_input())
    check_thread = cocotb.start_soon(tester.check_dut_output())
    tester.log.info("Start testing!")
    await check_thread
    tester.log.info(f"Pass all {tester.cases_num} successfully")


def test_UdpIpEthRx():
    toplevel = "mkRawUdpIpEthRx"
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
        timescale="1ns/1ps"
    )

if __name__ == "__main__":
    test_UdpIpEthRx()


