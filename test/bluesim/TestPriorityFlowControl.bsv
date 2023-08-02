import FIFOF :: *;
import Vector :: *;
import GetPut :: *;
import ClientServer :: *;
import Connectable :: *;
import Randomizable :: *;


import Ports :: *;
import Utils :: *;
import SemiFifo :: *;
import PrimUtils :: *;
import TestUtils :: *;
import EthernetTypes :: *;
import PriorityFlowControl :: *;
 
typedef 16 CYCLE_COUNT_WIDTH;
typedef 16 CASE_COUNT_WIDTH;
typedef 50000 MAX_CYCLE_NUM;
typedef 64 TEST_CASE_NUM;

typedef 5 FRAME_COUNT_WIDTH;
typedef 4 MAX_RANDOM_DELAY;
typedef VIRTUAL_CHANNEL_NUM CHANNEL_NUM;

typedef 4 BUF_PACKET_NUM;
typedef 32 MAX_PACKET_FRAME_NUM;
typedef 3 PFC_THRESHOLD;

typedef 256 REF_BUF_DEPTH;

(* synthesize *)
module mkTestPriorityFlowControl();
    Integer testCaseNum = valueOf(TEST_CASE_NUM);
    Integer maxCycleNum = valueOf(MAX_CYCLE_NUM);
    Integer channelNum = valueOf(VIRTUAL_CHANNEL_NUM);

    // Common Signals
    Reg#(Bool) isInit <- mkReg(False);
    Reg#(Bit#(CYCLE_COUNT_WIDTH)) cycleCount <- mkReg(0);
    Vector#(CHANNEL_NUM, Reg#(Bit#(CASE_COUNT_WIDTH))) inputCaseCounters <- replicateM(mkReg(0));
    Vector#(CHANNEL_NUM, Reg#(Bit#(CASE_COUNT_WIDTH))) outputCaseCounters <- replicateM(mkReg(0));

    // Random Signals
    Vector#(CHANNEL_NUM, Randomize#(Data)) randData <- replicateM(mkGenericRandomizer);
    Vector#(CHANNEL_NUM, Randomize#(UdpIpMetaData)) randUdpIpMetaData <- replicateM(mkGenericRandomizer);
    Vector#(CHANNEL_NUM, Randomize#(Bit#(FRAME_COUNT_WIDTH))) randDataStreamLen <- replicateM(mkGenericRandomizer);

    // DUT And Ref Model
    PriorityFlowControlTx#(BUF_PACKET_NUM, MAX_PACKET_FRAME_NUM) pfcTx <- mkPriorityFlowControlTx;
    PriorityFlowControlRx#(BUF_PACKET_NUM, MAX_PACKET_FRAME_NUM, PFC_THRESHOLD) pfcRx <- mkPriorityFlowControlRx;
    RandomDelay#(UdpIpMetaDataAndChannelIdx, MAX_RANDOM_DELAY) metaDataDelay <- mkRandomDelay;
    RandomDelay#(DataStream, MAX_RANDOM_DELAY) dataStreamDelay <- mkRandomDelay;
    mkConnection(metaDataDelay.request, pfcTx.udpIpMetaAndChannelIdxOut);
    mkConnection(metaDataDelay.response, pfcRx.udpIpMetaAndChannelIdxIn);
    mkConnection(dataStreamDelay.request, pfcTx.dataStreamOut);
    mkConnection(dataStreamDelay.response, pfcRx.dataStreamIn);

    Vector#(CHANNEL_NUM, Reg#(Bool)) metaDataSentFlags <- replicateM(mkReg(False));
    Vector#(CHANNEL_NUM, Reg#(Bit#(FRAME_COUNT_WIDTH))) dataStreamLenReg <- replicateM(mkRegU);
    Vector#(CHANNEL_NUM, Reg#(Bit#(FRAME_COUNT_WIDTH))) frameCounters <- replicateM(mkReg(0));

    Vector#(CHANNEL_NUM, FIFOF#(UdpIpMetaData)) refMetaDataBuf <- replicateM(mkSizedFIFOF(valueOf(REF_BUF_DEPTH)));
    Vector#(CHANNEL_NUM, FIFOF#(DataStream)) refDataStreamBuf <- replicateM(mkSizedFIFOF(valueOf(REF_BUF_DEPTH)));


    // Initialize Testbench
    rule initTest if (!isInit);
        for (Integer i = 0; i < channelNum; i = i + 1) begin
            randData[i].cntrl.init;
            randUdpIpMetaData[i].cntrl.init;
            randDataStreamLen[i].cntrl.init;
        end
        isInit <= True;
    endrule

    // Count Cycle Number
    rule doCycleCount if (isInit);
        cycleCount <= cycleCount + 1;
        $display("\nCycle %d ----------------------------------------", cycleCount);
        immAssert(
            cycleCount < fromInteger(maxCycleNum),
            "Testbench timeout assertion @ mkTestPriorityFlowControl",
            $format("Cycle number overflow %d", maxCycleNum)
        );
    endrule

    for (Integer i = 0; i < channelNum; i = i + 1) begin
        rule sendMetaData if (isInit && !metaDataSentFlags[i] && inputCaseCounters[i] < fromInteger(testCaseNum));
            let udpIpMetaData <- randUdpIpMetaData[i].next;
            let dataStreamLen <- randDataStreamLen[i].next;
            pfcTx.udpIpMetaDataInVec[i].put(udpIpMetaData);
            refMetaDataBuf[i].enq(udpIpMetaData);
            dataStreamLenReg[i] <= dataStreamLen;
            frameCounters[i] <= 0;
            metaDataSentFlags[i] <= True;
            $display("Virtual Channel %d: Send %d UdpIpMetaData DataStreamLen: %d", i, inputCaseCounters[i], dataStreamLen);
        endrule
    end

    for (Integer i = 0; i < channelNum; i = i + 1) begin
        rule sendDataStream if (metaDataSentFlags[i]);
            let data <- randData[i].next;
            let nextFrameCount = frameCounters[i] + 1;
            let dataStream = DataStream {
                data: data,
                byteEn: setAllBits,
                isFirst: frameCounters[i] == 0,
                isLast: nextFrameCount == dataStreamLenReg[i]
            };

            pfcTx.dataStreamInVec[i].put(dataStream);
            refDataStreamBuf[i].enq(dataStream);
            frameCounters[i] <= nextFrameCount;
            
            if (dataStream.isLast) begin
                metaDataSentFlags[i] <= False;
                inputCaseCounters[i] <= inputCaseCounters[i] + 1;
            end

            $display("Virtual Channel %d: Send %d dataStream frame of %d case", i, frameCounters[i], inputCaseCounters[i]);
        endrule
    end

    for (Integer i = 0; i < channelNum; i = i + 1) begin
        rule recvAndCheckMetaData;
            let dutMetaData <- pfcRx.udpIpMetaDataOutVec[i].get;
            let refMetaData = refMetaDataBuf[i].first;
            refMetaDataBuf[i].deq;
            $display("Virtual Channel %d: Receive %d UdpIpMetaData", i, outputCaseCounters[i]);
            immAssert(
                dutMetaData == refMetaData,
                "Compare DUT And REF UdpIpMetaData output @ mkTestPriorityFlowControl",
                $format("Channel %d Case %5d incorrect", i, outputCaseCounters[i])
            );
        endrule
    end

    for (Integer i = 0; i < channelNum; i = i + 1) begin
        rule recvAndCheckDataStream;
            let dutDataStream <- pfcRx.dataStreamOutVec[i].get;
            let refDataStream = refDataStreamBuf[i].first;
            refDataStreamBuf[i].deq;
            $display("Virtual Channel %d: Receive %d DataStream", i, outputCaseCounters[i]);
            immAssert(
                dutDataStream == refDataStream,
                "Compare DUT And REF DataStream output @ mkTestPriorityFlowControl",
                $format("Channel %d Case %5d incorrect", i, outputCaseCounters[i])
            );
            if (dutDataStream.isLast) begin
                outputCaseCounters[i] <= outputCaseCounters[i] + 1;
            end
        endrule
    end

    rule finishTest;
        Bool isAllChannelDone = True;
        for (Integer i = 0; i < channelNum; i = i + 1) begin
            if (outputCaseCounters[i] < fromInteger(testCaseNum)) begin
                isAllChannelDone = False;
            end
        end
        if (isAllChannelDone) begin
            $display("All %3d channels pass %5d testcases", channelNum, testCaseNum);
            $finish;
        end
    endrule
endmodule