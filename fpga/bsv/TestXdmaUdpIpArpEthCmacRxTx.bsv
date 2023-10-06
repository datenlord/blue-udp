
import FIFOF :: *;
import Clocks :: *;
import Vector :: *;
import Randomizable :: *;

import Ports :: *;
import Utils :: *;

import SemiFifo :: *;
import AxiStreamTypes :: *;

typedef 33 CYCLE_COUNT_WIDTH;
typedef 16 CASE_COUNT_WIDTH;
typedef  8 FRAME_COUNT_WIDTH;
typedef 256 TEST_CASE_NUM;

typedef 2048 PAYLOAD_BYTE_NUM;
typedef TMul#(PAYLOAD_BYTE_NUM, 8) PAYLOAD_WIDTH;
typedef TDiv#(PAYLOAD_BYTE_NUM, AXIS_TKEEP_WIDTH) PAYLOAD_FRAME_NUM;
typedef TMul#(PAYLOAD_FRAME_NUM, AXIS_TDATA_WIDTH) PAYLOAD_EXT_WIDTH;
typedef TMul#(PAYLOAD_FRAME_NUM, AXIS_TKEEP_WIDTH) PAYLOAD_EXT_BYTE_NUM;
typedef TSub#(PAYLOAD_EXT_BYTE_NUM, PAYLOAD_BYTE_NUM) EXTRA_BYTE_NUM;

// Clock and Reset Signal Configuration(unit: 1ps/1ps)
typedef    1 CLK_POSITIVE_INIT_VAL;
typedef    0 CLK_NEGATIVE_INIT_VAL;
typedef 3103 GT_REF_CLK_HALF_PERIOD;
typedef 5000 INIT_CLK_HALF_PERIOD;
typedef 1000 UDP_CLK_HALF_PERIOD;
typedef  100 SYS_RST_DURATION;
typedef  100 UDP_RESET_DURATION;

interface TestXdmaUdpIpArpEthCmacRxTx;
    (* prefix = "xdma_tx_axis" *)
    interface RawAxiStreamMaster#(AXIS_TKEEP_WIDTH, AXIS_TUSER_WIDTH) xdmaAxiStreamOutTx;
    (* prefix = "xdma_rx_axis" *)
    interface RawAxiStreamSlave#(AXIS_TKEEP_WIDTH, AXIS_TUSER_WIDTH) xdmaAxiStreamInRx;
endinterface

module mkTestXdmaUdpIpArpEthCmacRxTx(TestXdmaUdpIpArpEthCmacRxTx);
    Integer testCaseNum = valueOf(TEST_CASE_NUM);
    Integer payloadFrameNum = valueOf(PAYLOAD_FRAME_NUM);

    // Common Signals
    Reg#(Bool) isInit <- mkReg(False);
    Reg#(Bit#(CYCLE_COUNT_WIDTH)) cycleCount <- mkReg(0);
    Reg#(Bit#(CASE_COUNT_WIDTH)) inputCaseCount <- mkReg(0);
    Reg#(Bit#(FRAME_COUNT_WIDTH)) inputFrameCount <- mkReg(0);
    Reg#(Bit#(CASE_COUNT_WIDTH)) outputCaseCount <- mkReg(0);
    Reg#(Bit#(FRAME_COUNT_WIDTH)) outputFrameCount <- mkReg(0);
    // Random Signals
    Randomize#(Bit#(PAYLOAD_WIDTH)) randRawData <- mkGenericRandomizer;


    // Input/Output FIFO
    FIFOF#(AxiStream512) refAxiStreamBuf <- mkSizedFIFOF(valueOf(TEST_CASE_NUM));
    FIFOF#(AxiStream512) xdmaAxiStreamOutTxBuf <- mkFIFOF;
    FIFOF#(AxiStream512) xdmaAxiStreamInRxBuf <- mkFIFOF;

    let rawAxiStreamOutTx <- mkPipeOutToRawAxiStreamMaster(
        convertFifoToPipeOut(xdmaAxiStreamOutTxBuf)
    );
    let rawAxiStreamInRx <- mkPipeInToRawAxiStreamSlave(
        convertFifoToPipeIn(xdmaAxiStreamInRxBuf)
    );

    // Initialize Testbench
    rule initTest if (!isInit);
        randRawData.cntrl.init;
        isInit <= True;
    endrule
    
    // Count Cycle Number
    rule doCycleCount if (isInit);
        cycleCount <= cycleCount + 1;
        if (cycleCount[7:0] == 0) begin
            $display("\nCycle %d ----------------------------------------", cycleCount); 
        end
        
        Bool cycleCountOut = unpack(msb(cycleCount));
        immAssert(
            !cycleCountOut,
            "Testbench timeout assertion @ mkTestCompletionBuf",
            $format("Cycle number overflows its limitation")
        );
    endrule

    Reg#(Vector#(PAYLOAD_FRAME_NUM, Bit#(AXIS_TDATA_WIDTH))) rawDataVecReg <- mkRegU;
    rule driveXdmaAxiStreamTx if (isInit && (inputCaseCount < fromInteger(testCaseNum)));
        let nextFrameCount = inputFrameCount + 1;
        let rawData <- randRawData.next;
        Bit#(PAYLOAD_EXT_WIDTH) extRawData = zeroExtend(rawData);
        Vector#(PAYLOAD_FRAME_NUM, Bit#(AXIS_TDATA_WIDTH)) rawDataVec = unpack(extRawData);
        AxiStream512 axiStream = AxiStream {
            tData: rawDataVecReg[inputFrameCount],
            tKeep: setAllBits,
            tLast: False,
            tUser: 0
        };

        if (inputFrameCount == 0) begin
            rawDataVecReg <= rawDataVec;
            axiStream.tData = rawDataVec[0];
        end

        if (nextFrameCount == fromInteger(payloadFrameNum)) begin
            axiStream.tLast = True;
            axiStream.tKeep = axiStream.tKeep >> valueOf(EXTRA_BYTE_NUM);
            inputFrameCount <= 0;
            inputCaseCount <= inputCaseCount + 1;
        end
        else begin
            inputFrameCount <= nextFrameCount;
        end
        refAxiStreamBuf.enq(axiStream);
        xdmaAxiStreamOutTxBuf.enq(axiStream);
        $display("Testbench: drive %5d AxiStream frame of %5d testcase:", inputFrameCount, inputCaseCount);
        $display(fshow(axiStream));
    endrule

    rule checkXdmaAxiStreamRx if (isInit);
        let dutAxiStream = xdmaAxiStreamInRxBuf.first;
        let refAxiStream = refAxiStreamBuf.first;
        xdmaAxiStreamInRxBuf.deq;
        refAxiStreamBuf.deq;
        if (dutAxiStream.tLast) begin
            outputFrameCount <= 0;
            outputCaseCount <= outputCaseCount + 1;
        end
        else begin
            outputFrameCount <= outputFrameCount + 1;
        end

        $display("Testbench: receive %5d AxiStream frame of %5d testcase:", outputFrameCount, outputCaseCount);
        $display("REF: ", fshow(refAxiStream));
        $display("DUT: ", fshow(dutAxiStream));
        immAssert(
            dutAxiStream == refAxiStream,
            "Compare DUT And REF output @ mkTestXdmaUdpIpArpEthCmacRxTx",
            $format("The %5d AxiStream frame of %5d testcase is incorrect", outputFrameCount, outputCaseCount)
        );
    endrule

    rule finishTestbench if (outputCaseCount == fromInteger(testCaseNum));
        $display("Testbench: XdmaUdpIpArpEthCmacRxTx passes all %d testcases", testCaseNum);
        $finish;
    endrule

    interface xdmaAxiStreamOutTx = rawAxiStreamOutTx;
    interface xdmaAxiStreamInRx = rawAxiStreamInRx;
endmodule

// Drive testcases and generate clk and reset signals
interface TestXdmaUdpIpArpEthCmacRxTxWithClk;
    (* prefix = "" *)
    interface TestXdmaUdpIpArpEthCmacRxTx testStimulus;
    
    // Clock and Reset
    (* prefix = "gt_ref_clk_p" *)
    interface Clock gtPositiveRefClk;
    (* prefix = "gt_ref_clk_n" *) 
    interface Clock gtNegativeRefClk;
    (* prefix = "init_clk" *) 
    interface Clock initClk;
    (* prefix = "sys_reset"  *) 
    interface Reset sysReset;
    (* prefix = "udp_clk" *) 
    interface Clock udpClk;
    (* prefix = "udp_reset" *) 
    interface Reset udpReset;
endinterface

(* synthesize, clock_prefix = "", reset_prefix = "", gate_prefix = "gate", no_default_clock, no_default_reset *)
module mkTestXdmaUdpIpArpEthCmacRxTxWithClk(TestXdmaUdpIpArpEthCmacRxTxWithClk);
    // Clock and Reset Generation
    let gtPositiveRefClkOsc <- mkAbsoluteClockFull(
        valueOf(GT_REF_CLK_HALF_PERIOD),
        fromInteger(valueOf(CLK_POSITIVE_INIT_VAL)),
        valueOf(GT_REF_CLK_HALF_PERIOD),
        valueOf(GT_REF_CLK_HALF_PERIOD)
    );

    let gtNegativeRefClkOsc <- mkAbsoluteClockFull(
        valueOf(GT_REF_CLK_HALF_PERIOD),
        fromInteger(valueOf(CLK_NEGATIVE_INIT_VAL)),
        valueOf(GT_REF_CLK_HALF_PERIOD),
        valueOf(GT_REF_CLK_HALF_PERIOD)
    );

    let initClkSrc <- mkAbsoluteClockFull(
        valueOf(INIT_CLK_HALF_PERIOD),
        fromInteger(valueOf(CLK_POSITIVE_INIT_VAL)),
        valueOf(INIT_CLK_HALF_PERIOD),
        valueOf(INIT_CLK_HALF_PERIOD)
    );

    let sysResetSrc <- mkInitialReset(valueOf(SYS_RST_DURATION), clocked_by initClkSrc);

    let udpClkSrc <- mkAbsoluteClockFull(
        valueOf(UDP_CLK_HALF_PERIOD),
        fromInteger(valueOf(CLK_POSITIVE_INIT_VAL)),
        valueOf(UDP_CLK_HALF_PERIOD),
        valueOf(UDP_CLK_HALF_PERIOD)
    );
    let udpResetSrc <- mkInitialReset(valueOf(UDP_RESET_DURATION), clocked_by udpClkSrc);


    let testXdmaUdpIpArpEthCmacRxTx <- mkTestXdmaUdpIpArpEthCmacRxTx(clocked_by udpClkSrc, reset_by udpResetSrc);

    interface testStimulus = testXdmaUdpIpArpEthCmacRxTx;
    interface gtPositiveRefClk = gtPositiveRefClkOsc;
    interface gtNegativeRefClk = gtNegativeRefClkOsc;
    interface initClk = initClkSrc;
    interface udpClk  = udpClkSrc;
    interface sysReset = sysResetSrc;
    interface udpReset = udpResetSrc;
endmodule