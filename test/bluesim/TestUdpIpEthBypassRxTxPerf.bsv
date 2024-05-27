
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
import AxiStreamTypes :: *;

typedef 32 CYCLE_COUNT_WIDTH;
typedef 16 CASE_COUNT_WIDTH;
typedef 100000 MAX_CYCLE_NUM;
typedef 1000 TEST_CASE_NUM;

typedef 32'h7F000001 DUT_IP_ADDR;
typedef 48'hd89c679c4829 DUT_MAC_ADDR;
typedef 32'h00000000 DUT_NET_MASK;
typedef 32'h00000000 DUT_GATE_WAY;

typedef 16 BEAT_COUNT_WIDTH;
typedef 32 TEST_PKT_BEAT_NUM;


(* synthesize *)
module mkTestUdpIpEthBypassRxTxPerf();
    Integer testCaseNum = valueOf(TEST_CASE_NUM);
    Integer maxCycleNum = valueOf(MAX_CYCLE_NUM);
    Integer pktBeatNum = valueOf(TEST_PKT_BEAT_NUM);
    Bool isSelectBypassChannel = False;

    // Common Signals
    Reg#(Bool) isInit <- mkReg(False);
    Reg#(Bit#(CYCLE_COUNT_WIDTH)) cycleCounter <- mkReg(0);

    Reg#(Bit#(BEAT_COUNT_WIDTH)) inputBeatCounter <- mkReg(0);
    Reg#(Bit#(BEAT_COUNT_WIDTH)) outputBeatCounter <- mkReg(0);

    Reg#(Bit#(CASE_COUNT_WIDTH)) inputPktCounter <- mkReg(0);
    Reg#(Bit#(CASE_COUNT_WIDTH)) interPktCounter <- mkReg(0);
    Reg#(Bit#(CASE_COUNT_WIDTH)) outputPktCounter <- mkReg(0);

    Reg#(Bit#(CYCLE_COUNT_WIDTH)) inputDataStreamStartCycle <- mkRegU;
    Reg#(Bit#(CYCLE_COUNT_WIDTH)) inputDataStreamEndCycle <- mkRegU;
    
    Reg#(Bit#(CYCLE_COUNT_WIDTH)) interAxiStreamStartCycle <- mkRegU;
    Reg#(Bit#(CYCLE_COUNT_WIDTH)) interAxiStreamEndCycle <- mkRegU;

    Reg#(Bit#(CYCLE_COUNT_WIDTH)) outputDataStreamStartCycle <- mkRegU;
    Reg#(Bit#(CYCLE_COUNT_WIDTH)) outputDataStreamEndCycle <- mkRegU;

    Reg#(Bool) isFirstAxiStreamBeat <- mkReg(False);

    // DUT
    let udpConfigVal = UdpConfig {
        macAddr: fromInteger(valueOf(DUT_MAC_ADDR)),
        ipAddr: fromInteger(valueOf(DUT_IP_ADDR)),
        netMask: fromInteger(valueOf(DUT_NET_MASK)),
        gateWay: fromInteger(valueOf(DUT_GATE_WAY))
    };
    let udpIpEthBypassRxTx <- mkGenericUdpIpEthBypassRxTx(`IS_SUPPORT_RDMA);
    FIFOF#(AxiStreamLocal) interAxiStreamBuf <- mkFIFOF;


    // Initialize Testbench
    rule initTest if (!isInit);
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

    // Tx Channel
    rule sendUdpIpMetaDataTx if (isInit);
        let udpIpMetaData = UdpIpMetaData {
            dataLen: fromInteger(valueOf(TEST_PKT_BEAT_NUM)) * fromInteger(valueOf(DATA_BUS_BYTE_WIDTH)),
            ipAddr: fromInteger(valueOf(DUT_IP_ADDR)),
            ipDscp: 0,
            ipEcn: 0,
            dstPort: fromInteger(valueOf(UDP_PORT_RDMA)),
            srcPort: fromInteger(valueOf(UDP_PORT_RDMA))
        };

        if (!isSelectBypassChannel) begin
            udpIpEthBypassRxTx.udpIpMetaDataTxIn.put(udpIpMetaData);
        end
        $display("Testbench: send UdpIpMetaData to DUT");
    endrule

    rule sendMacMetaDataTx if (isInit);
        let macMetaData = MacMetaData {
            macAddr: fromInteger(valueOf(DUT_MAC_ADDR)),
            ethType: fromInteger(valueOf(ETH_TYPE_IP))
        };

        udpIpEthBypassRxTx.macMetaDataTxIn.put(
            MacMetaDataWithBypassTag {
                macMetaData: macMetaData,
                isBypass: isSelectBypassChannel
            }
        );
        $display("Testbench: send MacMetaData to DUT");
    endrule

    rule sendDataStreamTx if (isInit && inputPktCounter < fromInteger(testCaseNum));
        let dataStream = DataStream {
            data: ?,
            byteEn: setAllBits,
            isFirst: inputBeatCounter == 0,
            isLast: inputBeatCounter == (fromInteger(pktBeatNum) - 1)
        };

        udpIpEthBypassRxTx.dataStreamTxIn.put(dataStream);
        if (dataStream.isLast) begin
            inputPktCounter <= inputPktCounter + 1;
            inputBeatCounter <= 0;
            if (inputPktCounter == fromInteger(testCaseNum) - 1) begin
                inputDataStreamEndCycle <= cycleCounter;
            end
        end
        else begin
            inputBeatCounter <= inputBeatCounter + 1;
        end

        if (inputPktCounter == 0 && inputBeatCounter == 0) begin
            inputDataStreamStartCycle <= cycleCounter;
        end

        $display("Testbench: Sends %d DataStream of %d testcase", inputBeatCounter, inputPktCounter);
    endrule

    rule connectTxRxChannel;
        let axiStream = udpIpEthBypassRxTx.axiStreamTxOut.first;
        udpIpEthBypassRxTx.axiStreamTxOut.deq;
        udpIpEthBypassRxTx.axiStreamRxIn.put(axiStream);

        if (axiStream.tLast) begin
            interPktCounter <= interPktCounter + 1;
            if (interPktCounter == fromInteger(testCaseNum) - 1) begin
                interAxiStreamEndCycle <= cycleCounter;
            end
        end
        if (!isFirstAxiStreamBeat) begin
            interAxiStreamStartCycle <= cycleCounter;
            isFirstAxiStreamBeat <= True;
        end
        $display("Testbench: pass one AXI-Stream Beat of %d testcase", interPktCounter);
    endrule

    rule recvMacMetaDataRx;
        if (!isSelectBypassChannel) begin
            udpIpEthBypassRxTx.macMetaDataRxOut.deq;
        end
    endrule

    rule recvUdpMetaDataRx;
        if (!isSelectBypassChannel) begin
            udpIpEthBypassRxTx.udpIpMetaDataRxOut.deq;
        end
    endrule

    rule recvDataStreamRx;
        DataStream dataStreamRx;
        if (isSelectBypassChannel) begin
            dataStreamRx = udpIpEthBypassRxTx.rawPktStreamRxOut.first;
            udpIpEthBypassRxTx.rawPktStreamRxOut.deq;
        end
        else begin
            dataStreamRx = udpIpEthBypassRxTx.dataStreamRxOut.first;
            udpIpEthBypassRxTx.dataStreamRxOut.deq;
        end

        if (dataStreamRx.isLast) begin
            outputPktCounter <= outputPktCounter + 1;
            outputBeatCounter <= 0;
            if (outputPktCounter == fromInteger(testCaseNum) - 1) begin
                outputDataStreamEndCycle <= cycleCounter;
            end
        end
        else begin
            outputBeatCounter <= outputBeatCounter + 1;
        end

        if (outputPktCounter == 0 && outputBeatCounter == 0) begin
            outputDataStreamStartCycle <= cycleCounter;
        end
        $display("Testbench: Receives %d DataStream of %d testcase", outputBeatCounter, outputPktCounter);
    endrule

    rule finishTest if (outputPktCounter == fromInteger(testCaseNum));
        $display("Performance Test of mkUdpIpEthBypassRxTx Completes");
        $display("  Packet Number = %6d  Packet Size = %6d beats", testCaseNum, pktBeatNum);
        $display("  Duration of send input DataStream: %6d", inputDataStreamEndCycle - inputDataStreamStartCycle + 1);
        $display("  Duration of pass inter AxiStream: %6d", interAxiStreamEndCycle - interAxiStreamStartCycle + 1);
        $display("  Duration of recv output DataStream: %6d", outputDataStreamEndCycle - outputDataStreamStartCycle + 1);
        $finish;
    endrule
endmodule
