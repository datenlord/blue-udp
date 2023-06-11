import Connectable :: *;
import GetPut :: *;
import ClientServer :: *;
import FIFOF :: *;
import Randomizable :: *;

import UdpArpEthRxTx :: *;
import Ports :: *;
import EthernetTypes :: *;
import TestUtils :: *;
import Utils :: *;
import SemiFifo :: *;
import PrimUtils :: *;

typedef 128 TEST_CASE_NUM;
typedef 30000 MAX_CYCLE;
typedef 16 DST_DEVICE_NUM;
typedef 8 MAX_CHANNEL_DELAY;
typedef 128 REF_OUTPUT_BUF_SIZE;
typedef Bit#(10) UdpPayloadLen;
typedef Bit#(16) TestbenchCycle;
typedef Bit#(16) TestCaseCount;
typedef Bit#(8) FragmentCount;

typedef enum {
    META, 
    PAYLOAD
} InputGenState deriving(Bits, Eq);

(* synthesize *)
module mkTestUdpArpEthRxTx(Empty);
    UdpArpEthRxTx srcUdp <- mkUdpArpEthRxTx;
    UdpArpEthRxTx dstUdp <- mkUdpArpEthRxTx;
    Reg#(UdpConfig) dstUdpConfigReg <- mkRegU;
    Reg#(UdpConfig) srcUdpConfigReg <- mkRegU;
    RandomDelay#(AxiStream512, MAX_CHANNEL_DELAY) srcToDstDelayBuf <- mkRandomDelay;
    RandomDelay#(AxiStream512, MAX_CHANNEL_DELAY) dstToSrcDelayBuf <- mkRandomDelay;
    
    rule srcToDelayBuf;
        let data = srcUdp.axiStreamOutTx.first;
        srcUdp.axiStreamOutTx.deq;
        srcToDstDelayBuf.request.put(data);
    endrule
    mkConnection(srcToDstDelayBuf.response, dstUdp.axiStreamInRx);

    rule dstToDelayBuf;
        let data = dstUdp.axiStreamOutTx.first;
        dstUdp.axiStreamOutTx.deq;
        dstToSrcDelayBuf.request.put(data);
    endrule
    mkConnection(dstToSrcDelayBuf.response, srcUdp.axiStreamInRx);


    Reg#(Bool) randInit <- mkReg(False);
    Randomize#(IpAddr) srcIpAddrRand <- mkGenericRandomizer;
    Randomize#(EthMacAddr) srcMacAddrRand <- mkGenericRandomizer;
    Randomize#(IpAddr) dstIpAddrRand <- mkGenericRandomizer;
    Randomize#(EthMacAddr) dstMacAddrRand <- mkGenericRandomizer;

    Randomize#(UdpPayloadLen) dataLenRand <- mkGenericRandomizer;
    Randomize#(UdpPort) srcPortRand <- mkGenericRandomizer;
    Randomize#(UdpPort) dstPortRand <- mkGenericRandomizer;
    Randomize#(Data) dataRand <- mkGenericRandomizer;

    rule doRandInit if (!randInit);
        srcIpAddrRand.cntrl.init;
        srcMacAddrRand.cntrl.init;
        dstIpAddrRand.cntrl.init;
        dstMacAddrRand.cntrl.init;
    
        dataLenRand.cntrl.init;
        srcPortRand.cntrl.init;
        dstPortRand.cntrl.init;
        dataRand.cntrl.init;
        randInit <= True;
    endrule

    Reg#(TestbenchCycle) cycle <- mkReg(0);
    rule doCycleCount if (randInit);
        if (cycle == 0) begin
            // configure srcUdp and dstUdp
            let srcIp <- srcIpAddrRand.next;
            let srcMac <- srcMacAddrRand.next;
            let dstIp <- dstIpAddrRand.next;
            let dstMac <- dstMacAddrRand.next;
            UdpConfig srcUdpConfig = UdpConfig{
                macAddr: srcMac,
                ipAddr: srcIp,
                netMask: 0,
                gateWay: 0
            };
            UdpConfig dstUdpConfig = UdpConfig{
                macAddr: dstMac,
                ipAddr: dstIp,
                netMask: 0,
                gateWay: 0
            };
            srcUdp.udpConfig.put(srcUdpConfig);
            srcUdpConfigReg <= srcUdpConfig;
            
            dstUdp.udpConfig.put(dstUdpConfig);
            dstUdpConfigReg <= dstUdpConfig;
            $display("Configure srcUdp: Mac=%x IP=%x", srcMac, srcIp);
            $display("Configure dstUdp: Mac=%x IP=%x", dstMac, dstIp);
        end

        cycle <= cycle + 1;
        immAssert(
            cycle != fromInteger(valueOf(MAX_CYCLE)),
            "Testbench timeout assertion @ mkTestUdpEthRxTx",
            $format("Cycle count can't overflow %d", valueOf(MAX_CYCLE))
        );
        $display("\nCycle %d -----------------------------------",cycle);
    endrule

    FIFOF#(UdpIpMetaData) refMetaBuf <- mkSizedFIFOF(valueOf(REF_OUTPUT_BUF_SIZE));
    FIFOF#(DataStream) refDataBuf <- mkSizedFIFOF(valueOf(REF_OUTPUT_BUF_SIZE));
    Reg#(InputGenState) inputGenState <- mkReg(META);
    Reg#(UdpLength) dataLenReg <- mkReg(0);
    Reg#(UdpLength) putLenCount <- mkReg(0);
    Reg#(TestCaseCount) putCaseCount <- mkReg(0);
    Reg#(FragmentCount) putFragCount <- mkReg(0);
    TestCaseCount testCaseNum = fromInteger(valueOf(TEST_CASE_NUM));
    
    rule genInputToSrc if (putCaseCount < testCaseNum && randInit && cycle > 0);
        if (inputGenState == META) begin
            let randomLen <- dataLenRand.next;
            UdpLength minLen = fromInteger(valueOf(DATA_MIN_SIZE));

            let dataLen = minLen + zeroExtend(randomLen);
            let dstIpAddr = dstUdpConfigReg.ipAddr;
            let dstPort <- dstPortRand.next;
            let srcPort <- srcPortRand.next;

            UdpIpMetaData metaData = UdpIpMetaData{
                dataLen: dataLen,
                ipAddr: dstIpAddr,
                dstPort: dstPort,
                srcPort: srcPort
            };
            dataLenReg <= dataLen;
            srcUdp.udpIpMetaDataInTx.put(metaData);
            
            metaData.ipAddr = srcUdpConfigReg.ipAddr;
            refMetaBuf.enq(metaData);
            inputGenState <= PAYLOAD;
            $display("SrcUdp: Set MetaData of case %d Length:%d", putCaseCount, dataLen);
        end
        else if (inputGenState == PAYLOAD) begin
            let nxtDataLen = putLenCount + fromInteger(valueOf(DATA_BUS_BYTE_WIDTH));
            let data <- dataRand.next;
            let isFirst = putLenCount == 0;
            let isLast = nxtDataLen >= dataLenReg;
            ByteEn byteEn = (1 << valueOf(DATA_BUS_BYTE_WIDTH)) - 1;
            if (nxtDataLen >= dataLenReg) begin
                let surplusLen = nxtDataLen - dataLenReg;
                byteEn = byteEn >> surplusLen;
                data = bitMask(data, byteEn);
                putLenCount <= 0;
                putCaseCount <= putCaseCount + 1;
                putFragCount <= 0;
                inputGenState <= META;
            end
            else begin
                putLenCount <= nxtDataLen;
                putFragCount <= putFragCount + 1;
            end
            DataStream dataStream = DataStream{
                isFirst: isFirst,
                isLast: isLast,
                byteEn: byteEn,
                data:   data
            };
            srcUdp.dataStreamInTx.put(dataStream);
            refDataBuf.enq(dataStream);
            $display("SrcUdp: Send %d data fragment of case %x", putFragCount, putCaseCount);
        end
    endrule

    Reg#(TestCaseCount) getCaseCount <- mkReg(0);
    Reg#(FragmentCount) getFragCount <- mkReg(0);
    rule checkMetaDataFromDst;
        let dutMeta = dstUdp.udpIpMetaDataOutRx.first;
        dstUdp.udpIpMetaDataOutRx.deq;
        let refMeta = refMetaBuf.first; 
        refMetaBuf.deq;
        $display("DstUdp: receive MetaData of test case %d",getCaseCount);
        $display("Ref Meta: ", fshow(refMeta));
        $display("Dut Meta: ", fshow(dutMeta));
        immAssert(
            dutMeta == refMeta,
            "Check meta data from dstUdp @ mkTestUdpEth",
            $format("The output of dut and ref are inconsistent")
        );

    endrule

    rule checkDataStreamFromDst;
        let dutData = dstUdp.dataStreamOutRx.first;
        dstUdp.dataStreamOutRx.deq;
        let refData = refDataBuf.first; 
        refDataBuf.deq;
        
        $display("DstUdp: receive %d data fragment of case %d", getFragCount, getCaseCount);
        $display("Ref Data: ", fshow(refData));
        $display("Dut Data: ", fshow(dutData));
        immAssert(
            dutData == refData,
            "Check data from dstUdp @ mkTestUdpEth",
            $format("The output of dut and ref are inconsistent.")
        );

        if (dutData.isLast) begin
            getCaseCount <= getCaseCount + 1;
            getFragCount <= 0;
        end
        else begin
            getFragCount <= getFragCount + 1;
        end
    endrule

    rule doFinish if (getCaseCount == fromInteger(valueOf(TEST_CASE_NUM)));
        $display("Pass all %d test cases!", valueOf(TEST_CASE_NUM));
        $finish;
    endrule
endmodule
