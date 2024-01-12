import FIFOF :: *;
import Vector :: *;
import GetPut :: *;
import Clocks :: *;
import Randomizable :: *;

import Ports :: *;
import EthUtils :: *;
import PortConversion :: *;

import SemiFifo :: *;

typedef 33 CYCLE_COUNT_WIDTH;
typedef 16 CASE_COUNT_WIDTH;
typedef 16 FRAME_COUNT_WIDTH;
typedef 512 TEST_CASE_NUM;

typedef   18 MIN_RAW_BYTE_NUM;
typedef 1024 MAX_RAW_BYTE_NUM;
typedef TMul#(MAX_RAW_BYTE_NUM, BYTE_WIDTH) MAX_RAW_DATA_WIDTH;
typedef TLog#(TAdd#(MAX_RAW_BYTE_NUM, 1)) MAX_RAW_BYTE_NUM_WIDTH;

// DUT Configuration
typedef 32'h7F000001 DUT_IP_ADDR;
typedef 48'hd89c679c4829 DUT_MAC_ADDR;
typedef 32'h00000000 DUT_NET_MASK;
typedef 32'h00000000 DUT_GATE_WAY;
typedef 22 DUT_PORT_NUM;

typedef 64 CMAC_RX_INTER_BUF_DEPTH;
typedef 8  SYNC_BRAM_BUF_DEPTH;

typedef 512 REF_OUTPUT_BUF_DEPTH;

// Clock and Reset Signal Configuration(unit: 1ps/1ps)
typedef    1 CLK_POSITIVE_INIT_VAL;
typedef    0 CLK_NEGATIVE_INIT_VAL;
typedef 3200 GT_REF_CLK_HALF_PERIOD;
typedef 5000 INIT_CLK_HALF_PERIOD;
typedef 1000 UDP_CLK_HALF_PERIOD;
typedef  100 SYS_RST_DURATION;
typedef  100 UDP_RESET_DURATION;

module mkDataStreamGenerator#(
    PipeOut#(Bit#(maxRawByteNumWidth)) rawByteNumIn,
    PipeOut#(Bit#(maxRawDataWidth)) rawDataIn
)(DataStreamPipeOut)
    provisos(
        Mul#(maxRawByteNum, BYTE_WIDTH, maxRawDataWidth),
        Mul#(DATA_BUS_BYTE_WIDTH, maxFragNum, maxRawByteNum),
        NumAlias#(TLog#(TAdd#(maxRawByteNum, 1)), maxRawByteNumWidth),
        NumAlias#(TLog#(maxFragNum), maxFragNumWidth)
    );
    Reg#(Bit#(maxRawByteNumWidth)) rawByteCounter <- mkReg(0);
    Reg#(Bit#(maxFragNumWidth)) fragCounter <- mkReg(0);
    FIFOF#(DataStream) outputBuf <- mkFIFOF;

    rule doFragment;
        let rawData = rawDataIn.first;
        Vector#(maxFragNum, Data) rawDataVec = unpack(rawData);
        let rawByteNum = rawByteNumIn.first;

        DataStream dataStream = DataStream {
            data: rawDataVec[fragCounter],
            byteEn: setAllBits,
            isFirst: fragCounter == 0,
            isLast: False
        };

        let nextRawByteCountVal = rawByteCounter + fromInteger(valueOf(DATA_BUS_BYTE_WIDTH));
        if (nextRawByteCountVal >= rawByteNum) begin
            let extraByteNum = nextRawByteCountVal - rawByteNum;
            dataStream.byteEn = dataStream.byteEn >> extraByteNum;
            dataStream.isLast = True;
            fragCounter <= 0;
            rawByteCounter <= 0;
            rawDataIn.deq;
            rawByteNumIn.deq;
        end
        else begin
            fragCounter <= fragCounter + 1;
            rawByteCounter <= nextRawByteCountVal;
        end

        dataStream.data = bitMask(dataStream.data, dataStream.byteEn);

        outputBuf.enq(dataStream);
        //$display("%s: send %8d fragment ", instanceName, fragCounter, fshow(dataStream));
    endrule
    
    return convertFifoToPipeOut(outputBuf);
endmodule

interface TestUdpIpArpEthCmacRxTx;
    // Configuration
    (* prefix = "m_udp_config" *)
    interface RawUdpConfigBusMaster  udpConfigOut;
    
    // Tx
    (* prefix = "m_udp_meta" *)
    interface RawUdpIpMetaDataBusMaster udpIpMetaDataOutTx;
    (* prefix = "m_data_stream" *)
    interface RawDataStreamBusMaster dataStreamOutTx;
    
    // Rx
    (* prefix = "s_udp_meta" *)
    interface RawUdpIpMetaDataBusSlave udpIpMetaDataInRx;
    (* prefix = "s_data_stream" *)
    interface RawDataStreamBusSlave dataStreamInRx;
endinterface

// Generate test vectors for UdpIpArpEthRxTx
(* synthesize, default_clock_osc = "udp_clk", default_reset = "udp_reset" *)
module mkTestUdpIpArpEthCmacRxTx(TestUdpIpArpEthCmacRxTx);
    Integer testCaseNum = valueOf(TEST_CASE_NUM);

    // Common Signals
    Reg#(Bool) isInit <- mkReg(False);
    Reg#(Bit#(CYCLE_COUNT_WIDTH)) cycleCount <- mkReg(0);
    Reg#(Bit#(CASE_COUNT_WIDTH)) inputCaseCount <- mkReg(0);
    Reg#(Bit#(CASE_COUNT_WIDTH)) inputCaseCount2 <- mkReg(0);
    Reg#(Bit#(CASE_COUNT_WIDTH)) outputCaseCount <- mkReg(0);

    // Random Signals
    Randomize#(Bit#(MAX_RAW_DATA_WIDTH)) randRawData <- mkGenericRandomizer;
    Randomize#(Bit#(MAX_RAW_BYTE_NUM_WIDTH)) randRawByteNum <- mkGenericRandomizer;

    // DUT And Ref Model
    Reg#(Bool) isDutConfig <- mkReg(False);
    Reg#(Bit#(FRAME_COUNT_WIDTH)) inputFrameCount <- mkReg(0);
    Reg#(Bit#(FRAME_COUNT_WIDTH)) outputframeCount <- mkReg(0);
    FIFOF#(Bit#(MAX_RAW_DATA_WIDTH)) randRawDataBuf <- mkFIFOF;
    FIFOF#(Bit#(MAX_RAW_BYTE_NUM_WIDTH)) randRawByteNumBuf <- mkFIFOF;
    FIFOF#(DataStream) refDataStreamBuf <- mkSizedFIFOF(valueOf(REF_OUTPUT_BUF_DEPTH));
    FIFOF#(UdpIpMetaData) refMetaDataBuf <- mkSizedFIFOF(valueOf(REF_OUTPUT_BUF_DEPTH));


    // Input and Output Buffer
    FIFOF#(UdpConfig) udpConfigBuf <- mkFIFOF;
    FIFOF#(UdpIpMetaData) udpIpMetaDataOutTxBuf <- mkFIFOF;
    FIFOF#(DataStream) dataStreamOutTxBuf <- mkFIFOF;
    FIFOF#(UdpIpMetaData) udpIpMetaDataInRxBuf <- mkFIFOF;
    FIFOF#(DataStream) dataStreamInRxBuf <- mkFIFOF;

    let pktDataStream <- mkDataStreamGenerator(
        convertFifoToPipeOut(randRawByteNumBuf),
        convertFifoToPipeOut(randRawDataBuf)
    );

    // Initialize Testbench
    rule initTest if (!isInit);
        randRawData.cntrl.init;
        randRawByteNum.cntrl.init;
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

    rule configDut if (isInit && !isDutConfig);
        udpConfigBuf.enq(
            UdpConfig {
                macAddr: fromInteger(valueOf(DUT_MAC_ADDR)),
                ipAddr:  fromInteger(valueOf(DUT_IP_ADDR) ),
                netMask: fromInteger(valueOf(DUT_NET_MASK)),
                gateWay: fromInteger(valueOf(DUT_GATE_WAY))
            }
        );
        isDutConfig <= True;
        $display("Testbench: configure UdpIpArpEthCmacRxTx successfully");
    endrule

    rule driveMetaDataTx if (isDutConfig && (inputCaseCount < fromInteger(testCaseNum)));
        let rawData <- randRawData.next;
        let rawByteNum <- randRawByteNum.next;

        if (rawByteNum < fromInteger(valueOf(MIN_RAW_BYTE_NUM))) begin
            rawByteNum = fromInteger(valueOf(MIN_RAW_BYTE_NUM));
        end
        else if (rawByteNum > fromInteger(valueOf(MAX_RAW_BYTE_NUM))) begin
            rawByteNum = fromInteger(valueOf(MAX_RAW_BYTE_NUM));
        end

        randRawByteNumBuf.enq(rawByteNum);
        randRawDataBuf.enq(rawData);

        let metaData = UdpIpMetaData {
            dataLen: zeroExtend(rawByteNum),
            ipAddr:  fromInteger(valueOf(DUT_IP_ADDR)),
            ipDscp: 0,
            ipEcn: 0,
            dstPort: fromInteger(valueOf(DUT_PORT_NUM)),
            srcPort: fromInteger(valueOf(DUT_PORT_NUM))
        };

        udpIpMetaDataOutTxBuf.enq(metaData);
        refMetaDataBuf.enq(metaData);
        inputCaseCount <= inputCaseCount + 1;
        $display("Testbench: drive UdpIpMetaDataTx %d testcase of %d bytes", inputCaseCount, rawByteNum);
    endrule

    
    rule driveDataStreamTx if (isDutConfig);
        let dataStream = pktDataStream.first;
        pktDataStream.deq;
        dataStreamOutTxBuf.enq(dataStream);
        refDataStreamBuf.enq(dataStream);
        $display("Testbench: Drive %5d DataStream Frame of %5d testcase:\n", inputFrameCount, inputCaseCount2, fshow(dataStream));
        
        if (dataStream.isLast) begin
            inputFrameCount <= 0;
            inputCaseCount2 <= inputCaseCount2 + 1;
            $display("Testbench: Drive All Frames of %5d testcase", inputCaseCount2);
        end
        else begin
            inputFrameCount <= inputFrameCount + 1;
        end
    endrule

    rule checkMetaDateRx (isDutConfig);
        let dutMetaData = udpIpMetaDataInRxBuf.first;
        udpIpMetaDataInRxBuf.deq;

        let refMetaData = refMetaDataBuf.first;
        refMetaDataBuf.deq;

        $display("Testbench: receive UdpIpMetaData of %5d testcase:", outputCaseCount);
        $display("REF: ", fshow(refMetaData));
        $display("DUT: ", fshow(dutMetaData));
        immAssert(
            dutMetaData == refMetaData,
            "Compare DUT And REF output @ mkTestUdpIpArpEthRxTx",
            $format("UdpIpMetaData of %5d testcase is incorrect", outputCaseCount)
        );
    endrule

    rule checkDataStreamRx if (isDutConfig);
        let dutDataStream = dataStreamInRxBuf.first;
        dataStreamInRxBuf.deq;
        dutDataStream.data = bitMask(dutDataStream.data, dutDataStream.byteEn);

        let refDataStream = refDataStreamBuf.first;
        refDataStreamBuf.deq;

        $display("Testbench: Receive %d DataStream Frame of %5d testcase:", outputframeCount, outputCaseCount);
        $display("REF: ", fshow(refDataStream));
        $display("DUT: ", fshow(dutDataStream));
        immAssert(
            dutDataStream == refDataStream,
            "Compare DUT And REF output @ mkTestUdpIpArpEthRxTx",
            $format("%d DataStream frame of %5d testcase is incorrect", outputframeCount, outputCaseCount)
        );

        if (dutDataStream.isLast) begin
            outputframeCount <= 0;
            outputCaseCount <= outputCaseCount + 1;
            $display("Testbench: receive and verify data of %5d testcase", outputCaseCount);
        end
        else begin
            outputframeCount <= outputframeCount + 1;
        end
    endrule

    // Finish Testbench
    rule finishTestbench if (outputCaseCount == fromInteger(testCaseNum));
        $display("Testbench: UdpIpArpEthCmacRxTx passes all %d testcases", testCaseNum);
        $finish;
    endrule

    let udpConfig <- mkRawUdpConfigBusMaster(convertFifoToPipeOut(udpConfigBuf));
    let udpIpMetaDataOut <- mkRawUdpIpMetaDataBusMaster(convertFifoToPipeOut(udpIpMetaDataOutTxBuf));
    let dataStreamOut <- mkRawDataStreamBusMaster(convertFifoToPipeOut(dataStreamOutTxBuf));
    let udpIpMetaDataIn <- mkRawUdpIpMetaDataBusSlave(toPut(udpIpMetaDataInRxBuf));
    let dataStreamIn <- mkRawDataStreamBusSlave(toPut(dataStreamInRxBuf));
    interface udpConfigOut = udpConfig;
    interface udpIpMetaDataOutTx = udpIpMetaDataOut;
    interface dataStreamOutTx = dataStreamOut;
    interface udpIpMetaDataInRx = udpIpMetaDataIn;
    interface dataStreamInRx = dataStreamIn;
endmodule


