import FIFOF::*;
import GetPut::*;
import PAClib::*;
import Vector::*;

import Utils::*;
import Ports::*;
import EthernetTypes::*;

function IpUdpHeader genIpUdpHeader(MetaData meta, UdpConfig udpConfig, IpID ipId);

    UdpLength udpLen = meta.dataLen + fromInteger(valueOf(UDP_HDR_BYTE_WIDTH));
    IpTL ipLen = udpLen + fromInteger(valueOf(IP_HDR_BYTE_WIDTH));
    // generate ipHeader
    IpHeader ipHeader = IpHeader{
        ipVersion: fromInteger(valueOf(IP_VERSION_VAL)),
        ipIHL:     fromInteger(valueOf(IP_IHL_VAL)),
        ipDS:      fromInteger(valueOf(IP_DS_VAL)),
        ipTL:      ipLen,
        ipID:      ipId,
        ipFlag:    fromInteger(valueOf(IP_FLAGS_VAL)),
        ipOffset:  fromInteger(valueOf(IP_OFFSET_VAL)),
        ipTTL:     fromInteger(valueOf(IP_TTL_VAL)),
        ipProtocol:fromInteger(valueOf(IP_PROTOCOL_VAL)),
        ipChecksum:0,
        srcIpAddr :udpConfig.srcIpAddr,
        dstIpAddr :meta.ipAddr
    };
    Vector#(IP_HDR_WORD_WIDTH, Word) ipHdrVec = unpack(pack(ipHeader));
    ipHeader.ipChecksum = getCheckSum(ipHdrVec);
    // generate udpHeader
    UdpHeader udpHeader = UdpHeader{
        srcPort: meta.srcPort,
        dstPort: meta.dstPort,
        length:  udpLen,
        checksum:0
    };
    Vector#(UDP_HDR_WORD_WIDTH, Word) udpHdrVec = unpack(pack(udpHeader));
    udpHeader.checksum = getCheckSum(udpHdrVec);

    IpUdpHeader ipUdpHeader = IpUdpHeader{
        ipHeader: ipHeader,
        udpHeader: udpHeader
    };
    return ipUdpHeader;
endfunction

module mkIpUdpGenerator#(
    MetaDataPipeOut metaDataIn,
    DataStreamPipeOut dataStreamIn,
    Maybe#(UdpConfig) udpConfig
)(DataStreamPipeOut);

    FIFOF#(IpUdpHeader) ipUdpHeaderBuf <- mkFIFOF;
    // FIFOF#(DataStream) dataStreamInBuf <- mkFIFOF;
    Reg#(IpID) ipIdCounter <- mkReg(0);
    let udpConfigVal = fromMaybe(?, udpConfig);
    
    rule genIpUdpHeader if (isValid(udpConfig));
        let metaData = metaDataIn.first; metaDataIn.deq;
        IpUdpHeader ipUdpHeader = genIpUdpHeader(metaData, udpConfigVal, ipIdCounter);
        ipUdpHeaderBuf.enq(ipUdpHeader);
        ipIdCounter <= ipIdCounter + 1;
        $display("IpUdpGen: genHeader of %d frame", ipIdCounter);
    endrule


    PipeOut#(IpUdpHeader) hdrStream = f_FIFOF_to_PipeOut(ipUdpHeaderBuf);
    DataStreamPipeOut dataStreamOut <- mkDataStreamInsert(dataStreamIn, hdrStream);

    return dataStreamOut;

endmodule


function MetaData extractMetaData(IpUdpHeader hdr);
    UdpLength dataLen = hdr.udpHeader.length - fromInteger(valueOf(UDP_HDR_BYTE_WIDTH));
    MetaData meta = MetaData{
        dataLen: dataLen,
        ipAddr : hdr.ipHeader.srcIpAddr,
        dstPort: hdr.udpHeader.dstPort,
        srcPort: hdr.udpHeader.srcPort
    };
    return meta;
endfunction

function Bool checkIpUdp(IpUdpHeader hdr, UdpConfig udpConfig);
    // To be modified!!!
    Vector#(IP_HDR_WORD_WIDTH, Word) ipHdrVec = unpack(pack(hdr.ipHeader));
    Vector#(UDP_HDR_WORD_WIDTH, Word) udpHdrVec = unpack(pack(hdr.udpHeader));
    let ipChecksum = getCheckSum(ipHdrVec);
    let udpChecksum = getCheckSum(udpHdrVec);

    let ipAddrMatch = hdr.ipHeader.dstIpAddr == udpConfig.srcIpAddr;
    let protocolMatch = hdr.ipHeader.ipProtocol == fromInteger(valueOf(IP_PROTOCOL_VAL));

    return (ipChecksum == 0) && (udpChecksum == 0) && ipAddrMatch && protocolMatch;
endfunction

interface IpUdpExtractor;
    interface MetaDataPipeOut   metaDataOut;
    interface DataStreamPipeOut dataStreamOut;
endinterface

typedef enum{
    PASS, THROW
} ExtState deriving(Bits, Eq);

module mkIpUdpExtractor#(
    DataStreamPipeOut dataStreamIn,
    Maybe#(UdpConfig) udpConfig
)(IpUdpExtractor);
    FIFOF#(DataStream) dataStreamOutBuf <- mkFIFOF;
    FIFOF#(MetaData) metaDataOutBuf <- mkFIFOF;
    Reg#(Maybe#(ExtState)) extState[2] <- mkCReg(2, Invalid);
    
    DataStreamExtract#(IpUdpHeader) ipUdpExt <- mkDataStreamExtract(dataStreamIn);
    
    rule doCheck if (isValid(udpConfig));
        let ipUdpHeader = ipUdpExt.extractDataOut.first; ipUdpExt.extractDataOut.deq;
        let checkRes = checkIpUdp( ipUdpHeader, fromMaybe(?,udpConfig));
        if (checkRes) begin
            let metaData = extractMetaData(ipUdpHeader);
            metaDataOutBuf.enq(metaData);
            extState[0] <= tagged Valid PASS;
            $display("IpUdp EXT: Check Pass");
        end
        else begin
            $display("IpUdp EXT: Check Fail ");
            extState[0] <= tagged Valid THROW;
        end
    endrule

    rule doPass if (isValid(extState[1]));
        let dataStream = ipUdpExt.dataStreamOut.first; ipUdpExt.dataStreamOut.deq;
        if (fromMaybe(?, extState[1]) == PASS) begin
            dataStreamOutBuf.enq(dataStream);
        end
        if (dataStream.isLast) begin
            extState[1] <= tagged Invalid;
        end
    endrule

    interface PipeOut dataStreamOut = f_FIFOF_to_PipeOut(dataStreamOutBuf);
    interface PipeOut metaDataOut = f_FIFOF_to_PipeOut(metaDataOutBuf);

endmodule


