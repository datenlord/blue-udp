import GetPut::*;
import FIFOF::*;
import Vector::*;
import PAClib::*;

import Ports::*;
import EthernetTypes::*;
import FragmentTypes::*;

interface UdpReceiver;
    interface Put#( UdpConfig  ) udpConfig;
    interface MetaDataPipeOut metaDataOut;
    interface Put#( DataStream ) dataStreamIn;
    interface DataStreamPipeOut dataStreamOut;
endinterface

typedef enum{
    HEADER, PAYLOAD, UNALIGN, THROW
} ReceiverState deriving(Bits,Eq);

typedef Vector#(TSub#(FRAGMENT_NUM,1),Fragment) HeaderFragBuf;

function Bool checkEtherMatch(TotalHeader hdr, UdpConfig udpConfig);
    // To be modified!
    let macAddrMatch = hdr.ethHeader.dstMacAddr == udpConfig.srcMacAddr;
    let ipAddrMatch = hdr.ipHeader.dstIpAddr == udpConfig.srcIpAddr;
    let addrMatch = macAddrMatch && ipAddrMatch;
    let ethTypeMatch = hdr.ethHeader.etherType == fromInteger(valueOf(ETH_TYPE_VAL));
    let ipVersionMatch = hdr.ipHeader.ipVersion == fromInteger(valueOf(IP_VERSION_VAL));
    let ipProtocolMatch = hdr.ipHeader.ipProtocol == fromInteger(valueOf(IP_PROTOCOL_VAL));
    let protocolMatch = ethTypeMatch && ipVersionMatch && ipProtocolMatch;
    return addrMatch && protocolMatch;
endfunction

function MetaData extractMetaData(TotalHeader hdr);
    UdpLength dataLen = hdr.udpHeader.length - fromInteger(valueOf(UDP_HDR_BYTE_WIDTH));
    MetaData meta = MetaData{
        dataLen: dataLen,
        macAddr: hdr.ethHeader.srcMacAddr,
        ipAddr : hdr.ipHeader.srcIpAddr,
        dstPort: hdr.udpHeader.dstPort,
        srcPort: hdr.udpHeader.srcPort
    };
    return meta;
endfunction

function SepDataStream seperateDataStreamIn(DataStream in);
    return SepDataStream{
        residue: truncateLSB(in.data),
        residueByteEn: truncateLSB(in.byteEn),
        unalignData: truncate(in.data),
        unalignByteEn: truncate(in.byteEn)
    };
endfunction

module mkUdpReceiver(UdpReceiver);
    FIFOF#(MetaData) metaDataOutBuf <- mkFIFOF;
    FIFOF#(DataStream) dataStreamOutBuf <- mkFIFOF;
    FIFOF#(DataStream) dataStreamInBuf <- mkFIFOF;
    Reg#(ReceiverState) udpState <- mkReg(HEADER);
    Reg#(Maybe#(UdpConfig)) udpConfigReg <- mkReg(Invalid);
    
    Reg#(HeaderFragBuf) hdrFragBuf <- mkRegU;
    Reg#(FragmentCounter) fragCounter <- mkReg(0);
    FragmentCounter fragCountMax = fromInteger(valueOf(FRAGMENT_NUM)-1);
    let isLastHdrFrag = fragCounter == fragCountMax;
    let nxtFragCount = isLastHdrFrag ? 0 : fragCounter + 1;

    Reg#(Residue) residueBuf <- mkRegU;
    Reg#(ResidueByteEn) residueByteEnBuf <- mkRegU;
    Reg#(Bool) isFirstDataFrag <- mkReg(False);


    rule doDataDemux if (isValid(udpConfigReg));
        if (udpState == HEADER) begin
            let dataStream = dataStreamInBuf.first;
            dataStreamInBuf.deq;
    
            $display("Rx: Get one Header frame");
            if (isLastHdrFrag) begin
                PreFragment preFrag = {dataStream.data, pack(hdrFragBuf)};
                Bit#(TOTAL_HDR_WIDTH) totalHdrBit= truncate(preFrag);
                TotalHeader totalHdr = unpack(totalHdrBit);
                
                let ethMatch = checkEtherMatch(totalHdr, fromMaybe(?,udpConfigReg));
                if (ethMatch)begin
                    MetaData metaData = extractMetaData(totalHdr);
                    metaDataOutBuf.enq(metaData);

                    residueBuf <= truncateLSB(dataStream.data);
                    residueByteEnBuf <= truncateLSB(dataStream.byteEn);

                    if(dataStream.isLast) udpState <= UNALIGN;
                    else udpState <= PAYLOAD;
                    isFirstDataFrag <= True;
                end
                else begin
                    udpState <= THROW;
                end
            end 
            else begin
                hdrFragBuf[fragCounter] <= dataStream.data;
            end
            fragCounter <= nxtFragCount;
        end
        else if (udpState == PAYLOAD) begin
            $display("Rx: Get one payload fragment");
            DataStream dataStream = dataStreamInBuf.first;
            dataStreamInBuf.deq;
            isFirstDataFrag <= False;
            
            SepDataStream sepData = seperateDataStreamIn(dataStream);
            residueBuf <= sepData.residue;
            residueByteEnBuf <= sepData.residueByteEn;
            dataStream.data  = {sepData.unalignData,residueBuf};
            dataStream.byteEn = {sepData.unalignByteEn,residueByteEnBuf};
            dataStream.isFirst = isFirstDataFrag;

            if (dataStream.isLast) begin
                if(sepData.residueByteEn == 0) begin
                    udpState <= HEADER;
                end
                else begin
                    udpState <= UNALIGN;
                    dataStream.isLast = False;
                end
            end

            dataStreamOutBuf.enq(dataStream);
        end
        else if (udpState == UNALIGN) begin
            DataStream dataStream = DataStream{
                isFirst: isFirstDataFrag,
                isLast: True,
                data: zeroExtend(residueBuf),
                byteEn: zeroExtend(residueByteEnBuf)
            };
            udpState <= HEADER;
            dataStreamOutBuf.enq(dataStream);
        end
        else if (udpState == THROW) begin
            $display("Throw ethernet fragment");
            dataStreamInBuf.deq;
            if(dataStreamInBuf.first.isLast) begin
                udpState <= HEADER;
            end
        end
    endrule
    

    interface Put udpConfig;
        method Action put(UdpConfig conf);
            udpConfigReg <= tagged Valid conf;
        endmethod
    endinterface

    interface PipeOut metaDataOut = f_FIFOF_to_PipeOut(metaDataOutBuf);
    interface PipeOut dataStreamOut = f_FIFOF_to_PipeOut(dataStreamOutBuf);
    interface Put dataStreamIn = toPut(dataStreamInBuf);

endmodule
