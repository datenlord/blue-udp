import logging
import os
import random
from binascii import crc32
from queue import Queue

import cocotb_test.simulator
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
from cocotb.regression import TestFactory

from cocotbext.axi import AxiStreamBus, AxiStreamSource, AxiStreamSink, AxiStreamFrame
from cocotbext.axi.stream import define_stream

CrcStreamBus, CrcStreamTransation, CrcStreamSource, CrcStreamSink, CrcStreamMonitor = define_stream(
    "CrcStream", signals=["valid", "ready", "data"]
)

class StandardCrc32Tester:
    def __init__(self, dut):
        self.dut = dut
        
        self.log = logging.getLogger("cocotb.tb")
        self.log.setLevel(logging.DEBUG)
        
        self.cases_num = 4096
        self.max_payload_size = 1024
        self.ref_rawdata_buf  = Queue(maxsize = self.cases_num)
        self.ref_checksum_buf = Queue(maxsize = self.cases_num)

        self.data_stream_src = AxiStreamSource(AxiStreamBus.from_prefix(dut, "s_data_stream"), dut.clk, dut.reset_n, False)
        self.crc_stream_sink = CrcStreamSink(CrcStreamBus.from_prefix(dut, "m_crc_stream"), dut.clk, dut.reset_n, False)
        
    async def clock(self):
        await cocotb.start(Clock(self.dut.clk, 10, 'ns').start())
        self.log.info("Start dut clock")
        
    async def reset(self):
        self.dut.reset_n.setimmediatevalue(0)
        await RisingEdge(self.dut.clk)
        await RisingEdge(self.dut.clk)
        await RisingEdge(self.dut.clk)
        self.dut.reset_n.value = 1
        await RisingEdge(self.dut.clk)
        await RisingEdge(self.dut.clk)
        await RisingEdge(self.dut.clk)
        self.log.info("Complete reset dut")
    
    def gen_random_test_case(self):
        data_size = random.randint(1, self.max_payload_size)
        raw_data = random.randbytes(data_size)
        check_sum = crc32(raw_data)
        return (raw_data, check_sum)
    
    async def drive_dut_input(self):
        for case_idx in range(self.cases_num):
            raw_data, check_sum = self.gen_random_test_case()
            frame = AxiStreamFrame(tdata=raw_data)
            await self.data_stream_src.send(frame)
            self.ref_rawdata_buf.put(raw_data)
            self.ref_checksum_buf.put(check_sum)
            raw_data = raw_data.hex('-')
            self.log.info(f"Drive dut {case_idx} case: rawdata={raw_data} checksum={check_sum}")
    
    async def check_dut_output(self):
        for case_idx in range(self.cases_num):
           dut_crc = await self.crc_stream_sink.recv()
           dut_crc = dut_crc.data
           ref_crc = self.ref_checksum_buf.get()
           ref_raw = self.ref_rawdata_buf.get()
           self.log.info(f"Recv dut {case_idx} case:\nraw = {ref_raw}\ndut_crc = {dut_crc}\nref_crc = {ref_crc}")
           assert dut_crc == ref_crc
    
@cocotb.test(timeout_time=10000000, timeout_unit="ns")
async def runUdpEthRxTester(dut):
    
    tester = StandardCrc32Tester(dut)
    await tester.clock()
    await tester.reset()
    drive_thread = cocotb.start_soon(tester.drive_dut_input())
    check_thread = cocotb.start_soon(tester.check_dut_output())
    tester.log.info("Start testing!")
    await check_thread
    tester.log.info(f"Pass all {tester.cases_num} successfully")


def test_StandardCrc32():
    toplevel = "mkStandardCrc32SynWrapper"
    module = os.path.splitext(os.path.basename(__file__))[0]
    test_dir = os.path.abspath(os.path.dirname(__file__))
    sim_build = os.path.join(test_dir, "build")
    v_wrapper_file = os.path.join(test_dir, "verilog", f"{toplevel}.v")
    v_source_file  = os.path.join(test_dir, "verilog", "mkStandardCrc32Syn.v")
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
    test_StandardCrc32()





