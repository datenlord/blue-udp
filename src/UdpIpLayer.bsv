import FIFOF :: *;
import GetPut :: *;
import Vector :: *;
import ClientServer :: *;
import Connectable :: *;

import Ports :: *;
import EthUtils :: *;
import EthernetTypes :: *;
import StreamHandler :: *;

import SemiFifo :: *;


module mkIpHdrCheckSumStream#(
    FifoOut#(IpHeader) ipHeaderStream
)(FifoOut#(IpCheckSum)) 
    provisos(
        NumAlias#(TDiv#(IP_HDR_WORD_WIDTH, 2), firstStageOutNum),
        NumAlias#(TAdd#(IP_CHECKSUM_WIDTH, 1), firstStageOutWidth),
        NumAlias#(TDiv#(firstStageOutNum, 4), secondStageOutNum),
        NumAlias#(TAdd#(firstStageOutWidth, 2), secondStageOutWidth)
    );

    function Bit#(TAdd#(width, 1)) add(Bit#(width) a, Bit#(width) b) = zeroExtend(a) + zeroExtend(b);
    function Bit#(TAdd#(width, 1)) pass(Bit#(width) a) = zeroExtend(a);

    FIFOF#(Vector#(firstStageOutNum, Bit#(firstStageOutWidth))) firstStageOutBuf <- mkFIFOF;
    FIFOF#(Vector#(secondStageOutNum, Bit#(secondStageOutWidth))) secondStageOutBuf <- mkFIFOF;
    FIFOF#(IpCheckSum) ipCheckSumOutBuf <- mkFIFOF;

    rule firstStageAdder;
        let ipHeader = ipHeaderStream.first;
        ipHeaderStream.deq;
        Vector#(IP_HDR_WORD_WIDTH, Word) ipHdrVec = unpack(pack(ipHeader));
        let ipHdrVecReducedBy2 = mapPairs(add, pass, ipHdrVec);
        firstStageOutBuf.enq(ipHdrVecReducedBy2);
    endrule

    rule secondStageAdder;
        let firstStageOutVec = firstStageOutBuf.first;
        firstStageOutBuf.deq;
        let firstStageOutReducedBy2 = mapPairs(add, pass, firstStageOutVec);
        let firstStageOutReducedBy4 = mapPairs(add, pass, firstStageOutReducedBy2);
        secondStageOutBuf.enq(firstStageOutReducedBy4);
    endrule

    rule lastStageAdder;
        let secondStageOutVec = secondStageOutBuf.first;
        secondStageOutBuf.deq;

        let secondStageOutReducedBy2 = mapPairs(add, pass, secondStageOutVec);

        let sum = secondStageOutReducedBy2[0];
        Bit#(TLog#(IP_HDR_WORD_WIDTH)) overFlow = truncateLSB(sum);
        IpCheckSum remainder = truncate(sum);
        IpCheckSum checkSum = ~(remainder + zeroExtend(overFlow));
        ipCheckSumOutBuf.enq(checkSum);
    endrule

    return convertFifoToFifoOut(ipCheckSumOutBuf);
endmodule

module mkIpHdrCheckSumServer(Server#(IpHeader, IpCheckSum)) 
    provisos(
        NumAlias#(TDiv#(IP_HDR_WORD_WIDTH, 2), firstStageOutNum),
        NumAlias#(TAdd#(IP_CHECKSUM_WIDTH, 1), firstStageOutWidth),
        NumAlias#(TDiv#(firstStageOutNum, 4), secondStageOutNum),
        NumAlias#(TAdd#(firstStageOutWidth, 2), secondStageOutWidth)
    );

    function Bit#(TAdd#(width, 1)) add(Bit#(width) a, Bit#(width) b) = zeroExtend(a) + zeroExtend(b);
    function Bit#(TAdd#(width, 1)) pass(Bit#(width) a) = zeroExtend(a);

    FIFOF#(Vector#(firstStageOutNum, Bit#(firstStageOutWidth))) firstStageOutBuf <- mkFIFOF;
    FIFOF#(Vector#(secondStageOutNum, Bit#(secondStageOutWidth))) secondStageOutBuf <- mkFIFOF;
    FIFOF#(IpCheckSum) ipCheckSumOutBuf <- mkFIFOF;

    rule secondStageAdder;
        let firstStageOutVec = firstStageOutBuf.first;
        firstStageOutBuf.deq;
        let firstStageOutReducedBy2 = mapPairs(add, pass, firstStageOutVec);
        let firstStageOutReducedBy4 = mapPairs(add, pass, firstStageOutReducedBy2);
        secondStageOutBuf.enq(firstStageOutReducedBy4);
    endrule

    rule lastStageAdder;
        let secondStageOutVec = secondStageOutBuf.first;
        secondStageOutBuf.deq;

        let secondStageOutReducedBy2 = mapPairs(add, pass, secondStageOutVec);

        let sum = secondStageOutReducedBy2[0];
        Bit#(TLog#(IP_HDR_WORD_WIDTH)) overFlow = truncateLSB(sum);
        IpCheckSum remainder = truncate(sum);
        IpCheckSum checkSum = ~(remainder + zeroExtend(overFlow));
        ipCheckSumOutBuf.enq(checkSum);
    endrule

    interface Put request;
        method Action put(IpHeader hdr);
            Vector#(IP_HDR_WORD_WIDTH, Word) ipHdrVec = unpack(pack(hdr));
            let ipHdrVecReducedBy2 = mapPairs(add, pass, ipHdrVec);
            firstStageOutBuf.enq(ipHdrVecReducedBy2);
        endmethod
    endinterface

    interface Get response = toGet(ipCheckSumOutBuf);
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
        ipProtocol: fromInteger(valueOf(IP_PROTOCOL_UDP)),
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
    DataStreamFifoOut dataStreamIn,
    UdpIpMetaDataFifoOut udpIpMetaDataIn,
    function UdpIpHeader genHeader(UdpIpMetaData meta, UdpConfig udpConfig, IpID ipId)
)(DataStreamFifoOut);
    Integer interBufDepth = 4;
    IpID defaultIpId = 1;

    Reg#(IpID) ipIdCounter <- mkReg(0);
    FIFOF#(UdpIpHeader) interUdpIpHeaderBuf <- mkSizedFIFOF(interBufDepth);
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

    let interDataStream <- mkSizedFifoToFifoOut(interBufDepth, dataStreamIn);
    FifoOut#(UdpIpHeader) udpIpHdrStream = convertFifoToFifoOut(udpIpHeaderBuf);
    DataStreamFifoOut udpIpStreamOut <- mkAppendDataStreamHead(HOLD, SWAP, interDataStream, udpIpHdrStream);

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
    let protocolMatch = hdr.ipHeader.ipProtocol == fromInteger(valueOf(IP_PROTOCOL_UDP));
    
    return ipAddrMatch && protocolMatch;
endfunction

interface UdpIpMetaDataAndDataStream;
    interface UdpIpMetaDataFifoOut udpIpMetaDataOut;
    interface DataStreamFifoOut dataStreamOut;
    // An additional channel to pass UDP/IP packet check result out
    interface FifoOut#(Bool) integrityCheckOut;
endinterface

module mkUdpIpMetaDataAndDataStream#(
    UdpConfig udpConfig,
    DataStreamFifoOut udpIpStreamIn,
    function UdpIpMetaData extractMetaData(UdpIpHeader hdr)
)(UdpIpMetaDataAndDataStream);
    Integer integrityCheckBufDepth = 8;
    Integer interBufDepth = 6;

    // Reg#(Maybe#(Bool)) udpIpHdrChkState <- mkReg(Invalid);
    // Output Buffer
    FIFOF#(DataStream) dataStreamOutBuf <- mkFIFOF;
    FIFOF#(UdpIpMetaData) udpIpMetaDataOutBuf <- mkFIFOF;
    FIFOF#(Bool) integrityCheckOutBuf <- mkSizedFIFOF(integrityCheckBufDepth);
    
    // Intermediate Buffer
    FIFOF#(IpHeader) ipHeaderInterBuf <- mkFIFOF;
    FIFOF#(UdpIpMetaData) udpIpMetaDataInterBuf <- mkSizedFIFOF(interBufDepth);
    FIFOF#(Bool) udpIpHdrFieldChkInterBuf <- mkSizedFIFOF(interBufDepth);
    FIFOF#(Bool) dataStreamPassFlagBuf <- mkSizedFIFOF(interBufDepth);
    
    
    ExtractDataStream#(UdpIpHeader) udpIpExtractor <- mkExtractDataStreamHead(udpIpStreamIn);
    let interDataStream <- mkSizedFifoToFifoOut(interBufDepth, udpIpExtractor.dataStreamOut);
    let ipHdrCheckSumStream <- mkIpHdrCheckSumStream(convertFifoToFifoOut(ipHeaderInterBuf));

    rule forkMetaDataStream;
        let udpIpHeader = udpIpExtractor.extractDataOut.first; 
        udpIpExtractor.extractDataOut.deq;

        ipHeaderInterBuf.enq(udpIpHeader.ipHeader);
        udpIpHdrFieldChkInterBuf.enq(checkUdpIpHeader(udpIpHeader, udpConfig));
        udpIpMetaDataInterBuf.enq(extractMetaData(udpIpHeader));
    endrule

    rule joinCheckSumStream;
        let ipHdrCheckSum = ipHdrCheckSumStream.first;
        ipHdrCheckSumStream.deq;

        let udpIpHdrFieldChk = udpIpHdrFieldChkInterBuf.first;
        udpIpHdrFieldChkInterBuf.deq;
        let passCheck = (ipHdrCheckSum == 0) && udpIpHdrFieldChk;
        //
        integrityCheckOutBuf.enq(passCheck);
        //
        let udpIpMetaData = udpIpMetaDataInterBuf.first;
        udpIpMetaDataInterBuf.deq;
        if (passCheck) begin
            udpIpMetaDataOutBuf.enq(udpIpMetaData);
            $display("UdpIpStreamExtractor: Check Pass");
        end
        //
        dataStreamPassFlagBuf.enq(passCheck);
    endrule

    rule passDataStream;
        if (dataStreamPassFlagBuf.notEmpty()) begin
            let isPassDataStream = dataStreamPassFlagBuf.first;
            let dataStream = interDataStream.first; 
            interDataStream.deq;
            if (isPassDataStream) begin
                dataStreamOutBuf.enq(dataStream);
            end
            if (dataStream.isLast) begin
                dataStreamPassFlagBuf.deq;
            end
        end
    endrule

    interface FifoOut dataStreamOut = convertFifoToFifoOut(dataStreamOutBuf);
    interface FifoOut udpIpMetaDataOut = convertFifoToFifoOut(udpIpMetaDataOutBuf);
    interface FifoOut integrityCheckOut = convertFifoToFifoOut(integrityCheckOutBuf);
endmodule


