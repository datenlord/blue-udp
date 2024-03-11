
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
import UdpIpEthCmacRxTx :: *;

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
typedef 10 TEST_PKT_BEAT_NUM;


(* synthesize *)
module mkTestUdpIpEthBypassTxPerf();
    Integer testCaseNum = valueOf(TEST_CASE_NUM);
    Integer maxCycleNum = valueOf(MAX_CYCLE_NUM);
    Integer pktBeatNum = valueOf(TEST_PKT_BEAT_NUM);
    Bool isSelectBypassChannel = False;

    // Common Signals
    Reg#(Bool) isInit <- mkReg(False);
    Reg#(Bit#(CYCLE_COUNT_WIDTH)) cycleCounter <- mkReg(0);
    Reg#(Bit#(BEAT_COUNT_WIDTH)) inputBeatCounter <- mkReg(0);

    Reg#(Bit#(CASE_COUNT_WIDTH)) inputPktCounter <- mkReg(0);
    Reg#(Bit#(CASE_COUNT_WIDTH)) outputPktCounter <- mkReg(0);

    Reg#(Bit#(CYCLE_COUNT_WIDTH)) inputStartCycle <- mkRegU;
    Reg#(Bit#(CYCLE_COUNT_WIDTH)) inputEndCycle <- mkRegU;
    Reg#(Bit#(CYCLE_COUNT_WIDTH)) outputStartCycle <- mkRegU;
    Reg#(Bit#(CYCLE_COUNT_WIDTH)) outputEndCycle <- mkRegU;

    Reg#(Bool) isRecvFirstBeat <- mkReg(False);

    // DUT
    let udpConfigVal = UdpConfig {
        macAddr: fromInteger(valueOf(DUT_MAC_ADDR)),
        ipAddr: fromInteger(valueOf(DUT_IP_ADDR)),
        netMask: fromInteger(valueOf(DUT_NET_MASK)),
        gateWay: fromInteger(valueOf(DUT_GATE_WAY))
    };
    let udpIpEthBypassRxTx <- mkGenericUdpIpEthBypassRxTx(`IS_SUPPORT_RDMA);

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
    rule sendMetaData if (isInit);  
        
        let macMetaData = MacMetaData {
            macAddr: fromInteger(valueOf(DUT_MAC_ADDR)),
            ethType: fromInteger(valueOf(ETH_TYPE_IP))
        };

        let udpIpMetaData = UdpIpMetaData {
            dataLen: fromInteger(valueOf(TEST_PKT_BEAT_NUM)) * fromInteger(valueOf(DATA_BUS_BYTE_WIDTH)),
            ipAddr: fromInteger(valueOf(DUT_IP_ADDR)),
            ipDscp: 0,
            ipEcn: 0,
            dstPort: fromInteger(valueOf(UDP_PORT_RDMA)),
            srcPort: fromInteger(valueOf(UDP_PORT_RDMA))
        };

        if (isSelectBypassChannel) begin
            udpIpEthBypassRxTx.macMetaDataTxIn.put(
                MacMetaDataWithBypassTag {
                    macMetaData: macMetaData,
                    isBypass: True
                }
            );
        end
        else begin
            udpIpEthBypassRxTx.macMetaDataTxIn.put(
                MacMetaDataWithBypassTag {
                    macMetaData: macMetaData,
                    isBypass: False
                }
            );
            udpIpEthBypassRxTx.udpIpMetaDataTxIn.put(udpIpMetaData);
        end
        $display("Testbench: send MetaData to DUT");
    endrule

    rule sendDataStream if (isInit && inputPktCounter < fromInteger(testCaseNum));
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
                inputEndCycle <= cycleCounter;
            end
        end
        else begin
            inputBeatCounter <= inputBeatCounter + 1;
        end

        if (inputPktCounter == 0 && inputBeatCounter == 0) begin
            inputStartCycle <= cycleCounter;
        end

        $display("Testbench: Sends %d DataStream of %d testcase", inputBeatCounter, inputPktCounter);
    endrule

    rule recvOutputData;
        let axiStream = udpIpEthBypassRxTx.axiStreamTxOut.first;
        udpIpEthBypassRxTx.axiStreamTxOut.deq;
        if (axiStream.tLast) begin
            outputPktCounter <= outputPktCounter + 1;
            if (outputPktCounter == fromInteger(testCaseNum) - 1) begin
                outputEndCycle <= cycleCounter;
            end
        end
        if (!isRecvFirstBeat) begin
            outputStartCycle <= cycleCounter;
            isRecvFirstBeat <= True;
        end
        $display("Testbench: recv one AXI-Stream Beat of %d testcase", outputPktCounter);
    endrule

    rule finishTest if (outputPktCounter == fromInteger(testCaseNum));
        $display("Testbench: mkUdpIpEthBypassRxTx pass all %5d testcases", testCaseNum);
        $display("Duration of send input data: %d", inputEndCycle - inputStartCycle + 1);
        $display("Duration of recv output data: %d", outputEndCycle - outputStartCycle + 1);
        $finish;
    endrule
endmodule
