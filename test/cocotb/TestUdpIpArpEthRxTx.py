import os
import random

from scapy.all import *

import cocotb_test.simulator
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
from cocotbext.axi import AxiStreamBus, AxiStreamSource, AxiStreamSink, AxiStreamFrame

from TestUtils import *

TEST_CASE_NUM = 64
MAX_PAYLOAD_SIZE = 1024


class UdpIpArpEthRxTxTester:
    def __init__(self, dut, target_ip, udp_port, cases_num, max_payload_size):
        self.dut = dut
        
        self.log = logging.getLogger("cocotb.tb")
        self.log.setLevel(logging.DEBUG)
        
        self.cases_num = cases_num
        self.max_payload_size = max_payload_size
        
        self.ref_udp_meta_buf = Queue(maxsize = self.cases_num)
        self.ref_data_stream_buf = Queue(maxsize = self.cases_num)
        

        self.reset_val = False
        self.clock = self.dut.CLK
        self.reset = self.dut.RST_N
        self.udp_config_dut_src = UdpConfigSource(UdpConfigBus.from_prefix(dut, "s_udp_config"), self.clock, self.reset, False)
        # Rx
        self.udp_meta_src = UdpIpMetaDataSource(UdpIpMetaDataBus.from_prefix(dut, "s_udp_meta"), self.clock, self.reset, False)
        self.data_stream_src = AxiStreamSource(AxiStreamBus.from_prefix(dut, "s_data_stream"), self.clock, self.reset, False)
        self.axi_stream_sink = AxiStreamSink(AxiStreamBus.from_prefix(dut, "m_axi_stream"), self.clock, self.reset, False)
        # Tx
        self.udp_meta_sink = UdpIpMetaDataSink(UdpIpMetaDataBus.from_prefix(dut, "m_udp_meta"), self.clock, self.reset, False)
        self.data_stream_sink = AxiStreamSink(AxiStreamBus.from_prefix(dut, "m_data_stream"), self.clock, self.reset, False)
        self.axi_stream_src = AxiStreamSource(AxiStreamBus.from_prefix(dut, "s_axi_stream"), self.clock, self.reset, False)
        
        # Config
        self.local_ip = get_default_ip_addr()
        self.local_mac = get_default_mac_addr()
        self.gate_way = get_default_gateway()
        self.net_mask = get_default_netmask()
        self.target_ip = target_ip
        self.udp_port = udp_port

        print("Target IP: ", self.target_ip)
        print("Udp Port: ", self.udp_port)
        
    async def gen_clock(self):
        await cocotb.start(Clock(self.clock, 10, 'ns').start())
        
    async def gen_reset(self):
        self.reset.setimmediatevalue(self.reset_val)
        await RisingEdge(self.clock)
        await RisingEdge(self.clock)
        self.reset.value = not self.reset_val
        await RisingEdge(self.clock)
        await RisingEdge(self.clock)
        
    async def config_dut(self):
        udpConfig = UdpConfigTransation()
        udpConfig.mac_addr = int.from_bytes(mac2str(self.local_mac), 'big')
        udpConfig.ip_addr  = atol(self.local_ip)
        udpConfig.net_mask = atol(self.net_mask)
        udpConfig.gate_way = atol(self.gate_way)
        await self.udp_config_dut_src.send(udpConfig)
        print("Set Udp Configuration Reg Succesfully:", udpConfig)


    async def drive_dut_input(self):
        print("Start sending UdpMeta and payload")
        for case_idx in range(self.cases_num):
            payload_len = random.randint(64, self.max_payload_size)
            payload = random.randbytes(payload_len)
            
            udp_meta_trans = UdpIpMetaDataTransation()
            udp_meta_trans.ip_addr = atol(self.target_ip)
            udp_meta_trans.dst_port = self.udp_port
            udp_meta_trans.src_port = self.udp_port
            udp_meta_trans.data_len = payload_len
            await self.udp_meta_src.send(udp_meta_trans)
            await self.data_stream_src.send(AxiStreamFrame(tdata=payload))
            
            print(f"Send {case_idx} Udp Meta:{udp_meta_trans}")
            print(f"Send {case_idx} Payload: {payload}")
            
            self.ref_udp_meta_buf.put(udp_meta_trans)
            self.ref_data_stream_buf.put(payload)
    
    
    async def check_dut_output(self):
        print("Start checking UdpMeta and payload")
        for case_idx in range(self.cases_num):
            dut_udp_meta = await self.udp_meta_sink.recv()
            dut_payload = await self.data_stream_sink.recv()
            dut_payload = bytes(dut_payload)
            
            ref_udp_meta = self.ref_udp_meta_buf.get()
            ref_payload = self.ref_data_stream_buf.get()
            
            print(f"Dut {case_idx} Udp Meta:{dut_udp_meta}")
            print(f"Dut {case_idx} Payload:{dut_payload}")
            
            udp_meta_eq = is_udp_ip_meta_equal(dut_udp_meta, ref_udp_meta)
            packet_eq = udp_meta_eq & (ref_payload == dut_payload)
            if not packet_eq:
                print(f"Ref {case_idx} Udp Meta:{ref_udp_meta}")
                print(f"Ref {case_idx} Payload:{ref_payload}")
            
            assert packet_eq, "Receive Incorrect packets"
    
    
    async def send_and_recv_eth(self):
        print("Start sending and receiving ethernet packet")
        pkt_idx = 0
        while True:
            axi_frame = await self.axi_stream_sink.recv()
            packet = Ether(bytes(axi_frame.tdata))
            print(f"Scapy Send {pkt_idx} Packet:")
            packet.show()
            resp, _ = srp(packet, verbose=True)
            for _, r in resp:
                recv_pkt = r
            
            print(f"Scapy Recv {pkt_idx} Packet:")
            recv_pkt.show()
            
            axi_frame = AxiStreamFrame(tdata=raw(recv_pkt))
            await self.axi_stream_src.send(axi_frame)
            print(f"Successfully send and receive {pkt_idx}")
            pkt_idx += 1
            time.sleep(1)
            

@cocotb.test(timeout_time=1000000, timeout_unit="ns")
async def runUdpEthRxTester(dut):
    target_ip = os.getenv("TARGET_IP")
    udp_port = int(os.getenv("UDP_PORT"))
    tester = UdpIpArpEthRxTxTester(
        dut = dut,
        target_ip = target_ip,
        udp_port = udp_port,
        cases_num = TEST_CASE_NUM,
        max_payload_size = MAX_PAYLOAD_SIZE
    )
    await tester.gen_clock()
    await tester.gen_reset()
    await tester.config_dut()
    
    drive_thread = cocotb.start_soon(tester.drive_dut_input())
    check_thread = cocotb.start_soon(tester.check_dut_output())
    srp_thread = cocotb.start_soon(tester.send_and_recv_eth())
    
    print("Start Testing UdpIpArpEthRxTx!!!")
    await check_thread
    print(f"Pass all {tester.cases_num} testcases successfully!!!")


def test_UdpIpArpEthRxTx(target_ip, udp_port):
    toplevel = "mkRawUdpIpArpEthRxTx"
    module = os.path.splitext(os.path.basename(__file__))[0]
    test_dir = os.path.abspath(os.path.dirname(__file__))
    sim_build = os.path.join(test_dir, "build")
    v_top_file = os.path.join(test_dir,"verilog", toplevel + ".v")
    verilog_sources = [v_top_file]
    
    cocotb_test.simulator.run(
        toplevel = toplevel,
        module = module,
        verilog_sources = verilog_sources,
        python_search = test_dir,
        sim_build = sim_build,
        timescale = "1ns/1ps",
        extra_env = {"TARGET_IP":target_ip, "UDP_PORT":udp_port}
    )

if __name__ == '__main__':
    assert len(sys.argv) == 3, "Usage: python3 TestUdpIpArpEthRxTx.py IP_ADDR UDP_PORT"
    target_ip = sys.argv[1]
    udp_port = sys.argv[2]
    test_UdpIpArpEthRxTx(target_ip, udp_port)