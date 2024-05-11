import FIFOF :: *;

import Ports :: *;
import EthUtils :: *;
import UdpIpLayer :: *;
import Connectable :: *;
import EthernetTypes :: *;
import StreamHandler :: *;

import SemiFifo :: *;
import CrcDefines :: *;
import AxiStreamTypes :: *;

function UdpIpHeader genUdpIpHeaderForRoCE(UdpIpMetaData metaData, UdpConfig udpConfig, IpID ipId);
    let udpIpHeader = genUdpIpHeader(metaData, udpConfig, ipId);

    let crc32ByteWidth = valueOf(CRC32_BYTE_WIDTH);
    let udpLen = udpIpHeader.udpHeader.length;
    udpIpHeader.udpHeader.length = udpLen + fromInteger(crc32ByteWidth);
    let ipLen = udpIpHeader.ipHeader.ipTL;
    udpIpHeader.ipHeader.ipTL = ipLen + fromInteger(crc32ByteWidth);

    return udpIpHeader;
endfunction

function UdpIpHeader genUdpIpHeaderForICrc(UdpIpMetaData metaData, UdpConfig udpConfig, IpID ipId);
    let udpIpHeader = genUdpIpHeaderForRoCE(metaData, udpConfig, ipId);

    udpIpHeader.ipHeader.ipDscp = setAllBits;
    udpIpHeader.ipHeader.ipEcn = setAllBits;
    udpIpHeader.ipHeader.ipTTL = setAllBits;
    udpIpHeader.ipHeader.ipChecksum = setAllBits;

    udpIpHeader.udpHeader.checksum = setAllBits;

    return udpIpHeader;
endfunction


module mkUdpIpStreamForICrcGen#(
    UdpIpMetaDataFifoOut udpIpMetaDataIn,
    DataStreamFifoOut dataStreamIn,
    UdpConfig udpConfig
)(DataStreamFifoOut);
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

    DataStreamFifoOut udpIpStream <- mkAppendDataStreamHead(
        HOLD,
        SWAP,
        convertFifoToFifoOut(dataStreamBuf),
        convertFifoToFifoOut(udpIpHeaderBuf)
    );
    DataStreamFifoOut dummyBitsAndUdpIpStream <- mkAppendDataStreamHead(
        HOLD,
        SWAP,
        udpIpStream,
        convertFifoToFifoOut(dummyBitsBuf)
    );
    return dummyBitsAndUdpIpStream;
endmodule


module mkUdpIpStreamForRdma#(
    UdpIpMetaDataFifoOut udpIpMetaDataIn,
    DataStreamFifoOut dataStreamIn,
    UdpConfig udpConfig
)(DataStreamFifoOut);
    Integer udpIpStreamInterBufDepth = 16;
    FIFOF#(DataStream) dataStreamBuf <- mkFIFOF;
    FIFOF#(DataStream) dataStreamCrcBuf <- mkFIFOF;
    FIFOF#(UdpIpMetaData) udpIpMetaDataBuf <- mkFIFOF;
    FIFOF#(UdpIpMetaData) udpIpMetaDataCrcBuf <- mkFIFOF;
    FIFOF#(UdpLength) preComputeLengthBuf <- mkFIFOF;
    FIFOF#(DataStream) udpIpStreamInterBuf <- mkSizedFIFOF(udpIpStreamInterBufDepth);

    rule forkUdpIpMetaDataIn;
        let udpIpMetaData = udpIpMetaDataIn.first;
        udpIpMetaDataIn.deq;
        udpIpMetaDataBuf.enq(udpIpMetaData);
        udpIpMetaDataCrcBuf.enq(udpIpMetaData);
        let dataStreamLen = udpIpMetaData.dataLen +
                            fromInteger(valueOf(IP_HDR_BYTE_WIDTH)) +
                            fromInteger(valueOf(UDP_HDR_BYTE_WIDTH));
        preComputeLengthBuf.enq(dataStreamLen);
    endrule

    rule forkDataStreamIn;
        let dataStream = dataStreamIn.first;
        dataStreamIn.deq;
        dataStreamBuf.enq(dataStream);
        dataStreamCrcBuf.enq(dataStream);
    endrule

    DataStreamFifoOut udpIpStream <- mkUdpIpStream(
        udpConfig,
        convertFifoToFifoOut(dataStreamBuf),
        convertFifoToFifoOut(udpIpMetaDataBuf),
        genUdpIpHeaderForRoCE
    );
    mkConnection(udpIpStream, convertFifoToFifoIn(udpIpStreamInterBuf));

    DataStreamFifoOut udpIpStreamForICrc <- mkUdpIpStreamForICrcGen(
        convertFifoToFifoOut(udpIpMetaDataCrcBuf),
        convertFifoToFifoOut(dataStreamCrcBuf),
        udpConfig
    );

    let crc32Stream <- mkCrc32AxiStreamLocalFifoOut(
        CRC_MODE_SEND,
        convertDataStreamToAxiStream(udpIpStreamForICrc)
    );

    DataStreamFifoOut udpIpStreamWithICrc <- mkAppendDataStreamTail(
        HOLD,
        HOLD,
        convertFifoToFifoOut(udpIpStreamInterBuf),
        crc32Stream,
        convertFifoToFifoOut(preComputeLengthBuf)
    );

    return udpIpStreamWithICrc;
endmodule


function UdpIpMetaData extractUdpIpMetaDataForRoCE(UdpIpHeader hdr);
    let meta = extractUdpIpMetaData(hdr);
    meta.dataLen = meta.dataLen - fromInteger(valueOf(CRC32_BYTE_WIDTH));
    return meta;
endfunction

module mkUdpIpStreamForICrcChk#(
    DataStreamFifoOut udpIpStreamIn
)(DataStreamFifoOut);

    function BTHUdpIpHeader setBTHUdpIpHeader(BTHUdpIpHeader header);
        header.bth.fecn = setAllBits;
        header.bth.becn = setAllBits;
        header.bth.resv6 = setAllBits;
        header.udpHeader.checksum = setAllBits;
        header.ipHeader.ipDscp = setAllBits;
        header.ipHeader.ipEcn = setAllBits;
        header.ipHeader.ipTTL = setAllBits;
        header.ipHeader.ipChecksum = setAllBits;
        return header;
    endfunction

    function DoubleDataStream processUdpIpStream(DoubleDataStream udpIpStream);
        if (udpIpStream.isFirst) begin
            let data = swapEndian(udpIpStream.data);
            let bthUdpIpHdr = setBTHUdpIpHeader(unpack(truncateLSB(data)));
            data = {pack(bthUdpIpHdr), truncate(data)};
            udpIpStream.data = swapEndian(data);
        end
        return udpIpStream;
    endfunction

    let doubleUdpIpStreamIn <- mkDoubleDataStreamFifoOut(udpIpStreamIn);
    let newUdpIpStream = processUdpIpStream(doubleUdpIpStreamIn.first);
    let interDoubleUdpIpStreamFifoOut = translateFifoOut(doubleUdpIpStreamIn, newUdpIpStream);
    let interUdpIpStreamFifoOut <- mkHalfDataStreamFifoOut(interDoubleUdpIpStreamFifoOut);
    
    FIFOF#(Bit#(DUMMY_BITS_WIDTH)) dummyBitsBuf <- mkFIFOF;
    let udpIpStreamOut <- mkAppendDataStreamHead(
        HOLD,
        SWAP,
        interUdpIpStreamFifoOut,
        convertFifoToFifoOut(dummyBitsBuf)
    );

    rule genDummyBits;
        dummyBitsBuf.enq(setAllBits);
    endrule

    return udpIpStreamOut;
endmodule


module mkRemoveICrcFromDataStream#(
    FifoOut#(Bit#(streamLenWidth)) streamLenIn,
    DataStreamFifoOut dataStreamIn
)(DataStreamFifoOut) provisos(
    NumAlias#(TLog#(DATA_BUS_BYTE_WIDTH), frameLenWidth),
    NumAlias#(TLog#(TAdd#(CRC32_BYTE_WIDTH, 1)), shiftAmtWidth),
    Add#(frameLenWidth, frameNumWidth, streamLenWidth)
);
    Integer crc32ByteWidth = valueOf(CRC32_BYTE_WIDTH);
    // +Reg +Cnt
    Reg#(Bool) isGetStreamLenReg <- mkReg(False);
    Reg#(Bool) isICrcInterFrameReg <- mkRegU;
    Reg#(Bit#(shiftAmtWidth)) frameShiftAmtReg <- mkRegU;
    Reg#(DataStream) foreDataStreamReg <- mkRegU;

    FIFOF#(DataStream) dataStreamOutBuf <- mkFIFOF;

    rule getStreamLen if (!isGetStreamLenReg);
        let streamLen = streamLenIn.first;
        streamLenIn.deq;
        Bit#(frameLenWidth) lastFrameLen = truncate(streamLen);
        
        if (lastFrameLen > fromInteger(crc32ByteWidth) || lastFrameLen == 0) begin
            isICrcInterFrameReg <= False;
            frameShiftAmtReg <= fromInteger(crc32ByteWidth);
            //$display("Remove ICRC shiftAmt=%d", frameShiftAmtReg);
        end
        else begin
            isICrcInterFrameReg <= True;
            frameShiftAmtReg <= truncate(fromInteger(crc32ByteWidth) - lastFrameLen);
        end
        isGetStreamLenReg <= True;
    endrule

    rule passDataStream if (isGetStreamLenReg);
        let dataStream = dataStreamIn.first;
        dataStreamIn.deq;
        
        if (!isICrcInterFrameReg) begin
            if (dataStream.isLast) begin
                let byteEn = dataStream.byteEn >> frameShiftAmtReg;
                dataStream.byteEn = byteEn;
                dataStream.data = bitMask(dataStream.data, byteEn);
            end
            dataStreamOutBuf.enq(dataStream);
        end
        else begin
            foreDataStreamReg <= dataStream;
            let foreDataStream = foreDataStreamReg;
            if (dataStream.isLast) begin
                let byteEn = foreDataStream.byteEn >> frameShiftAmtReg;
                foreDataStream.byteEn = byteEn;
                foreDataStream.data = bitMask(foreDataStream.data, byteEn);
                foreDataStream.isLast = True;
            end
            if (!dataStream.isFirst) begin
                dataStreamOutBuf.enq(foreDataStream);
            end
        end
        if (dataStream.isLast) begin
            isGetStreamLenReg <= False;
        end
    endrule

    return convertFifoToFifoOut(dataStreamOutBuf);
endmodule

typedef 4096 RDMA_PACKET_MAX_SIZE;
typedef 4 RDMA_META_BUF_SIZE;
typedef TDiv#(RDMA_PACKET_MAX_SIZE, DATA_BUS_BYTE_WIDTH) RDMA_PACKET_MAX_BEAT;
typedef TAdd#(RDMA_PACKET_MAX_BEAT, 16) RDMA_PAYLOAD_BUF_SIZE;

typedef enum {
    ICRC_IDLE,
    ICRC_META,
    ICRC_PAYLOAD
} ICrcCheckState deriving(Bits, Eq, FShow);

module mkUdpIpMetaDataAndDataStreamForRdma#(
    DataStreamFifoOut udpIpStreamIn,
    UdpConfig udpConfig
)(UdpIpMetaDataAndDataStream);

    FIFOF#(DataStream) udpIpStreamBuf <- mkFIFOF;
    FIFOF#(DataStream) udpIpStreamForICrcBuf <- mkFIFOF;

    FIFOF#(Bool) integrityCheckOutBuf <- mkFIFOF;

    rule forkUdpIpStream;
        let udpIpStream = udpIpStreamIn.first;
        udpIpStreamIn.deq;
        udpIpStreamBuf.enq(udpIpStream);
        udpIpStreamForICrcBuf.enq(udpIpStream);
    endrule

    DataStreamFifoOut udpIpStreamForICrc <- mkUdpIpStreamForICrcChk(
        convertFifoToFifoOut(udpIpStreamForICrcBuf)
    );

    let crc32Stream <- mkCrc32AxiStreamLocalFifoOut(
        CRC_MODE_RECV,
        convertDataStreamToAxiStream(udpIpStreamForICrc)
    );

    UdpIpMetaDataAndDataStream udpIpMetaAndDataStream <- mkUdpIpMetaDataAndDataStream(
        udpConfig,
        convertFifoToFifoOut(udpIpStreamBuf),
        extractUdpIpMetaDataForRoCE
    );

    FIFOF#(UdpLength) dataStreamLengthBuf <- mkFIFOF;
    FIFOF#(UdpIpMetaData) udpIpMetaDataBuf <- mkFIFOF;
    rule forkUdpIpMetaData;
        Integer iCrcByteWidth = valueOf(CRC32_BYTE_WIDTH);
        let udpIpMetaData = udpIpMetaAndDataStream.udpIpMetaDataOut.first;
        udpIpMetaAndDataStream.udpIpMetaDataOut.deq;
        dataStreamLengthBuf.enq(udpIpMetaData.dataLen + fromInteger(iCrcByteWidth));
        udpIpMetaDataBuf.enq(udpIpMetaData);
    endrule

    let udpIpMetaDataBuffered <- mkSizedFifoToFifoOut(
        valueOf(RDMA_META_BUF_SIZE),
        convertFifoToFifoOut(udpIpMetaDataBuf)
    );

    DataStreamFifoOut dataStreamWithOutICrc <- mkRemoveICrcFromDataStream(
        convertFifoToFifoOut(dataStreamLengthBuf),
        udpIpMetaAndDataStream.dataStreamOut
    );

    DataStreamFifoOut dataStreamBuffered <- mkSizedBramFifoToFifoOut(
        valueOf(RDMA_PAYLOAD_BUF_SIZE),
        dataStreamWithOutICrc
    );

    Reg#(Bool) isPassICrcCheck <- mkReg(False);
    Reg#(ICrcCheckState) iCrcCheckStateReg <- mkReg(ICRC_IDLE);
    FIFOF#(DataStream) dataStreamOutBuf <- mkFIFOF;
    FIFOF#(UdpIpMetaData) udpIpMetaDataOutBuf <- mkFIFOF;
    rule doCrcCheck;
        case(iCrcCheckStateReg) matches
            ICRC_IDLE: begin
                let crcChecksum = crc32Stream.first;
                crc32Stream.deq;
                $display("RdmaUdpIpEthRx gets iCRC result %x", crcChecksum);
                if (crcChecksum == 0) begin
                    isPassICrcCheck <= True;
                    $display("Pass ICRC check");
                end
                else begin
                    isPassICrcCheck <= False;
                    $display("FAIL ICRC check");
                end

                // check the integrity of UDP/IP Header
                let udpIpHdrChkRes = udpIpMetaAndDataStream.integrityCheckOut.first;
                udpIpMetaAndDataStream.integrityCheckOut.deq;
                
                integrityCheckOutBuf.enq(udpIpHdrChkRes && crcChecksum == 0);
                if (udpIpHdrChkRes) begin
                    iCrcCheckStateReg <= ICRC_META;
                end
            end
            ICRC_META: begin
                let udpIpMetaData = udpIpMetaDataBuffered.first;
                udpIpMetaDataBuffered.deq;
                if (isPassICrcCheck) begin
                    udpIpMetaDataOutBuf.enq(udpIpMetaData);
                end
                iCrcCheckStateReg <= ICRC_PAYLOAD;
            end
            ICRC_PAYLOAD: begin
                let dataStream = dataStreamBuffered.first;
                dataStreamBuffered.deq;
                if (isPassICrcCheck) begin
                    dataStreamOutBuf.enq(dataStream);
                end
                if (dataStream.isLast) begin
                    iCrcCheckStateReg <= ICRC_IDLE;
                end
            end
        endcase
    endrule

    interface udpIpMetaDataOut = convertFifoToFifoOut(udpIpMetaDataOutBuf);
    interface dataStreamOut = convertFifoToFifoOut(dataStreamOutBuf);
    interface integrityCheckOut = convertFifoToFifoOut(integrityCheckOutBuf);
endmodule
