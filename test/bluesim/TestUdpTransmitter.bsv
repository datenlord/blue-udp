import Randomizable :: *;
import Vector :: *;
import GetPut :: *;

import Ports :: *;
import SemiFifo :: *;
import UdpTransmitter :: *;
import EthernetTypes :: *;
import Utils :: *;
import HeaderGenerator :: *;


typedef enum {
    CONFIG, METADATA, DATA
} TestState deriving(Bits, Eq);


(* synthesize *)
module mkTestUdpTransmitter();
    Reg#(TestState) state <- mkReg(CONFIG);
    Reg#(Bit#(32))  cycle <- mkReg(0);
    
    Reg#(IpID) ipIdCounter <- mkReg(0);
    Reg#(Vector#(3, Data)) inputDataVec <- mkRegU;
    Reg#(Bit#(2)) inputVecIndex <- mkReg(0);
    Reg#(TotalHeader) totalHdrReg <- mkRegU;
    Reg#(MetaData) metaDataReg <- mkRegU;
    Reg#(Vector#(5,Data)) outputDataVec <- mkRegU;
    Reg#(Bit#(3)) outputVecIndex <- mkReg(0);
    Reg#(Bool) outputLast <- mkReg(False);
    Bit#(16) dataLen = 96;
    

    Randomize#(EthMacAddr) dstMacAddrRand <- mkGenericRandomizer;
    Randomize#(IpAddr) dstIpAddrRand <- mkGenericRandomizer;
    Randomize#(UdpPort) srcPortRand <- mkGenericRandomizer;
    Randomize#(UdpPort) dstPortRand <- mkGenericRandomizer;
    Randomize#(Data) dataRand <- mkGenericRandomizer;

    UdpTransmitter udpTransmitter <- mkUdpTransmitter;

    UdpConfig udpConfig = UdpConfig{
        srcMacAddr: 12345678,
        srcIpAddr: 234234423
    };

    rule test(True);
        if (cycle == 0) begin
            dstMacAddrRand.cntrl.init;
            dstIpAddrRand.cntrl.init;
            srcPortRand.cntrl.init;
            dstPortRand.cntrl.init;
            dataRand.cntrl.init;
        end

        $display("Cycle %d ---------------------------------------", cycle);
        cycle <= cycle + 1;
        if (cycle == 100) begin
            $display("Time Out!");
            $finish;
        end
    endrule

    rule doConfig if (state == CONFIG);
        udpTransmitter.udpConfig.put( udpConfig );
        state <= METADATA;
        $display("Set Udp Configuration successfully");
    endrule

    rule doMetaData if (state == METADATA);
        let dstMacAddr <- dstMacAddrRand.next;
        let dstIpAddr <- dstIpAddrRand.next;
        let dstPort <- dstPortRand.next;
        let srcPort <- srcPortRand.next;
        MetaData metaData = MetaData{
            dataLen: dataLen,
            macAddr: dstMacAddr,
            ipAddr: dstIpAddr,
            dstPort: dstPort,
            srcPort: srcPort
        };
        udpTransmitter.metaDataIn.put(metaData);

        metaDataReg <= metaData;
        totalHdrReg <= genTotalHeader(metaData, udpConfig, ipIdCounter);
        ipIdCounter <= ipIdCounter + 1;
        state <= DATA;
        $display("Set MetaData Successfully");
    endrule

    rule doSendData if (state == DATA);
        if (inputVecIndex < 3) begin
            Data randData <- dataRand.next;
            ByteEn byteEn = 1 << valueOf(DATA_BUS_BYTE_WIDTH) - 1;
            DataStream data = DataStream{
                data: randData,
                byteEn: byteEn,
                isFirst: inputVecIndex == 0,
                isLast:  inputVecIndex == 2
            };
            udpTransmitter.dataStreamIn.put(data);
            inputDataVec[inputVecIndex] <= randData;
            inputVecIndex <= inputVecIndex + 1;
            $display("Send %d Data Fragment", inputVecIndex);
        end
    endrule

    rule doReceiveData if (!outputLast);
        DataStream data = udpTransmitter.dataStreamOut.first;
        udpTransmitter.dataStreamOut.deq;
        $display("Receive %d data %x from UDPTransmitter",outputVecIndex, data.data);
        outputDataVec[outputVecIndex] <= data.data;
        outputVecIndex <= outputVecIndex + 1;
        outputLast <= data.isLast;

    endrule

    rule doCheck if (outputLast);

        Bit#(TOTAL_HDR_WIDTH) refHdr = pack(totalHdrReg);
        Bit#(TMul#(3,DATA_BUS_WIDTH)) refData = pack(inputDataVec);
        let refFrame = {refData, refHdr};
        Bit#(TMul#(5, DATA_BUS_WIDTH)) dutFrame = pack(outputDataVec);
        if (zeroExtend(refFrame) == dutFrame) begin
            $display("Pass");
        end
        else begin
            $display("Fail");
            $display("REF:%x",refFrame);
            $display("DUT:%x",dutFrame);
        end
        // Finish
        $finish;

    endrule
endmodule
