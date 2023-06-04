import FIFOF :: *;
import GetPut :: *;
import PAClib :: *;
import Vector :: *;

import Utils :: *;
import Ports :: *;
import EthernetTypes :: *;

function UdpIpHeader genUdpIpHeader(UdpIpMetaData meta, UdpConfig udpConfig, IpID ipId);

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
        srcIpAddr :udpConfig.ipAddr,
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
    // Vector#(UDP_HDR_WORD_WIDTH, Word) udpHdrVec = unpack(pack(udpHeader));
    // udpHeader.checksum = getCheckSum(udpHdrVec);

    UdpIpHeader udpIpHeader = UdpIpHeader{
        ipHeader: ipHeader,
        udpHeader: udpHeader
    };
    return udpIpHeader;
endfunction

module mkUdpIpStreamGenerator#(
    UdpIpMetaDataPipeOut udpIpMetaDataIn,
    DataStreamPipeOut dataStreamIn,
    UdpConfig udpConfig
)(DataStreamPipeOut);

    FIFOF#(UdpIpHeader) udpIpHeaderBuf <- mkFIFOF;
    // FIFOF#(DataStream) dataStreamInBuf <- mkFIFOF;
    Reg#(IpID) ipIdCounter <- mkReg(0);
    
    rule genUdpIpHeader;
        let metaData = udpIpMetaDataIn.first; 
        udpIpMetaDataIn.deq;
        UdpIpHeader udpIpHeader = genUdpIpHeader(metaData, udpConfig, 1);
        udpIpHeaderBuf.enq(udpIpHeader);
        ipIdCounter <= ipIdCounter + 1;
        $display("IpUdpGen: genHeader of %d frame", ipIdCounter);
    endrule

    PipeOut#(UdpIpHeader) udpIpHdrStream = f_FIFOF_to_PipeOut(udpIpHeaderBuf);
    DataStreamPipeOut udpIpStreamOut <- mkDataStreamInsert(dataStreamIn, udpIpHdrStream);

    return udpIpStreamOut;
endmodule


function UdpIpMetaData extractMetaData(UdpIpHeader hdr);
    UdpLength dataLen = hdr.udpHeader.length - fromInteger(valueOf(UDP_HDR_BYTE_WIDTH));
    UdpIpMetaData meta = UdpIpMetaData{
        dataLen: dataLen,
        ipAddr : hdr.ipHeader.srcIpAddr,
        dstPort: hdr.udpHeader.dstPort,
        srcPort: hdr.udpHeader.srcPort
    };
    return meta;
endfunction

function Bool checkUdpIp(UdpIpHeader hdr, UdpConfig udpConfig);
    // To be modified!!!
    Vector#(IP_HDR_WORD_WIDTH, Word) ipHdrVec = unpack(pack(hdr.ipHeader));
    let ipChecksum = getCheckSum(ipHdrVec);

    // Skip checksum of udp header
    // Vector#(UDP_HDR_WORD_WIDTH, Word) udpHdrVec = unpack(pack(hdr.udpHeader));
    // let udpChecksum = getCheckSum(udpHdrVec);

    let ipAddrMatch = hdr.ipHeader.dstIpAddr == udpConfig.ipAddr;
    let protocolMatch = hdr.ipHeader.ipProtocol == fromInteger(valueOf(IP_PROTOCOL_VAL));

    return (ipChecksum == 0) && ipAddrMatch && protocolMatch;
endfunction

interface UdpIpMetaDataAndDataStream;
    interface UdpIpMetaDataPipeOut udpIpMetaDataOut;
    interface DataStreamPipeOut dataStreamOut;
endinterface

typedef enum{
    HEAD, PASS, THROW
} ExtState deriving(Bits, Eq);

module mkUdpIpStreamExtractor#(
    DataStreamPipeOut udpIpStreamIn,
    UdpConfig udpConfig
)(UdpIpMetaDataAndDataStream);
    FIFOF#(DataStream) dataStreamOutBuf <- mkFIFOF;
    FIFOF#(UdpIpMetaData) udpIpMetaDataOutBuf <- mkFIFOF;
    Reg#(ExtState) extState <- mkReg(HEAD);
    
    DataStreamExtract#(UdpIpHeader) udpIpExtractor <- mkDataStreamExtract(udpIpStreamIn);
    
    rule doCheck if (extState == HEAD);
        let udpIpHeader = udpIpExtractor.extractDataOut.first; 
        udpIpExtractor.extractDataOut.deq;
        let checkRes = checkUdpIp(udpIpHeader, udpConfig);
        if (checkRes) begin
            let metaData = extractMetaData(udpIpHeader);
            udpIpMetaDataOutBuf.enq(metaData);
            extState <= PASS;
            $display("IpUdp EXT: Check Pass");
        end
        else begin
            $display("IpUdp EXT: Check Fail ");
            extState <= THROW;
        end
    endrule

    rule doPass if (extState == PASS);
        let dataStream = udpIpExtractor.dataStreamOut.first; 
        udpIpExtractor.dataStreamOut.deq;
        dataStreamOutBuf.enq(dataStream);
        if (dataStream.isLast) begin
            extState <= HEAD;
        end
    endrule

    rule doThrow if (extState == THROW);
        let dataStream = udpIpExtractor.dataStreamOut.first; 
        udpIpExtractor.dataStreamOut.deq;
        if (dataStream.isLast) begin
            extState <= HEAD;
        end
    endrule

    interface PipeOut dataStreamOut = f_FIFOF_to_PipeOut(dataStreamOutBuf);
    interface PipeOut udpIpMetaDataOut = f_FIFOF_to_PipeOut(udpIpMetaDataOutBuf);

endmodule


