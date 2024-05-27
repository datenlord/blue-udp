import Ports :: *;
import FIFOF :: *;
import GetPut :: *;
import Connectable :: *;
import Randomizable :: *;
import ClientServer :: *;

import EthUtils :: *;
import MacLayer :: *;
import EthernetTypes :: *;
import TestUtils :: *;
import UdpIpEthBypassCmacRxTx :: *;

import SemiFifo :: *;

typedef 32 CYCLE_COUNT_WIDTH;
typedef 16 CASE_COUNT_WIDTH;
typedef 500000 MAX_CYCLE_NUM;
typedef 2000 TEST_CASE_NUM;

typedef 32'h7F000001 DUT_IP_ADDR;
typedef 48'hd89c679c4829 DUT_MAC_ADDR;
typedef 32'h00000000 DUT_NET_MASK;
typedef 32'h00000000 DUT_GATE_WAY;

typedef 6 BEAT_COUNT_WIDTH;
typedef 4 MAX_AXI_STREAM_DELAY;

typedef 1024 REF_BUF_DEPTH;

(* synthesize *)
module mkTestUdpIpEthBypassRxTx();
    Integer testCaseNum = valueOf(TEST_CASE_NUM);
    Integer maxCycleNum = valueOf(MAX_CYCLE_NUM);

    // Common Signals
    Reg#(Bool) isInit <- mkReg(False);
    Reg#(Bit#(CYCLE_COUNT_WIDTH)) cycleCounter <- mkReg(0);
    Reg#(Bit#(CASE_COUNT_WIDTH)) inputCaseCounter <- mkReg(0);
    Reg#(Bit#(CASE_COUNT_WIDTH)) outputCaseCounter <- mkReg(0);

    // Random Signals
    Randomize#(Data) randData <- mkGenericRandomizer;
    Randomize#(Bool) randBypassSelect <- mkGenericRandomizer;
    Randomize#(Bit#(BEAT_COUNT_WIDTH)) randBeatNum <- mkGenericRandomizer;

    // Control Signal
    Reg#(Bool) metaDataSentFlag <- mkReg(False);
    Reg#(Bool) bypassSelectReg <- mkReg(False);
    Reg#(Bit#(BEAT_COUNT_WIDTH)) beatNumReg <- mkRegU;
    Reg#(Bit#(BEAT_COUNT_WIDTH)) inputBeatCounter <- mkReg(0);
    Reg#(Bit#(BEAT_COUNT_WIDTH)) outputBeatCounter <- mkReg(0);

    // DUT
    let udpConfigVal = UdpConfig {
        macAddr: fromInteger(valueOf(DUT_MAC_ADDR)),
        ipAddr: fromInteger(valueOf(DUT_IP_ADDR)),
        netMask: fromInteger(valueOf(DUT_NET_MASK)),
        gateWay: fromInteger(valueOf(DUT_GATE_WAY))
    };
    let udpIpEthBypassRxTx <- mkGenericUdpIpEthBypassRxTx(`IS_SUPPORT_RDMA);
    RandomDelay#(AxiStreamLocal, MAX_AXI_STREAM_DELAY) randDelayGen <- mkRandomDelay;
    mkConnection(toGet(udpIpEthBypassRxTx.axiStreamTxOut), randDelayGen.request);
    mkConnection(randDelayGen.response, udpIpEthBypassRxTx.axiStreamRxIn);

    //REF
    FIFOF#(Bool) bypassSelectBuf <- mkSizedFIFOF(valueOf(REF_BUF_DEPTH));
    
    FIFOF#(MacMetaData) refMacMetaDataBuf <- mkSizedFIFOF(valueOf(REF_BUF_DEPTH));   
    FIFOF#(UdpIpMetaData) refUdpIpMetaDataBuf <- mkSizedFIFOF(valueOf(REF_BUF_DEPTH));
    FIFOF#(DataStream) refDataStreamBuf <- mkSizedFIFOF(valueOf(REF_BUF_DEPTH));
    
    FIFOF#(DataStream) refRawPktStreamBuf <- mkSizedFIFOF(valueOf(REF_BUF_DEPTH));

    // Initialize Testbench
    rule initTest if (!isInit);
        randBypassSelect.cntrl.init;
        randData.cntrl.init;
        randBeatNum.cntrl.init;
        udpIpEthBypassRxTx.udpConfig.put(udpConfigVal);

        isInit <= True;
    endrule

    // Count Cycle Number
    rule doCycleCount if (isInit);
        cycleCounter <= cycleCounter + 1;
        $display("\nCycle %d ----------------------------------------", cycleCounter);
        immAssert(
            cycleCounter < fromInteger(maxCycleNum),
            "Testbench timeout assertion @ mkTestPfcUdpIpArpEthRxTx",
            $format("Cycle number overflow %d", maxCycleNum)
        );
    endrule

    rule sendMetaData if (isInit && !metaDataSentFlag && inputCaseCounter < fromInteger(testCaseNum));  
        Bit#(BEAT_COUNT_WIDTH) beatNum <- randBeatNum.next;
        Bool bypassSelect <- randBypassSelect.next;
        //Bit#(BEAT_COUNT_WIDTH) beatNum = 32;
        //Bool bypassSelect = False;
        if (beatNum == 0) beatNum = 1;
        beatNumReg <= beatNum;
        bypassSelectReg <= bypassSelect;
        inputBeatCounter <= 0;
        metaDataSentFlag <= True;
        bypassSelectBuf.enq(bypassSelect);
        
        let macMetaData = MacMetaData {
            macAddr: fromInteger(valueOf(DUT_MAC_ADDR)),
            ethType: fromInteger(valueOf(ETH_TYPE_IP))
        };

        let udpIpMetaData = UdpIpMetaData {
            dataLen: zeroExtend(beatNum) * fromInteger(valueOf(DATA_BUS_BYTE_WIDTH)),
            ipAddr: fromInteger(valueOf(DUT_IP_ADDR)),
            ipDscp: 0,
            ipEcn: 0,
            dstPort: fromInteger(valueOf(UDP_PORT_RDMA)),
            srcPort: fromInteger(valueOf(UDP_PORT_RDMA))
        };

        if (bypassSelect) begin
            udpIpEthBypassRxTx.macMetaDataTxIn.put(
                MacMetaDataWithBypassTag {
                    macMetaData: macMetaData,
                    isBypass: True
                }
            );
            $display("Testbench: Testcase %d sends MacMetaData to bypass channel", inputCaseCounter);
        end
        else begin
            udpIpEthBypassRxTx.macMetaDataTxIn.put(
                MacMetaDataWithBypassTag {
                    macMetaData: macMetaData,
                    isBypass: False
                }
            );
            udpIpEthBypassRxTx.udpIpMetaDataTxIn.put(udpIpMetaData);
            refMacMetaDataBuf.enq(macMetaData);
            refUdpIpMetaDataBuf.enq(udpIpMetaData);
            $display("Testbench: Testcase %d sends UdpIpMetaData and MacMetaData to packet generator", inputCaseCounter);
        end
    endrule

    rule sendDataStream if (metaDataSentFlag);
        let data <- randData.next;
        let nextBeatCount = inputBeatCounter + 1;
        let dataStream = DataStream {
            data: data,
            byteEn: setAllBits,
            isFirst: inputBeatCounter == 0,
            isLast: nextBeatCount == beatNumReg
        };

        udpIpEthBypassRxTx.dataStreamTxIn.put(dataStream);
        if (bypassSelectReg) begin
            refRawPktStreamBuf.enq(dataStream);
        end
        else begin
            refDataStreamBuf.enq(dataStream);
        end
        inputBeatCounter <= nextBeatCount;
        if (dataStream.isLast) begin
            metaDataSentFlag <= False;
            inputCaseCounter <= inputCaseCounter + 1;
        end

        $display("Testbench: Sends %d DataStream of %d testcase", inputBeatCounter, inputCaseCounter);
    endrule


    rule recvAndCheckMetaData;
        let dutUdpIpMetaData = udpIpEthBypassRxTx.udpIpMetaDataRxOut.first;
        udpIpEthBypassRxTx.udpIpMetaDataRxOut.deq;
        let refUdpIpMetaData = refUdpIpMetaDataBuf.first;
        refUdpIpMetaDataBuf.deq;

        let dutMacMetaData = udpIpEthBypassRxTx.macMetaDataRxOut.first;
        udpIpEthBypassRxTx.macMetaDataRxOut.deq;
        let refMacMetaData = refMacMetaDataBuf.first;
        $display("Testbench: receive UdpIpMetaData and MacMetaData of %d testcase", outputCaseCounter);
        immAssert(
            dutUdpIpMetaData == refUdpIpMetaData,
            "Compare DUT And REF UdpIpMetaData output @ mkTestPfcUdpIpArpEthRxTx",
            $format("Testcase %d check UdpIpMetaData failed", outputCaseCounter)
        );
        immAssert(
            dutMacMetaData == refMacMetaData,
            "Compare DUT And REF MacMetaData output @ mkTestPfcUdpIpArpEthRxTx",
            $format("Testcase %d check MacMetaData failed", outputCaseCounter)
        );
    endrule

    rule recvAndCheckDataStream;
        let bypassSelect = bypassSelectBuf.first;
        DataStream dutDataStream, refDataStream;

        if (bypassSelect) begin
            dutDataStream = udpIpEthBypassRxTx.rawPktStreamRxOut.first;
            udpIpEthBypassRxTx.rawPktStreamRxOut.deq;
            refDataStream = refRawPktStreamBuf.first;
            refRawPktStreamBuf.deq;
            $display("Testbench: receive %d DataStream of %d testcase from bypass channel", outputBeatCounter, outputCaseCounter);
        end
        else begin
            dutDataStream = udpIpEthBypassRxTx.dataStreamRxOut.first;
            udpIpEthBypassRxTx.dataStreamRxOut.deq;
            refDataStream = refDataStreamBuf.first;
            refDataStreamBuf.deq;
            $display("Testbench: receive %d DataStream of %d testcase from packet extractor", outputBeatCounter, outputCaseCounter);
        end

        immAssert(
            dutDataStream == refDataStream,
            "Compare DUT And REF DataStream output @ mkTestUdpIpEthBypassRxTx",
            $format("Testcase %5d incorrect", outputCaseCounter)
        );
        if (dutDataStream.isLast) begin
            outputCaseCounter <= outputCaseCounter + 1;
            bypassSelectBuf.deq;
            outputBeatCounter <= 0;
        end
        else begin
            outputBeatCounter <= outputBeatCounter + 1;
        end
    endrule

    rule finishTest if (outputCaseCounter == fromInteger(testCaseNum));
        $display("Testbench: mkUdpIpEthBypassRxTx pass all %5d testcases", testCaseNum);
        $finish;
    endrule
endmodule
