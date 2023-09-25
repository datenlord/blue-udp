import FIFOF :: *;
import GetPut :: *;
import Vector :: *;
import Connectable :: *;
import Randomizable :: *;

import Ports :: *;
import Utils :: *;
import EthernetTypes :: *;
import PfcUdpIpArpEthRxTx :: *;

import SemiFifo :: *;

typedef 16 CYCLE_COUNT_WIDTH;
typedef 16 CASE_COUNT_WIDTH;
typedef 50000 MAX_CYCLE_NUM;
typedef 512 TEST_CASE_NUM;

typedef 32'h7F000001 DUT_IP_ADDR;
typedef 48'hd89c679c4829 DUT_MAC_ADDR;
typedef 32'h00000000 DUT_NET_MASK;
typedef 32'h00000000 DUT_GATE_WAY;
typedef 22 DUT_PORT_NUM;

typedef 5 FRAME_COUNT_WIDTH;
typedef VIRTUAL_CHANNEL_NUM CHANNEL_NUM;

typedef 400 PAUSE_CYCLE_NUM;

typedef 4 TEST_CHANNEL_IDX;
typedef 10 BUF_PACKET_NUM;
typedef 32 MAX_PACKET_FRAME_NUM;
typedef 3 PFC_THRESHOLD;

typedef 256 REF_BUF_DEPTH;

(* synthesize *)
module mkTestPfcUdpIpArpEthRxTx();
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
    Reg#(Bool) isRxPause <- mkReg(True);
    Reg#(Bit#(CYCLE_COUNT_WIDTH)) pauseCycleCount <- mkReg(0);
    Reg#(Bool) metaDataSentFlag <- mkReg(False);
    Reg#(Bit#(FRAME_COUNT_WIDTH)) frameNumReg <- mkRegU;
    Reg#(Bit#(FRAME_COUNT_WIDTH)) frameCounter <- mkReg(0);

    FIFOF#(AxiStream512) axiStreamInterBuf <- mkFIFOF;
    FIFOF#(UdpIpMetaData) refMetaDataBuf <- mkSizedFIFOF(valueOf(REF_BUF_DEPTH));
    FIFOF#(DataStream) refDataStreamBuf <- mkSizedFIFOF(valueOf(REF_BUF_DEPTH));

    PfcUdpIpArpEthRxTx#(BUF_PACKET_NUM, MAX_PACKET_FRAME_NUM, PFC_THRESHOLD) pfcUdpIpArpEthRxTx <- mkGenericPfcUdpIpArpEthRxTx(`IS_SUPPORT_RDMA);
    mkConnection(pfcUdpIpArpEthRxTx.flowControlReqVecIn, toGet(pfcUdpIpArpEthRxTx.flowControlReqVecOut));
    mkConnection(pfcUdpIpArpEthRxTx.axiStreamInRx, toGet(axiStreamInterBuf));
    rule connectAxiStream;
        let axiStream = pfcUdpIpArpEthRxTx.axiStreamOutTx.first;
        pfcUdpIpArpEthRxTx.axiStreamOutTx.deq;
        if (axiStreamInterBuf.notFull) begin
            axiStreamInterBuf.enq(axiStream);
        end
        else begin
            $display("Testbench: Throw AxiStream frame");
        end
    endrule

    // Initialize Testbench
    rule initTest if (!isInit);
        randPause.cntrl.init;
        randData.cntrl.init;
        randFrameNum.cntrl.init;

        pfcUdpIpArpEthRxTx.udpConfig.put(
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
        $display("\nCycle %d ----------------------------------------", cycleCount);
        immAssert(
            cycleCount < fromInteger(maxCycleNum),
            "Testbench timeout assertion @ mkTestPfcUdpIpArpEthRxTx",
            $format("Cycle number overflow %d", maxCycleNum)
        );
    endrule

    rule genRandomRxPause if (isInit);
        if (pauseCycleCount == fromInteger(valueOf(PAUSE_CYCLE_NUM))) begin
            pauseCycleCount <= 0;
            let isPause <- randPause.next;
            isRxPause <= isPause;
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
        pfcUdpIpArpEthRxTx.udpIpMetaDataInTxVec[testChannelIdx].put(udpIpMetaData);

        frameNumReg <= frameNum;
        frameCounter <= 0;
        metaDataSentFlag <= True;
        $display("Testbench: Channel %3d Send %d UdpIpMetaData", testChannelIdx, inputCaseCounter);
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
        pfcUdpIpArpEthRxTx.dataStreamInTxVec[testChannelIdx].put(dataStream);
        frameCounter <= nextFrameCount;
        
        if (dataStream.isLast) begin
            metaDataSentFlag <= False;
            inputCaseCounter <= inputCaseCounter + 1;
        end

        $display("Testbench: Channel %3d: Send %d dataStream of %d case", testChannelIdx, frameCounter, inputCaseCounter);
    endrule


    rule recvAndCheckMetaData if (!isRxPause);
        let dutMetaData = pfcUdpIpArpEthRxTx.udpIpMetaDataOutRxVec[testChannelIdx].first;
        pfcUdpIpArpEthRxTx.udpIpMetaDataOutRxVec[testChannelIdx].deq;
        let refMetaData = refMetaDataBuf.first;
        refMetaDataBuf.deq;
        $display("Testbench: Channel %3d: Receive %d UdpIpMetaData", testChannelIdx, outputCaseCounter);
        immAssert(
            dutMetaData == refMetaData,
            "Compare DUT And REF UdpIpMetaData output @ mkTestPfcUdpIpArpEthRxTx",
            $format("Channel %d Case %5d incorrect", testChannelIdx, outputCaseCounter)
        );
    endrule

    rule recvAndCheckDataStream if (!isRxPause);
        let dutDataStream = pfcUdpIpArpEthRxTx.dataStreamOutRxVec[testChannelIdx].first;
        pfcUdpIpArpEthRxTx.dataStreamOutRxVec[testChannelIdx].deq;
        let refDataStream = refDataStreamBuf.first;
        refDataStreamBuf.deq;
        $display("Testbench: Channel %3d: Receive %d DataStream", testChannelIdx, outputCaseCounter);
        immAssert(
            dutDataStream == refDataStream,
            "Compare DUT And REF DataStream output @ mkTestPfcUdpIpArpEthRxTx",
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
endmodule