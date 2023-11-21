import FIFOF :: *;
import GetPut :: *;
import Vector :: *;
import Clocks :: *;
import Connectable :: *;
import Randomizable :: *;

import Ports :: *;
import Utils :: *;
import EthernetTypes :: *;

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
    interface Vector#(VIRTUAL_CHANNEL_NUM, Get#(DataStream)) dataStreamTxOutVec;
    interface Vector#(VIRTUAL_CHANNEL_NUM, Get#(UdpIpMetaData)) udpIpMetaDataTxOutVec;
    // Rx
    interface Vector#(VIRTUAL_CHANNEL_NUM, Put#(DataStream)) dataStreamRxInVec;
    interface Vector#(VIRTUAL_CHANNEL_NUM, Put#(UdpIpMetaData)) udpIpMetaDataRxInVec;
endinterface


(* synthesize, default_clock_osc = "udp_clk", default_reset = "udp_reset" *)
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
    Vector#(VIRTUAL_CHANNEL_NUM, FIFOF#(DataStream)) dataStreamTxOutBufVec <- replicateM(mkFIFOF);
    Vector#(VIRTUAL_CHANNEL_NUM, FIFOF#(UdpIpMetaData)) udpIpMetaDataTxOutBufVec <- replicateM(mkFIFOF);
    Vector#(VIRTUAL_CHANNEL_NUM, FIFOF#(DataStream)) dataStreamRxInBufVec <- replicateM(mkFIFOF);
    Vector#(VIRTUAL_CHANNEL_NUM, FIFOF#(UdpIpMetaData)) udpIpMetaDataRxInBufVec <- replicateM(mkFIFOF);


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
        udpIpMetaDataTxOutBufVec[testChannelIdx].enq(udpIpMetaData);

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
        dataStreamTxOutBufVec[testChannelIdx].enq(dataStream);
        frameCounter <= nextFrameCount;
        
        if (dataStream.isLast) begin
            metaDataSentFlag <= False;
            inputCaseCounter <= inputCaseCounter + 1;
        end

        $display("Testbench: Channel %3d: Send %d dataStream of %d case:\n", testChannelIdx, frameCounter, inputCaseCounter, dataStream);
    endrule

    rule recvAndCheckMetaData if (!isRxPauseReg);
        let dutMetaData = udpIpMetaDataRxInBufVec[testChannelIdx].first;
        udpIpMetaDataRxInBufVec[testChannelIdx].deq;
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
        let dutDataStream = dataStreamRxInBufVec[testChannelIdx].first;
        dataStreamRxInBufVec[testChannelIdx].deq;
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
    interface dataStreamTxOutVec = map(toGet, dataStreamTxOutBufVec);
    interface udpIpMetaDataTxOutVec = map(toGet, udpIpMetaDataTxOutBufVec);
    interface dataStreamRxInVec = map(toPut, dataStreamRxInBufVec);
    interface udpIpMetaDataRxInVec = map(toPut, udpIpMetaDataRxInBufVec);
endmodule
