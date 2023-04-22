import itertools
import logging
import os
import random

from scapy.all import *

import cocotb_test.simulator
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
from cocotb.regression import TestFactory

from cocotbext.axi import AxiStreamBus, AxiStreamSource, AxiStreamSink, AxiStreamFrame
from cocotbext.axi.stream import define_stream


UdpConfigBus, UdpConfigTransation, UdpConfigSource, UdpConfigSink, UdpConfigMonitor = define_stream(
    "UdpConfig", signals=["valid", "ready", "mac_addr", "ip_addr"]
)

UdpMetaBus, UdpMetaTransation, UdpMetaSource, UdpMetaSink, UdpMetaMonitor = define_stream(
    "UdpMeta", signals=["valid", "ready", "ip_addr", "dst_port", "src_port", "data_len"]
)

MacMetaBus, MacMetaTransaction, MacMetaSource, MacMetaSink, MacMetaMonitor = define_stream(
    "MacMeta", signals=["valid", "ready", "mac_addr", "eth_type"]
)

class UdpEthTxTester:
    def __init__(self, dut):
        self.dut = dut
        
        self.log = logging.getLogger("cocotb.tb")
        self.log.setLevel(logging.DEBUG)
        
        cocotb.start_soon(Clock(dut.clk, 10, "ns").start())
        self.cases_num = 20
        self.max_payload_size = 512
        self.ref_buffer = Queue(maxsize = self.cases_num)
        
        self.udp_config_src = UdpConfigSource(UdpConfigBus.from_prefix(dut, "s_udp_config"), dut.clk, dut.reset_n, False)
        self.udp_meta_src = UdpMetaSource(UdpMetaBus.from_prefix(dut, "s_udp_meta"), dut.clk, dut.reset_n, False)
        self.mac_meta_src = MacMetaSource(MacMetaBus.from_prefix(dut, "s_mac_meta"), dut.clk, dut.reset_n, False)
        
        self.data_stream_src = AxiStreamSource(AxiStreamBus.from_prefix(dut, "s_data_stream"), dut.clk, dut.reset_n, False)
        self.axi_stream_sink = AxiStreamSink(AxiStreamBus.from_prefix(dut, "m_axi_stream"), dut.clk, dut.reset_n, False)
        
    async def clock(self):
        await cocotb.start(Clock(self.dut.clk, 10, 'ns').start())
        
    async def reset(self):
        self.dut.reset_n.value = 0
        await RisingEdge(self.dut.clk)
        await RisingEdge(self.dut.clk)
        self.dut.reset_n.value = 1
        await RisingEdge(self.dut.clk)
        await RisingEdge(self.dut.clk)
    
    async def send(self, pkt, payload):
        udp_config = UdpConfigTransation()
        udp_config.mac_addr = int.from_bytes(mac2str(pkt[Ether].src), 'big')
        udp_config.ip_addr = atol(pkt[IP].src)
        
        udp_meta = UdpMetaTransation()
        udp_meta.ip_addr  = atol(pkt[IP].dst)
        udp_meta.dst_port = pkt[UDP].dport
        udp_meta.src_port = pkt[UDP].sport
        udp_meta.data_len = len(payload)
        
        mac_meta = MacMetaTransaction()
        mac_meta.mac_addr = int.from_bytes(mac2str(pkt[Ether].dst), 'big')
        mac_meta.eth_type = pkt[Ether].type
        
        await self.udp_config_src.send(udp_config)
        await self.udp_meta_src.send(udp_meta)
        await self.mac_meta_src.send(mac_meta)
        frame = AxiStreamFrame()
        frame.tdata = payload
        await self.data_stream_src.send(frame)
    
    async def recv(self):
        frame = await self.axi_stream_sink.recv()
        return bytes(frame.tdata)

    
    async def drive_dut_input(self):
        #
        header = Ether(dst="d8:9c:67:9c:48:29", src="6a:80:36:f9:9e:56")
        header = header / IP(dst="10.20.239.27", src="127.0.0.1")
        header = header / UDP(dport=666, sport=8000)
        for case_idx in range(self.cases_num):
            payload_size = random.randint(46, self.max_payload_size - 1)
            print(payload_size)
            payload = random.randbytes(payload_size)
            packet = Ether(raw(header/Raw(payload)))
            packet[UDP].chksum = 0
            await self.send(packet, payload)
            self.ref_buffer.put(raw(packet))
            print(f"Send Packet {case_idx}: ", packet)
    
    async def check_dut_output(self):
        for case_idx in range(self.cases_num):
            dut_packet = await self.recv()
            ref_packet = self.ref_buffer.get()
            
            if(dut_packet != ref_packet):
                print(f"DUT Packet {case_idx}: ", dut_packet.hex("-"))
                print(f"REF Packet {case_idx}: ", ref_packet.hex("-"))
                Ether(dut_packet).show()
                Ether(ref_packet).show()
            assert raw(dut_packet)==raw(ref_packet), f"Test Case {case_idx} Fail"


@cocotb.test(timeout_time=100000, timeout_unit="ns")
async def runUdpEthTxTester(dut):
    
    tester = UdpEthTxTester(dut)
    await tester.clock()
    await tester.reset()
    drive_thread = cocotb.start_soon(tester.drive_dut_input())
    check_thread = cocotb.start_soon(tester.check_dut_output())
    print("Start testing!")
    await check_thread
    print(f"Pass all {tester.cases_num} successfully")


def test_UdpEthTx():
    toplevel = "mkUdpEthTxWrapper"
    module = os.path.splitext(os.path.basename(__file__))[0]
    test_dir = os.path.abspath(os.path.dirname(__file__))
    sim_build = os.path.join(test_dir, "build")
    v_wrapper_file = os.path.join(test_dir, "verilog", f"{toplevel}.v")
    v_source_file  = os.path.join(test_dir, "verilog", "mkUdpEthTx.v")
    v_lib_file = os.path.join(test_dir, "lib", "FIFO2.v")
    verilog_sources = [v_wrapper_file, v_source_file]
    cocotb_test.simulator.run(
        toplevel = toplevel,
        module = module,
        verilog_sources = verilog_sources,
        python_search = test_dir,
        sim_build = sim_build,
        timescale="1ns/1ps"
    )



