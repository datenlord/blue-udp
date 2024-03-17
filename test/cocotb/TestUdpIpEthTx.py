import os
import random
import logging

from scapy.all import *
from scapy.contrib.roce import *

import cocotb_test.simulator
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
from cocotbext.axi import AxiStreamBus, AxiStreamSource, AxiStreamSink, AxiStreamFrame

from TestUtils import *

MIN_PAYLOAD_LEN = 46
MAX_PAYLOAD_LEN = 2048
CASES_NUM = 512


class UdpIpEthTxTester:
    def __init__(
        self, dut, cases_num, min_payload_len, max_payload_len, is_support_rdma
    ):
        self.dut = dut

        self.log = logging.getLogger("cocotb.tb")
        self.log.setLevel(logging.DEBUG)

        self.cases_num = cases_num
        self.min_payload_len = min_payload_len
        self.max_payload_len = max_payload_len
        self.is_support_rdma = is_support_rdma
        self.ref_buffer = Queue(maxsize=self.cases_num)
        self.local_ip = random.randbytes(IP_ADDR_BYTE_NUM)
        self.local_mac = random.randbytes(MAC_ADDR_BYTE_NUM)

        self.clock = dut.CLK
        self.resetn = dut.RST_N

        self.udp_config_src = UdpConfigSource(
            UdpConfigBus.from_prefix(dut, "s_udp_config"),
            self.clock,
            self.resetn,
            False,
        )
        self.udp_ip_meta_src = UdpIpMetaDataSource(
            UdpIpMetaDataBus.from_prefix(dut, "s_udp_meta"),
            self.clock,
            self.resetn,
            False,
        )
        self.mac_meta_src = MacMetaDataSource(
            MacMetaDataBus.from_prefix(dut, "s_mac_meta"),
            self.clock,
            self.resetn,
            False,
        )

        self.data_stream_src = AxiStreamSource(
            AxiStreamBus.from_prefix(dut, "s_data_stream"),
            self.clock,
            self.resetn,
            False,
        )
        self.data_stream_src.log.setLevel(logging.WARNING)
        self.axi_stream_sink = AxiStreamSink(
            AxiStreamBus.from_prefix(dut, "m_axis"), self.clock, self.resetn, False
        )
        self.axi_stream_sink.log.setLevel(logging.WARNING)

    async def gen_clock(self):
        await cocotb.start(Clock(self.clock, 10, "ns").start())

    async def gen_reset(self):
        self.resetn.value = 0
        await RisingEdge(self.clock)
        await RisingEdge(self.clock)
        self.resetn.value = 1
        await RisingEdge(self.clock)
        await RisingEdge(self.clock)

    async def config_udp(self):
        udp_config_trans = UdpConfigTransation()
        udp_config_trans.ip_addr = int.from_bytes(self.local_ip, "big")
        udp_config_trans.mac_addr = int.from_bytes(self.local_mac, "big")
        udp_config_trans.net_mask = int.from_bytes(
            random.randbytes(IP_ADDR_BYTE_NUM), "big"
        )
        udp_config_trans.gate_way = int.from_bytes(
            random.randbytes(IP_ADDR_BYTE_NUM), "big"
        )

        self.log.info(
            f"Udp Config: MAC={str2mac(self.local_mac)} IP={ltoa(udp_config_trans.ip_addr)}"
        )
        await self.udp_config_src.send(udp_config_trans)

    async def send(self, pkt):
        payload = raw(pkt[UDP].payload)
        if self.is_support_rdma:
            payload = payload[:-4]

        udp_ip_meta = UdpIpMetaDataTransation()
        udp_ip_meta.ip_addr = atol(pkt[IP].dst)
        udp_ip_meta.ip_dscp = 0
        udp_ip_meta.ip_ecn = 0
        udp_ip_meta.dst_port = pkt[UDP].dport
        udp_ip_meta.src_port = pkt[UDP].sport
        udp_ip_meta.data_len = len(payload)

        mac_meta = MacMetaDataTransaction()
        mac_meta.mac_addr = int.from_bytes(mac2str(pkt[Ether].dst), "big")
        mac_meta.eth_type = pkt[Ether].type

        await self.udp_ip_meta_src.send(udp_ip_meta)
        await self.mac_meta_src.send(mac_meta)
        frame = AxiStreamFrame()
        frame.tdata = payload
        await self.data_stream_src.send(frame)

    async def recv(self):
        frame = await self.axi_stream_sink.recv()
        return bytes(frame.tdata)

    def gen_random_pkt(self):
        dst_mac = random.randbytes(MAC_ADDR_BYTE_NUM)
        dst_ip_int = int.from_bytes(random.randbytes(IP_ADDR_BYTE_NUM), "big")
        src_ip_int = int.from_bytes(self.local_ip, "big")
        dst_port_int = int.from_bytes(random.randbytes(UDP_PORT_BYTE_NUM), "big")
        src_port_int = int.from_bytes(random.randbytes(UDP_PORT_BYTE_NUM), "big")

        header = Ether(dst=str2mac(dst_mac), src=str2mac(self.local_mac))
        header = header / IP(dst=ltoa(dst_ip_int), src=ltoa(src_ip_int))
        header = header / UDP(
            dport=dst_port_int, sport=src_port_int, chksum=0
        )  # Udp checksum is unused
        payload_size = random.randint(self.min_payload_len, self.max_payload_len - 1)
        payload = random.randbytes(payload_size)

        if self.is_support_rdma:
            header = header / BTH()
            bind_layers(UDP, BTH)

        packet = Ether(raw(header / Raw(payload)))
        return packet

    async def drive_dut_input(self):
        for case_idx in range(self.cases_num):
            packet = self.gen_random_pkt()
            await self.send(packet)
            self.ref_buffer.put(raw(packet))
            self.log.info(f"Send {case_idx} Packet: {packet}")

    async def check_dut_output(self):
        for case_idx in range(self.cases_num):
            dut_packet = await self.recv()
            ref_packet = self.ref_buffer.get()

            if dut_packet != ref_packet:
                dut_packet_hex = dut_packet.hex("-")
                ref_packet_hex = ref_packet.hex("-")
                self.log.error(f"DUT Packet {case_idx}: {dut_packet_hex}")
                self.log.error(f"REF Packet {case_idx}: {ref_packet_hex}")
                Ether(dut_packet).show()
                Ether(ref_packet).show()
            assert raw(dut_packet) == raw(ref_packet), f"Test Case {case_idx} Fail"
            self.log.info(f"Pass testcase {case_idx}")


@cocotb.test(timeout_time=1000000000, timeout_unit="ns")
async def runUdpIpEthTxTester(dut):
    support_rdma = os.getenv("SUPPORT_RDMA")
    is_support_rdma = support_rdma == "True"
    tester = UdpIpEthTxTester(
        dut, CASES_NUM, MIN_PAYLOAD_LEN, MAX_PAYLOAD_LEN, is_support_rdma
    )
    await tester.gen_clock()
    await tester.gen_reset()
    await tester.config_udp()
    drive_thread = cocotb.start_soon(tester.drive_dut_input())
    check_thread = cocotb.start_soon(tester.check_dut_output())
    tester.log.info("Start testing!")
    await check_thread
    tester.log.info(f"Pass all {tester.cases_num} testcases successfully")


def test_UdpIpEthTx(support_rdma):
    toplevel = "mkRawUdpIpEthTx"
    module = os.path.splitext(os.path.basename(__file__))[0]
    test_dir = os.path.abspath(os.path.dirname(__file__))
    sim_build = os.path.join(test_dir, "build")
    v_top_file = os.path.join(test_dir, "generated", f"{toplevel}.v")
    verilog_sources = [v_top_file]
    extra_env = {"SUPPORT_RDMA": support_rdma}
    cocotb_test.simulator.run(
        toplevel=toplevel,
        module=module,
        verilog_sources=verilog_sources,
        python_search=test_dir,
        sim_build=sim_build,
        timescale="1ns/1ps",
        extra_env=extra_env,
    )


if __name__ == "__main__":
    assert len(sys.argv) == 2
    support_rdma = sys.argv[1]
    test_UdpIpEthTx(support_rdma)
