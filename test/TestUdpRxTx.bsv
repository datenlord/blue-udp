import Connectable::*;
import GetPut::*;
import ClientServer::*;
import FIFOF::*;
import Randomizable::*;
import PAClib::*;

import UdpRxTx::*;
import Ports::*;
import EthernetTypes::*;
import TestUtils::*;
import Utils::*;

typedef enum {
    META, PAYLOAD
} InputGenState deriving(Bits, Eq);

(* synthesize *)
module mkTestUdpRxTx();

    UdpRxTx udpRxTx <- mkUdpRxTx;
    RandomDelay#(DataStream, 4) loopBuf <- mkRandomDelay(2);
    mkConnection(toGet(udpRxTx.dataStreamOutTx), loopBuf.request);
    mkConnection(loopBuf.response, udpRxTx.dataStreamInRx);

    Randomize#(Byte) dataLenRand <- mkGenericRandomizer;
    // Randomize#(EthMacAddr) dstMacAddrRand <- mkGenericRandomizer;
    // Randomize#(IpAddr) dstIpAddrRand <- mkGenericRandomizer;
    Randomize#(UdpPort) srcPortRand <- mkGenericRandomizer;
    Randomize#(UdpPort) dstPortRand <- mkGenericRandomizer;
    Randomize#(Data) dataRand <- mkGenericRandomizer;
    UdpConfig udpConfig = UdpConfig{
        srcMacAddr: 48'h6a8036f99e56,
        srcIpAddr: 32'h1f019
    };

    Reg#(Bit#(16)) cycle <- mkReg(0);
    rule test;
        if (cycle == 0) begin
            udpRxTx.udpConfig.put(udpConfig);

            dataLenRand.cntrl.init;
            // dstMacAddrRand.cntrl.init;
            // dstIpAddrRand.cntrl.init;
            srcPortRand.cntrl.init;
            dstPortRand.cntrl.init;
            dataRand.cntrl.init;
        end
        cycle <= cycle + 1;
        $display("\nCycle %d -----------------------------------",cycle);
        if(cycle == 800) begin
            $display("Error: Time Out!");
            $finish;
        end
    endrule

    Integer frameNum = 15;

    FIFOF#(MetaData) refMetaBuf <- mkSizedFIFOF(20);
    FIFOF#(DataStream) refDataBuf <- mkSizedFIFOF(200);
    Reg#(InputGenState) inputGenState <- mkReg(META);
    Reg#(UdpLength) dataLenReg <- mkReg(0);
    Reg#(UdpLength) dataLenCount <- mkReg(0);
    Reg#(Bit#(16)) framePutCount <- mkReg(0);
    rule genInput if (framePutCount != fromInteger(frameNum));
        if (inputGenState == META) begin
            let randLen <- dataLenRand.next;
            UdpLength minLen = fromInteger(valueOf(DATA_MIN_SIZE));
            let dataLen = minLen + zeroExtend(randLen);
            let dstMacAddr = udpConfig.srcMacAddr;
            let dstIpAddr = udpConfig.srcIpAddr;
            let dstPort <- dstPortRand.next;
            let srcPort <- srcPortRand.next;

            MetaData metaData = MetaData{
                dataLen: dataLen,
                macAddr: dstMacAddr,
                ipAddr: dstIpAddr,
                dstPort: dstPort,
                srcPort: srcPort
            };
            dataLenReg <= dataLen;
            udpRxTx.metaDataTx.put(metaData);
            refMetaBuf.enq(metaData);
            inputGenState <= PAYLOAD;
            $display("Testbench: Set MetaData of Frame%d data Length:%d",framePutCount,dataLen);
        end
        else if (inputGenState == PAYLOAD) begin
            let nxtDataLen = dataLenCount + fromInteger(valueOf(DATA_BUS_BYTE_WIDTH));
            let data <- dataRand.next;
            let isFirst = dataLenCount == 0;
            let isLast = nxtDataLen >= dataLenReg;
            ByteEn byteEn = (1 << valueOf(DATA_BUS_BYTE_WIDTH)) - 1;
            if (nxtDataLen >= dataLenReg) begin
                let surplusLen = nxtDataLen - dataLenReg;
                byteEn = byteEn >> surplusLen;
                data = bitMask(data, byteEn);
                dataLenCount <= 0;
                inputGenState <= META;
                framePutCount <= framePutCount + 1;
            end
            else begin
                dataLenCount <= nxtDataLen;
            end
            DataStream dataStream = DataStream{
                isFirst: isFirst,
                isLast: isLast,
                byteEn: byteEn,
                data:   data
            };
            udpRxTx.dataStreamInTx.put(dataStream);
            refDataBuf.enq(dataStream);
            $display("Testbench: Send DataStream of Frame %d",framePutCount);
        end

    endrule

    Reg#(Bit#(16)) frameGetCount <- mkReg(0);
    Reg#(Bit#(16)) fragGetCount  <- mkReg(0);
    rule checkMetaData;
        let dutMeta = udpRxTx.metaDataRx.first;
        udpRxTx.metaDataRx.deq;
        let refMeta = refMetaBuf.first; refMetaBuf.deq;
        $display("Testbench: receive MetaData of frame %d",frameGetCount);
        if(dutMeta != refMeta) begin
            $display("Error: MetaData of frame %d is fault", frameGetCount);
            $display("Ref Meta: ", fshow(refMeta));
            $display("Dut Meta: ", fshow(dutMeta));
            $finish;
        end
    endrule

    rule checkDataStream;
        let dutData = udpRxTx.dataStreamOutRx.first;
        udpRxTx.dataStreamOutRx.deq;
        let refData = refDataBuf.first; refDataBuf.deq;
        $display("Testbench: Get %d Data Fragment of frame %d",fragGetCount,frameGetCount);
        if(dutData != refData) begin
            $display("Error: The %d Data Fragment of frame %d is fault",fragGetCount,frameGetCount);
            $display("Ref Data: ", fshow(refData));
            $display("Dut Data: ", fshow(dutData));
            $finish;
        end
        Bit#(16) maxFrameCount = fromInteger(frameNum - 1);
        if(dutData.isLast) begin
            if(frameGetCount == maxFrameCount) begin
                $display("Testbench: Pass all test cases");
                $finish;
            end
            frameGetCount <= frameGetCount + 1;
            fragGetCount <= 0;
        end
        else begin
            fragGetCount <= fragGetCount + 1; 
        end
    endrule

endmodule