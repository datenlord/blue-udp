import logging
import os
import random

import cocotb_test.simulator
import cocotb

from scapy.all import *;
from scapy.contrib.roce import *

from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
from cocotb.regression import TestFactory

from cocotbext.axi import AxiStreamBus, AxiStreamSource, AxiStreamSink, AxiStreamFrame
from cocotbext.axi.stream import define_stream

from TestUtils import *

MIN_PAYLOAD_LEN = 46
MAX_PAYLOAD_LEN = 2048
CASES_NUM = 1024

class RdmaUdpIpEthRxTester:
    def __init__(self, dut, cases_num, min_payload_len, max_payload_len):
        self.dut = dut
        
        self.log = logging.getLogger("cocotb.tb")
        self.log.setLevel(logging.DEBUG)
        
        self.cases_num = cases_num
        self.min_payload_len = min_payload_len
        self.max_payload_len = max_payload_len
        self.ref_udp_meta_buf = Queue(maxsize = self.cases_num)
        self.ref_mac_meta_buf = Queue(maxsize = self.cases_num)
        self.ref_data_stream_buf = Queue(maxsize = self.cases_num)

        self.clock = self.dut.CLK
        self.resetn = self.dut.RST_N
        self.udp_config_src = UdpConfigSource(UdpConfigBus.from_prefix(dut, "s_udp_config"), self.clock, self.resetn, False)
        self.axi_stream_src = AxiStreamSource(AxiStreamBus.from_prefix(dut, "s_axis"), self.clock, self.resetn, False)
        
        self.data_stream_sink = AxiStreamSink(AxiStreamBus.from_prefix(dut, "m_data_stream"), self.clock, self.resetn, False)
        self.udp_ip_meta_sink = UdpIpMetaDataSink(UdpIpMetaDataBus.from_prefix(dut, "m_udp_meta"), self.clock, self.resetn, False)
        self.mac_meta_sink = MacMetaDataSink(MacMetaDataBus.from_prefix(dut, "m_mac_meta"), self.clock, self.resetn, False)
        
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
        self.local_mac = random.randbytes(MAC_ADDR_BYTE_NUM)
        self.local_ip  = random.randbytes(IP_ADDR_BYTE_NUM)
        self.net_mask = random.randbytes(IP_ADDR_BYTE_NUM)
        self.gate_way = random.randbytes(IP_ADDR_BYTE_NUM)
        udpConfig = UdpConfigTransation()
        udpConfig.mac_addr = int.from_bytes(self.local_mac, 'big')
        udpConfig.ip_addr  = int.from_bytes(self.local_ip, 'big')
        udpConfig.net_mask = int.from_bytes(self.net_mask, 'big')
        udpConfig.gate_way = int.from_bytes(self.gate_way, 'big')
        await self.udp_config_src.send(udpConfig)
        
    def gen_random_packet(self):
        bind_layers(UDP, BTH)

        src_mac = random.randbytes(MAC_ADDR_BYTE_NUM)
        src_ip = random.randbytes(IP_ADDR_BYTE_NUM)
        sport = random.randbytes(UDP_PORT_BYTE_NUM)
        dport = random.randbytes(UDP_PORT_BYTE_NUM)
        payload_size = random.randint(self.min_payload_len, self.max_payload_len - 1)
        payload = random.randbytes(payload_size)
        
        header = Ether(dst=str2mac(self.local_mac), src=str2mac(src_mac))
        dst_ip_int = int.from_bytes(self.local_ip, 'big')
        src_ip_int = int.from_bytes(src_ip, 'big')
        header = header / IP(dst=ltoa(dst_ip_int), src=ltoa(src_ip_int))
        header = header / UDP(dport=int.from_bytes(dport, 'big'), sport=int.from_bytes(sport, 'big'), chksum=0)
        header = header / BTH()
        packet = Ether(raw(header/Raw(payload)))
        
        return packet

    async def drive_dut_input(self):
        for case_idx in range(self.cases_num):
            packet = self.gen_random_packet()
            axi_frame = AxiStreamFrame(tdata=raw(packet))
            await self.axi_stream_src.send(axi_frame)
            
            mac_meta_trans = MacMetaDataTransaction()
            mac_meta_trans.mac_addr = int.from_bytes(mac2str(packet[Ether].src), 'big')
            mac_meta_trans.eth_type = packet[Ether].type
            self.ref_mac_meta_buf.put(mac_meta_trans)
            
            udp_meta_trans = UdpIpMetaDataTransation()
            udp_meta_trans.ip_addr = atol(packet[IP].src)
            udp_meta_trans.dst_port = packet[UDP].dport
            udp_meta_trans.src_port = packet[UDP].sport

            payload = raw(packet[UDP].payload)[:-4]
            udp_meta_trans.data_len = len(payload)
            self.ref_udp_meta_buf.put(udp_meta_trans)
            self.ref_data_stream_buf.put(payload)
            self.log.info(f"Send Packet {case_idx}: {packet}")
            

    async def check_mac_meta(self):
        self.mac_meta_sink.clear()
        for case_idx in range(self.cases_num):
            dut_meta = await self.mac_meta_sink.recv()
            ref_meta = self.ref_mac_meta_buf.get()
            equal = is_mac_meta_equal(dut_meta, ref_meta)
            if not equal:
                print("Dut MacMetaData: ", dut_meta)
                print("Ref MacMetaData: ", ref_meta)
            assert equal, f"Test Case {case_idx}: check MacMetaData failed"
            self.log.info(f"Test Case {case_idx}: Pass MacMetaData check")
    
    async def check_udp_ip_meta(self):
        self.udp_ip_meta_sink.clear()
        for case_idx in range(self.cases_num):
            dut_meta = await self.udp_ip_meta_sink.recv()
            ref_meta = self.ref_udp_meta_buf.get()
            equal = is_udp_ip_meta_equal(dut_meta, ref_meta)
            if not equal:
                print("Dut UdpIpMetaData: ", dut_meta)
                print("Ref UdpIpMetaData: ", ref_meta)
            assert equal, f"Test Case {case_idx}: check UdpIpMetaData failed"
            self.log.info(f"Test Case {case_idx}: Pass UdpIpMetaData check")

    async def check_data_stream(self):
        for case_idx in range(self.cases_num):
            dut_data_stream = await self.data_stream_sink.recv()
            dut_data_stream = bytes(dut_data_stream.tdata)
            ref_data_stream = self.ref_data_stream_buf.get()
            if(dut_data_stream != ref_data_stream):
                print(f"Dut DataStream Size {len(dut_data_stream)}")
                print("Dut DataStream: ", dut_data_stream.hex('-'))
                print(f"Ref DataStream Size {len(ref_data_stream)}")
                print("Ref DataStream: ", ref_data_stream.hex('-'))
                print(f"Test Case {case_idx}: check DataStream failed")
            
            assert dut_data_stream == ref_data_stream    
            self.log.info(f"Test Case {case_idx}: Pass DataStream check")
    
    async def check_dut_output(self):
        check_mac_meta = await cocotb.start(self.check_mac_meta())
        check_udp_ip_meta = await cocotb.start(self.check_udp_ip_meta())
        check_data_stream = await cocotb.start(self.check_data_stream())
        await check_data_stream

@cocotb.test(timeout_time=1000000000, timeout_unit="ns")
async def runRdmaUdpIpEthRxTester(dut):
    
    tester = RdmaUdpIpEthRxTester(dut, CASES_NUM, MIN_PAYLOAD_LEN, MAX_PAYLOAD_LEN)
    await tester.gen_clock()
    await tester.gen_reset()
    await tester.config()
    drive_thread = cocotb.start_soon(tester.drive_dut_input())
    check_thread = cocotb.start_soon(tester.check_dut_output())
    tester.log.info("Start testing!")
    await check_thread
    tester.log.info(f"Pass all {tester.cases_num} testcases successfully")


def test_RdmaUdpIpEthRx():
    toplevel = "mkRawRdmaUdpIpEthRx"
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
        timescale="1ns/1ps",
        work_dir=test_dir
    )

if __name__ == "__main__":
    test_RdmaUdpIpEthRx()


