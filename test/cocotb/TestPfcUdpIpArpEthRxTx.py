import os
import json
import asyncio
import random

from scapy.all import *

import cocotb_test.simulator
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
from cocotbext.axi import AxiStreamBus, AxiStreamSource, AxiStreamSink, AxiStreamFrame

from TestUtils import *

TEST_CASE_NUM = 8
MAX_PAYLOAD_SIZE = 1024


class PfcUdpIpArpEthRxTxTester:
    def __init__(self, dut, target_ip_vec, udp_port, cases_num, max_payload_size):
        self.dut = dut

        self.log = logging.getLogger("PfcUdpIpArpEthRxTxTester")
        self.log.setLevel(logging.DEBUG)

        self.cases_num = cases_num
        self.max_payload_size = max_payload_size

        self.ref_udp_meta_buf_vec = []
        for _ in range(self.cases_num):
            self.ref_udp_meta_buf_vec.append(Queue(maxsize=self.cases_num))
        self.ref_data_stream_buf_vec = []
        for _ in range(self.cases_num):
            self.ref_data_stream_buf_vec.append(Queue(maxsize=self.cases_num))

        self.reset_val = False
        self.clock = self.dut.CLK
        self.reset = self.dut.RST_N
        self.udp_config_src = UdpConfigSource(
            UdpConfigBus.from_prefix(dut, "s_udp_config"), self.clock, self.reset, False
        )

        def create_udp_meta_src(idx):
            prefix = "rawUdpIpMetaSlaveVec_" + str(idx)
            return UdpIpMetaDataSource(
                UdpIpMetaDataBus.from_prefix(dut, prefix), self.clock, self.reset, False
            )

        def create_data_stream_src(idx):
            prefix = "rawDataStreamSlaveVec_" + str(idx)
            return AxiStreamSource(
                AxiStreamBus.from_prefix(dut, prefix), self.clock, self.reset, False
            )

        def create_udp_meta_sink(idx):
            prefix = "rawUdpIpMetaMasterVec_" + str(idx)
            return UdpIpMetaDataSink(
                UdpIpMetaDataBus.from_prefix(dut, prefix), self.clock, self.reset, False
            )

        def create_data_stream_sink(idx):
            prefix = "rawDataStreamMasterVec_" + str(idx)
            return AxiStreamSink(
                AxiStreamBus.from_prefix(dut, prefix), self.clock, self.reset, False
            )

        # Tx
        self.udp_meta_src_vec = list(
            map(create_udp_meta_src, range(VIRTUAL_CHANNEL_NUM))
        )
        self.data_stream_src_vec = list(
            map(create_data_stream_src, range(VIRTUAL_CHANNEL_NUM))
        )
        for source in self.data_stream_src_vec:
            source.log.setLevel(logging.WARNING)

        self.axi_stream_sink = AxiStreamSink(
            AxiStreamBus.from_prefix(dut, "m_axi_stream"), self.clock, self.reset, False
        )
        self.axi_stream_sink.log.setLevel(logging.WARNING)

        # Rx
        self.udp_meta_sink_vec = list(
            map(create_udp_meta_sink, range(VIRTUAL_CHANNEL_NUM))
        )
        self.data_stream_sink_vec = list(
            map(create_data_stream_sink, range(VIRTUAL_CHANNEL_NUM))
        )
        for sink in self.data_stream_sink_vec:
            sink.log.setLevel(logging.WARNING)

        self.axi_stream_src = AxiStreamSource(
            AxiStreamBus.from_prefix(dut, "s_axi_stream"), self.clock, self.reset, False
        )
        self.axi_stream_src.log.setLevel(logging.WARNING)

        # Config
        self.local_ip = get_default_ip_addr()
        self.local_mac = get_default_mac_addr()
        self.gate_way = get_default_gateway()
        self.net_mask = get_default_netmask()
        self.target_ip_vec = target_ip_vec
        self.udp_port = udp_port

        self.channel_status_vec = [False] * VIRTUAL_CHANNEL_NUM

    async def gen_clock(self):
        await cocotb.start(Clock(self.clock, 10, "ns").start())

    async def gen_reset(self):
        self.reset.setimmediatevalue(self.reset_val)
        await RisingEdge(self.clock)
        await RisingEdge(self.clock)
        self.reset.value = not self.reset_val
        await RisingEdge(self.clock)
        await RisingEdge(self.clock)

    async def config_dut(self):
        udpConfig = UdpConfigTransation()
        udpConfig.mac_addr = int.from_bytes(mac2str(self.local_mac), "big")
        udpConfig.ip_addr = atol(self.local_ip)
        udpConfig.net_mask = atol(self.net_mask)
        udpConfig.gate_way = atol(self.gate_way)
        await self.udp_config_src.send(udpConfig)
        self.log.info(f"Configure Succesfully: {udpConfig}")

    async def drive_dut_input(self, idx):
        self.log.info(f"Channel {idx}: Start sending UdpIpMetaData and payload")
        for case_idx in range(self.cases_num):
            payload_len = random.randint(64, self.max_payload_size)
            payload = random.randbytes(payload_len)

            udp_meta_trans = UdpIpMetaDataTransation()
            udp_meta_trans.ip_addr = atol(self.target_ip_vec[idx])
            udp_meta_trans.dst_port = self.udp_port
            udp_meta_trans.src_port = self.udp_port
            udp_meta_trans.data_len = payload_len
            await self.udp_meta_src_vec[idx].send(udp_meta_trans)
            await self.data_stream_src_vec[idx].send(AxiStreamFrame(tdata=payload))

            self.log.info(f"Channel {idx}: Send {case_idx} Udp Meta:{udp_meta_trans}")
            self.log.info(f"Channel {idx}: Send {case_idx} Payload: {payload}")

            self.ref_udp_meta_buf_vec[idx].put(udp_meta_trans)
            self.ref_data_stream_buf_vec[idx].put(payload)

    async def check_dut_output(self, idx):
        self.log.info(f"Channel {idx}: Start checking UdpIpMetaData and payload")
        for case_idx in range(self.cases_num):
            dut_udp_meta = await self.udp_meta_sink_vec[idx].recv()
            dut_payload = await self.data_stream_sink_vec[idx].recv()
            dut_payload = bytes(dut_payload)

            ref_udp_meta = self.ref_udp_meta_buf_vec[idx].get()
            ref_payload = self.ref_data_stream_buf_vec[idx].get()

            self.log.info(
                f"Channel {idx}: Receive Dut {case_idx} UdpIpMetaData:{dut_udp_meta}"
            )
            self.log.info(
                f"Channel {idx}: Receive Dut {case_idx} Payload:{dut_payload}"
            )

            udp_meta_eq = is_udp_ip_meta_equal(dut_udp_meta, ref_udp_meta)
            packet_eq = udp_meta_eq & (ref_payload == dut_payload)
            if not packet_eq:
                self.log.error(
                    f"Channel {idx}: Ref {case_idx} UdpIpMetaData:{ref_udp_meta}"
                )
                self.log.error(f"Channel {idx}: Ref {case_idx} Payload:{ref_payload}")

            assert packet_eq, f"Channel {idx}: Receive incorrect packets"
        self.channel_status_vec[idx] = True
        self.log.info(f"Channel {idx}: Receive and check all packets")

    async def send_and_recv_eth(self):
        self.log.info("Start sending and receiving ethernet packet")
        pkt_idx = 0
        while True:
            axi_frame = await self.axi_stream_sink.recv()
            packet = Ether(bytes(axi_frame.tdata))
            self.log.info(f"Scapy Send {pkt_idx} Packet")

            resp, _ = srp(packet, verbose=True)
            for _, r in resp:
                recv_pkt = r

            self.log.info(f"Scapy Recv {pkt_idx} Packet:")
            recv_pkt.show()

            axi_frame = AxiStreamFrame(tdata=raw(recv_pkt))
            await self.axi_stream_src.send(axi_frame)
            self.log.info(f"Successfully send and receive {pkt_idx}")
            pkt_idx += 1
            time.sleep(2)


@cocotb.test(timeout_time=1000000, timeout_unit="ns")
async def runPfcUdpIpArpEthRxTester(dut):
    target_ip = []
    for i in range(VIRTUAL_CHANNEL_NUM):
        target_ip.append(os.getenv(f"TARGET_IP_{i}"))

    udp_port = int(os.getenv("UDP_PORT"))
    tester = PfcUdpIpArpEthRxTxTester(
        dut=dut,
        target_ip_vec=target_ip,
        udp_port=udp_port,
        cases_num=TEST_CASE_NUM,
        max_payload_size=MAX_PAYLOAD_SIZE,
    )
    await tester.gen_clock()
    await tester.gen_reset()
    await tester.config_dut()

    for i in range(VIRTUAL_CHANNEL_NUM):
        cocotb.start_soon(tester.drive_dut_input(i))

    for i in range(VIRTUAL_CHANNEL_NUM):
        cocotb.start_soon(tester.check_dut_output(i))

    srp_thread = cocotb.start_soon(tester.send_and_recv_eth())

    tester.log.info("Start Testing PfcUdpIpArpEthRxTx!!!")
    while not all(tester.channel_status_vec):
        await RisingEdge(tester.clock)

    tester.log.info(
        f"All {VIRTUAL_CHANNEL_NUM} channels pass {tester.cases_num} testcases successfully!!"
    )


def test_PfcUdpIpArpEthRxTx(target_ip, udp_port):
    toplevel = "mkRawPfcUdpIpArpEthRxTx"
    module = os.path.splitext(os.path.basename(__file__))[0]
    test_dir = os.path.abspath(os.path.dirname(__file__))
    sim_build = os.path.join(test_dir, "build")
    v_top_file = os.path.join(test_dir, "verilog", toplevel + ".v")
    verilog_sources = [v_top_file]
    extra_env = {"UDP_PORT": udp_port}
    for i in range(VIRTUAL_CHANNEL_NUM):
        extra_env[f"TARGET_IP_{i}"] = target_ip[i]

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
    assert len(sys.argv) == 2, "Usage: python3 TestPfcUdpIpArpEthRxTx.py CONFIG_FILE"
    with open(sys.argv[1]) as json_file:
        test_config = json.load(json_file)
    target_ip = test_config["ip_addr"]
    udp_port = test_config["udp_port"]
    test_PfcUdpIpArpEthRxTx(target_ip, udp_port)
