import FIFOF :: *;
import GetPut :: *;
import Vector :: *;
import ClientServer :: *;
import Connectable :: *;

import Utils :: *;
import Ports :: *;
import SemiFifo :: *;
import EthernetTypes :: *;


module mkIpHdrCheckSumServer(Server#(IpHeader, IpCheckSum)) 
    provisos(
        NumAlias#(TDiv#(IP_HDR_WORD_WIDTH, 4), firstStageOutNum),
        NumAlias#(TAdd#(IP_CHECKSUM_WIDTH, 2), firstStageOutWidth),
        NumAlias#(TDiv#(firstStageOutNum, 4), secondStageOutNum),
        NumAlias#(TAdd#(firstStageOutWidth, 2), secondStageOutWidth)
    );

    function Bit#(TAdd#(width, 1)) add(Bit#(width) a, Bit#(width) b) = zeroExtend(a) + zeroExtend(b);
    function Bit#(TAdd#(width, 1)) pass(Bit#(width) a) = zeroExtend(a);

    FIFOF#(Vector#(firstStageOutNum, Bit#(firstStageOutWidth))) firstStageOutBuf <- mkFIFOF;
    FIFOF#(Vector#(secondStageOutNum, Bit#(secondStageOutWidth))) secondStageOutBuf <- mkFIFOF;

    rule secondStageAdder;
        let firstStageOutVec = firstStageOutBuf.first;
        firstStageOutBuf.deq;
        let firstStageOutReducedBy2 = mapPairs(add, pass, firstStageOutVec);
        let firstStageOutReducedBy4 = mapPairs(add, pass, firstStageOutReducedBy2);
        secondStageOutBuf.enq(firstStageOutReducedBy4);
    endrule

    interface Put request;
        method Action put(IpHeader hdr);
            Vector#(IP_HDR_WORD_WIDTH, Word) ipHdrVec = unpack(pack(hdr));
            let ipHdrVecReducedBy2 = mapPairs(add, pass, ipHdrVec);
            let ipHdrVecReducedBy4 = mapPairs(add, pass, ipHdrVecReducedBy2);
            firstStageOutBuf.enq(ipHdrVecReducedBy4);
        endmethod
    endinterface

    interface Get response;
        method ActionValue#(IpCheckSum) get();
            let secondStageOutVec = secondStageOutBuf.first;
            secondStageOutBuf.deq;
            let sum = secondStageOutVec[0];
            Bit#(TLog#(IP_HDR_WORD_WIDTH)) overFlow = truncateLSB(sum);
            IpCheckSum remainder = truncate(sum);
            IpCheckSum checkSum = remainder + zeroExtend(overFlow);
            return ~checkSum;
        endmethod
    endinterface
endmodule

function UdpIpHeader genUdpIpHeader(UdpIpMetaData metaData, UdpConfig udpConfig, IpID ipId);
    // Calculate packet length
    UdpLength udpLen = metaData.dataLen + fromInteger(valueOf(UDP_HDR_BYTE_WIDTH));
    IpTL ipLen = udpLen + fromInteger(valueOf(IP_HDR_BYTE_WIDTH));
    // generate ipHeader
    IpHeader ipHeader = IpHeader {
        ipVersion : fromInteger(valueOf(IP_VERSION_VAL)),
        ipIHL     : fromInteger(valueOf(IP_IHL_VAL)),
        ipDscp    : metaData.ipDscp,
        ipEcn     : metaData.ipEcn,
        ipTL      : ipLen,
        ipID      : ipId,
        ipFlag    : fromInteger(valueOf(IP_FLAGS_VAL)),
        ipOffset  : fromInteger(valueOf(IP_OFFSET_VAL)),
        ipTTL     : fromInteger(valueOf(IP_TTL_VAL)),
        ipProtocol: fromInteger(valueOf(IP_PROTOCOL_VAL)),
        ipChecksum: 0,
        srcIpAddr : udpConfig.ipAddr,
        dstIpAddr : metaData.ipAddr
    };
    // generate udpHeader
    UdpHeader udpHeader = UdpHeader {
        srcPort : metaData.srcPort,
        dstPort : metaData.dstPort,
        length  : udpLen,
        checksum: 0
    };
    // generate udpIpHeader
    UdpIpHeader udpIpHeader = UdpIpHeader {
        ipHeader: ipHeader,
        udpHeader: udpHeader
    };
    return udpIpHeader;
endfunction

module mkUdpIpStream#(
    UdpConfig udpConfig,
    DataStreamPipeOut dataStreamIn,
    UdpIpMetaDataPipeOut udpIpMetaDataIn,
    function UdpIpHeader genHeader(UdpIpMetaData meta, UdpConfig udpConfig, IpID ipId)
)(DataStreamPipeOut);
    IpID defaultIpId = 1;

    Reg#(IpID) ipIdCounter <- mkReg(0);
    FIFOF#(UdpIpHeader) interUdpIpHeaderBuf <- mkFIFOF;
    FIFOF#(UdpIpHeader) udpIpHeaderBuf <- mkFIFOF;
    Server#(IpHeader, IpCheckSum) checkSumServer <- mkIpHdrCheckSumServer;

    rule doCheckSumReq;
        let metaData = udpIpMetaDataIn.first; 
        udpIpMetaDataIn.deq;
        UdpIpHeader udpIpHeader = genHeader(metaData, udpConfig, defaultIpId);
        interUdpIpHeaderBuf.enq(udpIpHeader);
        checkSumServer.request.put(udpIpHeader.ipHeader);
    endrule

    rule genUdpIpHeader;
        let ipCheckSum <- checkSumServer.response.get();
        let interUdpIpHdr = interUdpIpHeaderBuf.first;
        interUdpIpHeaderBuf.deq;
        interUdpIpHdr.ipHeader.ipChecksum = ipCheckSum;
        udpIpHeaderBuf.enq(interUdpIpHdr);
        ipIdCounter <= ipIdCounter + 1;
        $display("IpUdpGen: genHeader of %d frame", ipIdCounter);
    endrule

    PipeOut#(UdpIpHeader) udpIpHdrStream = convertFifoToPipeOut(udpIpHeaderBuf);
    DataStreamPipeOut udpIpStreamOut <- mkAppendDataStreamHead(HOLD, SWAP, dataStreamIn, udpIpHdrStream);

    return udpIpStreamOut;
endmodule


function UdpIpMetaData extractUdpIpMetaData(UdpIpHeader hdr);
    UdpLength dataLen = hdr.udpHeader.length - fromInteger(valueOf(UDP_HDR_BYTE_WIDTH));
    UdpIpMetaData metaData = UdpIpMetaData {
        dataLen: dataLen,
        ipAddr : hdr.ipHeader.srcIpAddr,
        ipDscp : hdr.ipHeader.ipDscp,
        ipEcn  : hdr.ipHeader.ipEcn,
        dstPort: hdr.udpHeader.dstPort,
        srcPort: hdr.udpHeader.srcPort
    };
    return metaData;
endfunction

function Bool checkUdpIpHeader(UdpIpHeader hdr, UdpConfig udpConfig);
    // TODO: To be modified!!!
    //Vector#(IP_HDR_WORD_WIDTH, Word) ipHdrVec = unpack(pack(hdr.ipHeader));
    // let ipChecksum = getCheckSum(ipHdrVec);

    // Skip checksum of udp header
    // Vector#(UDP_HDR_WORD_WIDTH, Word) udpHdrVec = unpack(pack(hdr.udpHeader));
    // let udpChecksum = getCheckSum(udpHdrVec);

    let ipAddrMatch = hdr.ipHeader.dstIpAddr == udpConfig.ipAddr;
    let protocolMatch = hdr.ipHeader.ipProtocol == fromInteger(valueOf(IP_PROTOCOL_VAL));
    
    return ipAddrMatch && protocolMatch;
endfunction

interface UdpIpMetaDataAndDataStream;
    interface UdpIpMetaDataPipeOut udpIpMetaDataOut;
    interface DataStreamPipeOut dataStreamOut;
endinterface

module mkUdpIpMetaDataAndDataStream#(
    UdpConfig udpConfig,
    DataStreamPipeOut udpIpStreamIn,
    function UdpIpMetaData extractMetaData(UdpIpHeader hdr)
)(UdpIpMetaDataAndDataStream);
    FIFOF#(DataStream) interDataStreamBuf <- mkFIFOF;
    FIFOF#(DataStream) dataStreamOutBuf <- mkFIFOF;
    FIFOF#(UdpIpMetaData) udpIpMetaDataInterBuf <- mkFIFOF;
    FIFOF#(UdpIpMetaData) udpIpMetaDataOutBuf <- mkFIFOF;
    Server#(IpHeader, IpCheckSum) checkSumServer <- mkIpHdrCheckSumServer;
    Reg#(Bool) interCheckRes <- mkReg(False);
    Reg#(Maybe#(Bool)) checkRes <- mkReg(Invalid);
    
    ExtractDataStream#(UdpIpHeader) udpIpExtractor <- mkExtractDataStreamHead(udpIpStreamIn);
    mkConnection(udpIpExtractor.dataStreamOut, interDataStreamBuf);

    rule doCheckSumReq;
        let udpIpHeader = udpIpExtractor.extractDataOut.first; 
        udpIpExtractor.extractDataOut.deq;
        let checkRes = checkUdpIpHeader(udpIpHeader, udpConfig);
        checkSumServer.request.put(udpIpHeader.ipHeader);
        interCheckRes <= checkRes;
        let metaData = extractMetaData(udpIpHeader);
        udpIpMetaDataInterBuf.enq(metaData);
    endrule

    rule doCheckSumResp if (!isValid(checkRes));
        let checkSum <- checkSumServer.response.get();
        let passCheck = (checkSum == 0) && interCheckRes;
        checkRes <= tagged Valid passCheck;
        $display("UdpIpStreamExtractor: Check Pass ");
    endrule

    rule passMetaData if (isValid(checkRes));
        let metaData = udpIpMetaDataInterBuf.first;
        udpIpMetaDataInterBuf.deq;
        if (fromMaybe(?, checkRes)) begin
            udpIpMetaDataOutBuf.enq(metaData);
        end
        else begin
            $display("UdpIpStreamExtractor: Check Fail ");
        end
    endrule

    rule passDataStream if (isValid(checkRes));
        let dataStream = interDataStreamBuf.first; 
        interDataStreamBuf.deq;
        if (fromMaybe(?, checkRes)) begin
            dataStreamOutBuf.enq(dataStream);
        end
        if (dataStream.isLast) begin
            checkRes <= tagged Invalid;
        end
    endrule

    interface PipeOut dataStreamOut = convertFifoToPipeOut(dataStreamOutBuf);
    interface PipeOut udpIpMetaDataOut = convertFifoToPipeOut(udpIpMetaDataOutBuf);
endmodule


