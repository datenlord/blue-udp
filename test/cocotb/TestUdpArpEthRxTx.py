import os
import random

from scapy.all import *

import cocotb_test.simulator
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge


from cocotbext.axi import AxiStreamBus, AxiStreamSource, AxiStreamSink, AxiStreamFrame
from cocotbext.axi.stream import define_stream

from Utils import *


UdpConfigBus, UdpConfigTransation, UdpConfigSource, UdpConfigSink, UdpConfigMonitor = define_stream(
    "UdpConfig", signals=["valid", "ready", "mac_addr", "ip_addr", "net_mask", "gate_way"]
)

UdpMetaBus, UdpMetaTransation, UdpMetaSource, UdpMetaSink, UdpMetaMonitor = define_stream(
    "UdpMeta", signals=["valid", "ready", "ip_addr", "dst_port", "src_port", "data_len"]
)


class UdpArpEthRxTxTester:
    def __init__(self, dut, local_ip, loacal_mac, target_ip, gate_way, net_mask, sport, dport):
        self.dut = dut
        
        self.log = logging.getLogger("cocotb.tb")
        self.log.setLevel(logging.DEBUG)
        
        self.cases_num = 20
        self.max_payload_size = 512
        
        self.ref_udp_meta_buf = Queue(maxsize = self.cases_num + 3)
        self.ref_data_stream_buf = Queue(maxsize = self.cases_num + 3)
        


        self.udp_config_src = UdpConfigSource(UdpConfigBus.from_prefix(dut, "s_udp_config"), dut.clk, dut.reset_n, False)
        # Rx
        self.udp_meta_src = UdpMetaSource(UdpMetaBus.from_prefix(dut, "s_udp_meta"), dut.clk, dut.reset_n, False)
        self.data_stream_src = AxiStreamSource(AxiStreamBus.from_prefix(dut, "s_data_stream"), dut.clk, dut.reset_n, False)
        self.axi_stream_sink = AxiStreamSink(AxiStreamBus.from_prefix(dut, "m_axi_stream"), dut.clk, dut.reset_n, False)
        
        # Tx
        self.udp_meta_sink = UdpMetaSink(UdpMetaBus.from_prefix(dut, "m_udp_meta"), dut.clk, dut.reset_n, False)
        self.data_stream_sink = AxiStreamSink(AxiStreamBus.from_prefix(dut, "m_data_stream"), dut.clk, dut.reset_n, False)
        self.axi_stream_src = AxiStreamSource(AxiStreamBus.from_prefix(dut, "s_axi_stream"), dut.clk, dut.reset_n, False)
        
        # Config
        self.local_ip = local_ip
        self.local_mac = loacal_mac
        self.target_ip = target_ip
        self.gate_way = gate_way
        self.net_mask = net_mask
        self.sport = sport
        self.dport = dport
    
    def is_udp_meta_equal(self, dut, ref):
        is_equal = (dut.ip_addr == ref.ip_addr)
        is_equal = is_equal & (dut.dst_port == ref.dst_port)
        is_equal = is_equal & (dut.src_port == ref.src_port)
        is_equal = is_equal & (dut.data_len == ref.data_len)
        return is_equal
        
    async def clock(self):
        await cocotb.start(Clock(self.dut.clk, 10, 'ns').start())
        
    async def reset(self):
        self.dut.reset_n.setimmediatevalue(0)
        await RisingEdge(self.dut.clk)
        await RisingEdge(self.dut.clk)
        await RisingEdge(self.dut.clk)
        self.dut.reset_n.value = 1
        await RisingEdge(self.dut.clk)
        await RisingEdge(self.dut.clk)
        await RisingEdge(self.dut.clk)
        
    async def config(self):
        udpConfig = UdpConfigTransation();
        udpConfig.mac_addr = int.from_bytes(mac2str(self.local_mac), 'big')
        udpConfig.ip_addr  = atol(self.local_ip)
        udpConfig.net_mask = atol(self.net_mask)
        udpConfig.gate_way = atol(self.gate_way)
        await self.udp_config_src.send(udpConfig)
        print("Set Udp Configuration Reg Succesfully:", udpConfig)


    async def drive_dut_input(self):
        print("Start sending UdpMeta and payload")
        for case_idx in range(self.cases_num):
            payload_len = random.randint(64, self.max_payload_size)
            payload = random.randbytes(payload_len)
            
            udp_meta_trans = UdpMetaTransation()
            udp_meta_trans.ip_addr = atol(self.target_ip)
            udp_meta_trans.dst_port = self.dport
            udp_meta_trans.src_port = self.sport
            udp_meta_trans.data_len = payload_len
            await self.udp_meta_src.send(udp_meta_trans)
            await self.data_stream_src.send(AxiStreamFrame(tdata=payload))
            
            print(f"Send {case_idx} Udp Meta:{udp_meta_trans}")
            print(f"Send {case_idx} Payload: {payload}")
            
            recv_udp_meta = copy.copy(udp_meta_trans)
            recv_udp_meta.dst_port = self.sport
            recv_udp_meta.src_port = self.dport
            self.ref_udp_meta_buf.put(recv_udp_meta)
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
            
            udp_meta_eq = self.is_udp_meta_equal(dut_udp_meta, ref_udp_meta)
            packet_eq = udp_meta_eq & (ref_payload == dut_payload)
            if not packet_eq:
                print(f"Ref {case_idx} Udp Meta:{ref_udp_meta}")
                print(f"Ref {case_idx} Payload:{ref_payload}")
            
            assert packet_eq
    
    
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
            print(f"Successfully recv {pkt_idx}")
            pkt_idx += 1
            time.sleep(1)
            

@cocotb.test(timeout_time=100000, timeout_unit="ns")
async def runUdpEthRxTester(dut):
    
    tester = UdpArpEthRxTxTester(
        dut = dut,
        local_ip = get_default_ip_addr(),
        loacal_mac = get_default_mac_addr(),
        target_ip = "10.19.134.191",
        gate_way = get_default_gateway(),
        net_mask = get_default_netmask(),
        sport = 5555,
        dport = 6666
    )
    await tester.clock()
    await tester.reset()
    await tester.config()
    
    drive_thread = cocotb.start_soon(tester.drive_dut_input())
    check_thread = cocotb.start_soon(tester.check_dut_output())
    srp_thread = cocotb.start_soon(tester.send_and_recv_eth())
    
    print("Start testing!")
    await check_thread
    print(f"Pass all {tester.cases_num} successfully")


def test_UdpArpEthRxTx():
    toplevel = "mkUdpArpEthRxTxWrapper"
    module = os.path.splitext(os.path.basename(__file__))[0]
    test_dir = os.path.abspath(os.path.dirname(__file__))
    sim_build = os.path.join(test_dir, "build")
    v_wrapper_file = os.path.join(test_dir, "verilog", f"{toplevel}.v")
    v_source_file = os.path.join(test_dir,"verilog", "mkUdpArpEthRxTx.v")
    verilog_sources = [v_wrapper_file, v_source_file]
    
    cocotb_test.simulator.run(
        toplevel = toplevel,
        module = module,
        verilog_sources = verilog_sources,
        python_search = test_dir,
        sim_build = sim_build,
        timescale="1ns/1ps"
    )

if __name__ == '__main__':
    test_UdpArpEthRxTx()