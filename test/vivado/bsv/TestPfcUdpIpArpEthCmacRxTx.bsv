import FIFOF :: *;
import GetPut :: *;
import Vector :: *;
import Clocks :: *;
import Connectable :: *;
import Randomizable :: *;

import Ports :: *;
import Utils :: *;
import EthernetTypes :: *;
import XilinxCmacRxTxWrapper :: *;
import PfcUdpIpArpEthRxTx :: *;

import SemiFifo :: *;

typedef 24 CYCLE_COUNT_WIDTH;
typedef 16 CASE_COUNT_WIDTH;
typedef 10000000 MAX_CYCLE_NUM;
typedef 256 TEST_CASE_NUM;

typedef 32'h7F000001 DUT_IP_ADDR;
typedef 48'hd89c679c4829 DUT_MAC_ADDR;
typedef 32'h00000000 DUT_NET_MASK;
typedef 32'h00000000 DUT_GATE_WAY;
typedef 22 DUT_PORT_NUM;

typedef 5 FRAME_COUNT_WIDTH;
typedef VIRTUAL_CHANNEL_NUM CHANNEL_NUM;

typedef 400 PAUSE_CYCLE_NUM;

typedef 4  TEST_CHANNEL_IDX;
typedef 16 BUF_PACKET_NUM;
typedef 32 MAX_PACKET_FRAME_NUM;
typedef 4  PFC_THRESHOLD;
typedef 8  SYNC_BRAM_BUF_DEPTH;

typedef 256 REF_BUF_DEPTH;

// Clock and Reset Signal Configuration(unit: 1ps/1ps)
typedef    1 CLK_POSITIVE_INIT_VAL;
typedef    0 CLK_NEGATIVE_INIT_VAL;
typedef 3103 GT_REF_CLK_HALF_PERIOD;
typedef 5000 INIT_CLK_HALF_PERIOD;
typedef 1000 UDP_CLK_HALF_PERIOD;
typedef  100 SYS_RST_DURATION;
typedef  100 UDP_RESET_DURATION;

interface TestPfcUdpIpArpEthCmacRxTx;
    // Configuration
    interface Get#(UdpConfig) udpConfig;
    // Tx
    interface Vector#(VIRTUAL_CHANNEL_NUM, Get#(DataStream)) dataStreamOutTxVec;
    interface Vector#(VIRTUAL_CHANNEL_NUM, Get#(UdpIpMetaData)) udpIpMetaDataOutTxVec;
    // Rx
    interface Vector#(VIRTUAL_CHANNEL_NUM, Put#(DataStream)) dataStreamInRxVec;
    interface Vector#(VIRTUAL_CHANNEL_NUM, Put#(UdpIpMetaData)) udpIpMetaDataInRxVec;
endinterface


(* synthesize, default_clock_osc = "clk", default_reset = "reset" *)
module mkTestPfcUdpIpArpEthCmacRxTx(TestPfcUdpIpArpEthCmacRxTx);
    Bool isTxWaitRxAligned = True;
    Integer testCaseNum = valueOf(TEST_CASE_NUM);
    Integer maxCycleNum = valueOf(MAX_CYCLE_NUM);
    Integer testChannelIdx = valueOf(TEST_CHANNEL_IDX);

    // Common Signals
    Reg#(Bool) isInit <- mkReg(False);
    Reg#(Bit#(CYCLE_COUNT_WIDTH)) cycleCount <- mkReg(0);
    Reg#(Bit#(CASE_COUNT_WIDTH)) inputCaseCounter <- mkReg(0);
    Reg#(Bit#(CASE_COUNT_WIDTH)) outputCaseCounter <- mkReg(0);

    // Random Signals
    Randomize#(Bool) randPause <- mkGenericRandomizer;
    Randomize#(Data) randData <- mkGenericRandomizer;
    Randomize#(Bit#(FRAME_COUNT_WIDTH)) randFrameNum <- mkGenericRandomizer;

    // DUT And Ref Model
    Reg#(Bool) isRxPauseReg <- mkReg(True);
    Reg#(Bit#(CYCLE_COUNT_WIDTH)) pauseCycleCount <- mkReg(0);
    Reg#(Bool) metaDataSentFlag <- mkReg(False);
    Reg#(Bit#(FRAME_COUNT_WIDTH)) frameNumReg <- mkRegU;
    Reg#(Bit#(FRAME_COUNT_WIDTH)) frameCounter <- mkReg(0);

    FIFOF#(UdpIpMetaData) refMetaDataBuf <- mkSizedFIFOF(valueOf(REF_BUF_DEPTH));
    FIFOF#(DataStream) refDataStreamBuf <- mkSizedFIFOF(valueOf(REF_BUF_DEPTH));

    FIFOF#(UdpConfig) udpConfigBuf <- mkFIFOF;
    Vector#(VIRTUAL_CHANNEL_NUM, FIFOF#(DataStream)) dataStreamOutTxBufVec <- replicateM(mkFIFOF);
    Vector#(VIRTUAL_CHANNEL_NUM, FIFOF#(UdpIpMetaData)) udpIpMetaDataOutTxBufVec <- replicateM(mkFIFOF);
    Vector#(VIRTUAL_CHANNEL_NUM, FIFOF#(DataStream)) dataStreamInRxBufVec <- replicateM(mkFIFOF);
    Vector#(VIRTUAL_CHANNEL_NUM, FIFOF#(UdpIpMetaData)) udpIpMetaDataInRxBufVec <- replicateM(mkFIFOF);


    // Initialize Testbench
    rule initTest if (!isInit);
        randPause.cntrl.init;
        randData.cntrl.init;
        randFrameNum.cntrl.init;

        udpConfigBuf.enq(
            UdpConfig {
                macAddr: fromInteger(valueOf(DUT_MAC_ADDR)),
                ipAddr: fromInteger(valueOf(DUT_IP_ADDR)),
                netMask: fromInteger(valueOf(DUT_NET_MASK)),
                gateWay: fromInteger(valueOf(DUT_GATE_WAY))
            }
        );

        isInit <= True;
    endrule

    // Count Cycle Number
    rule doCycleCount if (isInit);
        cycleCount <= cycleCount + 1;
        if (cycleCount[7:0] == 0) begin
        $display("\nCycle %d ----------------------------------------", cycleCount);
        end
        immAssert(
            cycleCount < fromInteger(maxCycleNum),
            "Testbench timeout assertion @ mkTestPfcUdpIpArpEthCmacRxTx",
            $format("Cycle number overflow %d", maxCycleNum)
        );
    endrule

    rule genRandomRxPause if (isInit);
        let isPause <- randPause.next;
        if (pauseCycleCount == fromInteger(valueOf(PAUSE_CYCLE_NUM))) begin
            pauseCycleCount <= 0;
            isRxPauseReg <= isPause;
            $display("Testbench: Pause UdpIpArpEthRx ", fshow(isPause));
        end
        else begin
            pauseCycleCount <= pauseCycleCount + 1;
        end
    endrule

    rule sendMetaData if (isInit && !metaDataSentFlag && inputCaseCounter < fromInteger(testCaseNum));  
        let frameNum <- randFrameNum.next;
        if (frameNum == 0) frameNum = 1;
        
        let udpIpMetaData = UdpIpMetaData {
            dataLen: zeroExtend(frameNum) * fromInteger(valueOf(DATA_BUS_BYTE_WIDTH)),
            ipAddr: fromInteger(valueOf(DUT_IP_ADDR)),
            ipDscp: 0,
            ipEcn: 0,
            dstPort: fromInteger(valueOf(DUT_PORT_NUM)),
            srcPort: fromInteger(valueOf(DUT_PORT_NUM))
        };

        refMetaDataBuf.enq(udpIpMetaData);
        udpIpMetaDataOutTxBufVec[testChannelIdx].enq(udpIpMetaData);

        frameNumReg <= frameNum;
        frameCounter <= 0;
        metaDataSentFlag <= True;
        $display("Testbench: Channel %3d Send %d UdpIpMetaData:\n", testChannelIdx, inputCaseCounter, udpIpMetaData);
    endrule

    rule sendDataStream if (metaDataSentFlag);
        let data <- randData.next;
        let nextFrameCount = frameCounter + 1;
        let dataStream = DataStream {
            data: data,
            byteEn: setAllBits,
            isFirst: frameCounter == 0,
            isLast: nextFrameCount == frameNumReg
        };

        
        refDataStreamBuf.enq(dataStream);
        dataStreamOutTxBufVec[testChannelIdx].enq(dataStream);
        frameCounter <= nextFrameCount;
        
        if (dataStream.isLast) begin
            metaDataSentFlag <= False;
            inputCaseCounter <= inputCaseCounter + 1;
        end

        $display("Testbench: Channel %3d: Send %d dataStream of %d case:\n", testChannelIdx, frameCounter, inputCaseCounter, dataStream);
    endrule

    rule recvAndCheckMetaData if (!isRxPauseReg);
        let dutMetaData = udpIpMetaDataInRxBufVec[testChannelIdx].first;
        udpIpMetaDataInRxBufVec[testChannelIdx].deq;
        let refMetaData = refMetaDataBuf.first;
        refMetaDataBuf.deq;
        $display("Testbench: Channel %3d: Receive %d UdpIpMetaData", testChannelIdx, outputCaseCounter);
        $display("DUT: ", fshow(dutMetaData));
        $display("REF: ", fshow(refMetaData));
        immAssert(
            dutMetaData == refMetaData,
            "Compare DUT And REF UdpIpMetaData output @ mkTestPfcUdpIpArpEthCmacRxTx",
            $format("Channel %d Case %5d incorrect", testChannelIdx, outputCaseCounter)
        );
    endrule

    rule recvAndCheckDataStream if (!isRxPauseReg);
        let dutDataStream = dataStreamInRxBufVec[testChannelIdx].first;
        dataStreamInRxBufVec[testChannelIdx].deq;
        let refDataStream = refDataStreamBuf.first;
        refDataStreamBuf.deq;
        $display("Testbench: Channel %3d: Receive %d DataStream:", testChannelIdx, outputCaseCounter);
        $display("DUT: ", fshow(dutDataStream));
        $display("REF: ", fshow(refDataStream));
        immAssert(
            dutDataStream == refDataStream,
            "Compare DUT And REF DataStream output @ mkTestPfcUdpIpArpEthCmacRxTx",
            $format("Channel %3d Case %5d incorrect", testChannelIdx, outputCaseCounter)
        );
        if (dutDataStream.isLast) begin
            outputCaseCounter <= outputCaseCounter + 1;
        end
    endrule

    rule finishTest if (outputCaseCounter == fromInteger(testCaseNum));
        $display("Testbench: Channel %3d pass %5d testcases", testChannelIdx, testCaseNum);
        $finish;
    endrule

    interface udpConfig = toGet(udpConfigBuf);
    interface dataStreamOutTxVec = map(toGet, dataStreamOutTxBufVec);
    interface udpIpMetaDataOutTxVec = map(toGet, udpIpMetaDataOutTxBufVec);
    interface dataStreamInRxVec = map(toPut, dataStreamInRxBufVec);
    interface udpIpMetaDataInRxVec = map(toPut, udpIpMetaDataInRxBufVec);
endmodule

interface TestPfcUdpIpArpEthCmacRxTxWithClkRst;
    (* prefix = "" *)
    interface TestPfcUdpIpArpEthCmacRxTx testStimulus;

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
module mkTestPfcUdpIpArpEthCmacRxTxWithClkRst(TestPfcUdpIpArpEthCmacRxTxWithClkRst);
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


    let testPfcUdpIpArpEthCmacRxTx <- mkTestPfcUdpIpArpEthCmacRxTx(clocked_by udpClkSrc, reset_by udpResetSrc);

    interface testStimulus = testPfcUdpIpArpEthCmacRxTx;
    interface gtPositiveRefClk = gtPositiveRefClkOsc;
    interface gtNegativeRefClk = gtNegativeRefClkOsc;
    interface initClk = initClkSrc;
    interface udpClk  = udpClkSrc;
    interface sysReset = sysResetSrc;
    interface udpReset = udpResetSrc;
endmodule

typedef PfcUdpIpArpEthCmacRxTx#(BUF_PACKET_NUM, MAX_PACKET_FRAME_NUM, PFC_THRESHOLD) PfcUdpIpArpEthCmacRxTxTestInst;

(* synthesize, no_default_clock, no_default_reset *)
module mkPfcUdpIpArpEthCmacRxTxInst(
    (* osc = "udp_clk"  *)        Clock udpClk,
    (* osc = "cmac_rxtx_clk" *)   Clock cmacRxTxClk,
    (* reset = "udp_reset" *)     Reset udpReset,
    (* reset = "cmac_rx_reset" *) Reset cmacRxReset,
    (* reset = "cmac_tx_reset" *) Reset cmacTxReset,
    PfcUdpIpArpEthCmacRxTxTestInst ifc
);
    Bool isTxWaitRxAligned = True;
    PfcUdpIpArpEthCmacRxTxTestInst pfcUdpIpArpEthCmacRxTx <- mkPfcUdpIpArpEthCmacRxTx(
        `IS_SUPPORT_RDMA,
        isTxWaitRxAligned,
        valueOf(SYNC_BRAM_BUF_DEPTH),
        cmacRxTxClk,
        cmacRxReset,
        cmacTxReset,
        clocked_by udpClk,
        reset_by udpReset
    );
    return pfcUdpIpArpEthCmacRxTx;
endmodule
