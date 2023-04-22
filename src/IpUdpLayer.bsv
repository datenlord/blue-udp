import FIFOF :: *;
import GetPut :: *;
import PAClib :: *;
import Vector :: *;

import Utils :: *;
import Ports :: *;
import EthernetTypes :: *;

function IpUdpHeader genIpUdpHeader(UdpMetaData meta, UdpConfig udpConfig, IpID ipId);

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

    IpUdpHeader ipUdpHeader = IpUdpHeader{
        ipHeader: ipHeader,
        udpHeader: udpHeader
    };
    return ipUdpHeader;
endfunction

module mkIpUdpGenerator#(
    UdpMetaDataPipeOut metaDataIn,
    DataStreamPipeOut dataStreamIn,
    UdpConfig udpConfig
)(DataStreamPipeOut);

    FIFOF#(IpUdpHeader) ipUdpHeaderBuf <- mkFIFOF;
    // FIFOF#(DataStream) dataStreamInBuf <- mkFIFOF;
    Reg#(IpID) ipIdCounter <- mkReg(0);
    
    rule genIpUdpHeader;
        let metaData = metaDataIn.first; 
        metaDataIn.deq;
        IpUdpHeader ipUdpHeader = genIpUdpHeader(metaData, udpConfig, 1);
        ipUdpHeaderBuf.enq(ipUdpHeader);
        ipIdCounter <= ipIdCounter + 1;
        $display("IpUdpGen: genHeader of %d frame", ipIdCounter);
    endrule


    PipeOut#(IpUdpHeader) hdrStream = f_FIFOF_to_PipeOut(ipUdpHeaderBuf);
    DataStreamPipeOut dataStreamOut <- mkDataStreamInsert(dataStreamIn, hdrStream);

    return dataStreamOut;
endmodule


function UdpMetaData extractMetaData(IpUdpHeader hdr);
    UdpLength dataLen = hdr.udpHeader.length - fromInteger(valueOf(UDP_HDR_BYTE_WIDTH));
    UdpMetaData meta = UdpMetaData{
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
    let ipChecksum = getCheckSum(ipHdrVec);

    // Skip checksum of udp header
    // Vector#(UDP_HDR_WORD_WIDTH, Word) udpHdrVec = unpack(pack(hdr.udpHeader));
    // let udpChecksum = getCheckSum(udpHdrVec);

    let ipAddrMatch = hdr.ipHeader.dstIpAddr == udpConfig.ipAddr;
    let protocolMatch = hdr.ipHeader.ipProtocol == fromInteger(valueOf(IP_PROTOCOL_VAL));

    return (ipChecksum == 0) && ipAddrMatch && protocolMatch;
endfunction

interface IpUdpExtractor;
    interface UdpMetaDataPipeOut udpMetaDataOut;
    interface DataStreamPipeOut dataStreamOut;
endinterface

typedef enum{
    HEAD, PASS, THROW
} ExtState deriving(Bits, Eq);

module mkIpUdpExtractor#(
    DataStreamPipeOut dataStreamIn,
    UdpConfig udpConfig
)(IpUdpExtractor);
    FIFOF#(DataStream) dataStreamOutBuf <- mkFIFOF;
    FIFOF#(UdpMetaData) metaDataOutBuf <- mkFIFOF;
    Reg#(ExtState) extState <- mkReg(HEAD);
    
    DataStreamExtract#(IpUdpHeader) ipUdpExtractor <- mkDataStreamExtract(dataStreamIn);
    
    rule doCheck if (extState == HEAD);
        let ipUdpHeader = ipUdpExtractor.extractDataOut.first; 
        ipUdpExtractor.extractDataOut.deq;
        let checkRes = checkIpUdp(ipUdpHeader, udpConfig);
        if (checkRes) begin
            let metaData = extractMetaData(ipUdpHeader);
            metaDataOutBuf.enq(metaData);
            extState <= PASS;
            $display("IpUdp EXT: Check Pass");
        end
        else begin
            $display("IpUdp EXT: Check Fail ");
            extState <= THROW;
        end
    endrule

    rule doPass if (extState == PASS);
        let dataStream = ipUdpExtractor.dataStreamOut.first; 
        ipUdpExtractor.dataStreamOut.deq;
        dataStreamOutBuf.enq(dataStream);
        if (dataStream.isLast) begin
            extState <= HEAD;
        end
    endrule

    rule doThrow if (extState == THROW);
        let dataStream = ipUdpExtractor.dataStreamOut.first; 
        ipUdpExtractor.dataStreamOut.deq;
        if (dataStream.isLast) begin
            extState <= HEAD;
        end
    endrule

    interface PipeOut dataStreamOut = f_FIFOF_to_PipeOut(dataStreamOutBuf);
    interface PipeOut udpMetaDataOut = f_FIFOF_to_PipeOut(metaDataOutBuf);

endmodule


