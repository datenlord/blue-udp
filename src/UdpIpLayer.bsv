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
        NumAlias#(TDiv#(IP_HDR_WORD_WIDTH, 2), firstStageOutNum),
        NumAlias#(TAdd#(IP_CHECKSUM_WIDTH, 1), firstStageOutWidth),
        NumAlias#(TDiv#(firstStageOutNum, 4), secondStageOutNum),
        NumAlias#(TAdd#(firstStageOutWidth, 2), secondStageOutWidth),
        NumAlias#(TMul#(secondStageOutNum, 4), secondStageInNum),
        NumAlias#(TSub#(secondStageInNum, firstStageOutNum), appendNum)
    );

    FIFOF#(Vector#(firstStageOutNum, Bit#(firstStageOutWidth))) firstStageOutBuf <- mkFIFOF;
    FIFOF#(Vector#(secondStageOutNum, Bit#(secondStageOutWidth))) secondStageOutBuf <- mkFIFOF;

    rule secondStageAdder;
        let firstStageOutVec = firstStageOutBuf.first;
        firstStageOutBuf.deq;
        Vector#(secondStageInNum, Bit#(firstStageOutWidth)) appendedVec = append(firstStageOutVec, replicate(0));
        Vector#(secondStageOutNum, Vector#(4, Bit#(firstStageOutWidth))) secondStageInVec;
        for (Integer i = 0; i < valueOf(secondStageOutNum); i = i + 1) begin
            secondStageInVec[i] = takeAt(4*i, appendedVec);
        end
        secondStageOutBuf.enq(map(combAdderTree, secondStageInVec));
    endrule

    interface Put request;
        method Action put(IpHeader hdr);
            Vector#(IP_HDR_WORD_WIDTH, Word) ipHdrVec = unpack(pack(hdr));
            Vector#(firstStageOutNum, Vector#(2, Word)) firstStageInVec;
            for (Integer i = 0; i < valueOf(firstStageOutNum); i = i + 1) begin
                firstStageInVec[i] = takeAt(2*i, ipHdrVec);
            end
            firstStageOutBuf.enq(map(combAdderTree, firstStageInVec));
        endmethod
    endinterface

    interface Get response;
        method ActionValue#(IpCheckSum) get();
            let secondStageOutVec = secondStageOutBuf.first;
            secondStageOutBuf.deq;
            let sum = combAdderTree(secondStageOutVec);
            Bit#(TLog#(IP_HDR_WORD_WIDTH)) overFlow = truncateLSB(sum);
            IpCheckSum remainder = truncate(sum);
            IpCheckSum checkSum = remainder + zeroExtend(overFlow);
            return ~checkSum;
        endmethod
    endinterface
endmodule

function UdpIpHeader genUdpIpHeader(UdpIpMetaData meta, UdpConfig udpConfig, IpID ipId);

    UdpLength udpLen = meta.dataLen + fromInteger(valueOf(UDP_HDR_BYTE_WIDTH));
    IpTL ipLen = udpLen + fromInteger(valueOf(IP_HDR_BYTE_WIDTH));
    // generate ipHeader
    IpHeader ipHeader = IpHeader {
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

    // generate udpHeader
    UdpHeader udpHeader = UdpHeader{
        srcPort: meta.srcPort,
        dstPort: meta.dstPort,
        length:  udpLen,
        checksum:0
    };

    UdpIpHeader udpIpHeader = UdpIpHeader{
        ipHeader: ipHeader,
        udpHeader: udpHeader
    };
    return udpIpHeader;
endfunction

function UdpIpHeader genUdpIpHeaderForRoCE(UdpIpMetaData meta, UdpConfig udpConfig, IpID ipId);
    let udpIpHeader = genUdpIpHeader(meta, udpConfig, ipId);

    let crc32ByteWidth = valueOf(CRC32_BYTE_WIDTH);
    let udpLen = udpIpHeader.udpHeader.length;
    udpIpHeader.udpHeader.length = udpLen + fromInteger(crc32ByteWidth);
    let ipLen = udpIpHeader.ipHeader.ipTL;
    udpIpHeader.ipHeader.ipTL = ipLen + fromInteger(crc32ByteWidth);

    return udpIpHeader;
endfunction

function UdpIpHeader genUdpIpHeaderForICrc(UdpIpMetaData meta, UdpConfig udpConfig, IpID ipId);

    let udpIpHeader = genUdpIpHeaderForRoCE(meta, udpConfig, ipId);

    udpIpHeader.ipHeader.ipDS = setAllBits;
    udpIpHeader.ipHeader.ipTTL = setAllBits;
    udpIpHeader.ipHeader.ipChecksum = setAllBits;

    udpIpHeader.udpHeader.checksum = setAllBits;

    return udpIpHeader;
endfunction


module mkUdpIpStreamGenerator#(
    function UdpIpHeader genHeader(UdpIpMetaData meta, UdpConfig udpConfig, IpID ipId),
    UdpIpMetaDataPipeOut udpIpMetaDataIn,
    DataStreamPipeOut dataStreamIn,
    UdpConfig udpConfig
)(DataStreamPipeOut);

    Reg#(IpID) ipIdCounter <- mkReg(0);
    FIFOF#(UdpIpHeader) interUdpIpHeaderBuf <- mkFIFOF;
    FIFOF#(UdpIpHeader) udpIpHeaderBuf <- mkFIFOF;
    Server#(IpHeader, IpCheckSum) checkSumServer <- mkIpHdrCheckSumServer;

    rule doCheckSumReq;
        let metaData = udpIpMetaDataIn.first; 
        udpIpMetaDataIn.deq;
        UdpIpHeader udpIpHeader = genHeader(metaData, udpConfig, 1);
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
    DataStreamPipeOut udpIpStreamOut <- mkDataStreamInsert(HOLD, SWAP, dataStreamIn, udpIpHdrStream);

    return udpIpStreamOut;
endmodule


function UdpIpMetaData extractMetaData(UdpIpHeader hdr);
    UdpLength dataLen = hdr.udpHeader.length - fromInteger(valueOf(UDP_HDR_BYTE_WIDTH));
    UdpIpMetaData meta = UdpIpMetaData {
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


module mkUdpIpStreamExtractor#(
    DataStreamPipeOut udpIpStreamIn,
    UdpConfig udpConfig
)(UdpIpMetaDataAndDataStream);
    FIFOF#(DataStream) interDataStreamBuf <- mkFIFOF;
    FIFOF#(DataStream) dataStreamOutBuf <- mkFIFOF;
    FIFOF#(UdpIpMetaData) udpIpMetaDataInterBuf <- mkFIFOF;
    FIFOF#(UdpIpMetaData) udpIpMetaDataOutBuf <- mkFIFOF;
    Server#(IpHeader, IpCheckSum) checkSumServer <- mkIpHdrCheckSumServer;
    Reg#(Bool) interCheckRes <- mkReg(False);
    Reg#(Maybe#(Bool)) checkRes <- mkReg(Invalid);
    
    DataStreamExtract#(UdpIpHeader) udpIpExtractor <- mkDataStreamExtract(udpIpStreamIn);
    mkConnection(udpIpExtractor.dataStreamOut, interDataStreamBuf);

    rule doCheckSumReq;
        let udpIpHeader = udpIpExtractor.extractDataOut.first; 
        udpIpExtractor.extractDataOut.deq;
        let checkRes = checkUdpIp(udpIpHeader, udpConfig);
        checkSumServer.request.put(udpIpHeader.ipHeader);
        interCheckRes <= checkRes;
        let metaData = extractMetaData(udpIpHeader);
        udpIpMetaDataInterBuf.enq(metaData);
    endrule

    rule doCheckSumResp if (!isValid(checkRes));
        let checkSum <- checkSumServer.response.get();
        let passCheck = (checkSum == 0) && interCheckRes;
        checkRes <= tagged Valid passCheck;
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


module mkUdpIpStreamForICrc#(
    UdpIpMetaDataPipeOut udpIpMetaDataIn,
    DataStreamPipeOut dataStreamIn,
    UdpConfig udpConfig
)(DataStreamPipeOut);
    Reg#(Bool) isFirstReg <- mkReg(True);
    Reg#(IpID) ipIdCounter <- mkReg(0);
    FIFOF#(DataStream) dataStreamBuf <- mkFIFOF;
    FIFOF#(UdpIpHeader) udpIpHeaderBuf <- mkFIFOF;
    FIFOF#(Bit#(DUMMY_BITS_WIDTH)) dummyBitsBuf <- mkFIFOF;

    rule genDataStream;
        let dataStream = dataStreamIn.first;
        dataStreamIn.deq;
        if (isFirstReg) begin
            let swappedData = swapEndian(dataStream.data);
            BTH bth = unpack(truncateLSB(swappedData));
            bth.fecn = setAllBits;
            bth.becn = setAllBits;
            bth.resv6 = setAllBits;
            Data maskedData = {pack(bth), truncate(swappedData)};
            dataStream.data = swapEndian(maskedData);
        end
        dataStreamBuf.enq(dataStream);
        isFirstReg <= dataStream.isLast;
    endrule

    rule genUdpIpHeader;
        let metaData = udpIpMetaDataIn.first;
        udpIpMetaDataIn.deq;
        UdpIpHeader udpIpHeader = genUdpIpHeaderForICrc(metaData, udpConfig, 1);
        udpIpHeaderBuf.enq(udpIpHeader);
        ipIdCounter <= ipIdCounter + 1;
        $display("IpUdpGen: genHeader of %d frame", ipIdCounter);
    endrule

    rule genDummyBits;
        dummyBitsBuf.enq(setAllBits);
    endrule

    DataStreamPipeOut udpIpStream <- mkDataStreamInsert(
        HOLD,
        SWAP,
        convertFifoToPipeOut(dataStreamBuf),
        convertFifoToPipeOut(udpIpHeaderBuf)
    );
    DataStreamPipeOut dummyBitsAndUdpIpStream <- mkDataStreamInsert(
        HOLD,
        SWAP,
        udpIpStream,
        convertFifoToPipeOut(dummyBitsBuf)
    );
    return dummyBitsAndUdpIpStream;
endmodule

