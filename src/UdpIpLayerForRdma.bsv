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
    Integer preComputeLengthBufDepth = 4;

    FIFOF#(DataStream) dataStreamBuf <- mkFIFOF;
    FIFOF#(DataStream) dataStreamCrcBuf <- mkFIFOF;
    FIFOF#(UdpIpMetaData) udpIpMetaDataBuf <- mkFIFOF;
    FIFOF#(UdpIpMetaData) udpIpMetaDataCrcBuf <- mkFIFOF;
    FIFOF#(UdpLength) preComputeLengthBuf <- mkSizedFIFOF(preComputeLengthBufDepth);
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
    Reg#(Bool) isICrcCrossBeatReg <- mkRegU;
    Reg#(Bit#(shiftAmtWidth)) frameShiftAmtReg <- mkRegU;
    Reg#(DataStream) foreDataStreamReg <- mkRegU;

    FIFOF#(DataStream) dataStreamOutBuf <- mkFIFOF;

    rule getStreamLen if (!isGetStreamLenReg);
        let streamLen = streamLenIn.first;
        streamLenIn.deq;

        Bit#(frameLenWidth) lastFrameLen = truncate(streamLen);
        let isICrcIntraOneBeat = lastFrameLen > fromInteger(crc32ByteWidth) || lastFrameLen == 0;
        
        isICrcCrossBeatReg <= !isICrcIntraOneBeat;
        if (isICrcIntraOneBeat) begin
            frameShiftAmtReg <= fromInteger(crc32ByteWidth);
        end
        else begin
            frameShiftAmtReg <= truncate(fromInteger(crc32ByteWidth) - lastFrameLen);
        end

        if (dataStreamIn.notEmpty) begin
            let dataStream = dataStreamIn.first;
            if (!dataStream.isLast) begin
                dataStreamIn.deq;
                if (isICrcIntraOneBeat) begin
                    dataStreamOutBuf.enq(dataStream);
                end
                else begin
                    foreDataStreamReg <= dataStream;
                end
            end
        end

        isGetStreamLenReg <= True;
    endrule

    rule passDataStream if (isGetStreamLenReg);
        let dataStream = dataStreamIn.first;
        dataStreamIn.deq;
        
        if (!isICrcCrossBeatReg) begin
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
    Integer udpIpMetaDataBufSize = 8;

    FIFOF#(DataStream) udpIpStreamBuf <- mkFIFOF;
    FIFOF#(DataStream) udpIpStreamForICrcBuf <- mkFIFOF;

    FIFOF#(Bool) integrityCheckOutBuf <- mkSizedFIFOF(4);

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

    FIFOF#(UdpLength) dataStreamLengthBuf <- mkSizedFIFOF(udpIpMetaDataBufSize);
    FIFOF#(UdpIpMetaData) udpIpMetaDataBuf <- mkSizedFIFOF(udpIpMetaDataBufSize);
    rule forkUdpIpMetaData;
        Integer iCrcByteWidth = valueOf(CRC32_BYTE_WIDTH);
        let udpIpMetaData = udpIpMetaAndDataStream.udpIpMetaDataOut.first;
        udpIpMetaAndDataStream.udpIpMetaDataOut.deq;
        dataStreamLengthBuf.enq(udpIpMetaData.dataLen + fromInteger(iCrcByteWidth));
        udpIpMetaDataBuf.enq(udpIpMetaData);
    endrule

    FIFOF#(DataStream) dataStreamForCrcRemovalBuf <- mkFIFOF;
    rule passDataStreamForCrcRemoval;
        let dataStream = udpIpMetaAndDataStream.dataStreamOut.first;
        udpIpMetaAndDataStream.dataStreamOut.deq;
        dataStreamForCrcRemovalBuf.enq(dataStream);
    endrule

    DataStreamFifoOut dataStreamWithOutICrc <- mkRemoveICrcFromDataStream(
        convertFifoToFifoOut(dataStreamLengthBuf),
        convertFifoToFifoOut(dataStreamForCrcRemovalBuf)
    );

    DataStreamFifoOut dataStreamBuffered <- mkSizedBramFifoToFifoOut(
        valueOf(RDMA_PAYLOAD_BUF_SIZE),
        dataStreamWithOutICrc
    );

    Reg#(Maybe#(Bool)) isPassDataStreamReg <- mkReg(tagged Invalid);
    FIFOF#(DataStream) dataStreamOutBuf <- mkFIFOF;
    FIFOF#(UdpIpMetaData) udpIpMetaDataOutBuf <- mkFIFOF;

    rule getCrcResultAndPassMetaData if (!isValid(isPassDataStreamReg));
        let isPassUdpIpHdrChk = udpIpMetaAndDataStream.integrityCheckOut.first;
        udpIpMetaAndDataStream.integrityCheckOut.deq;

        let isPassICrcChk = crc32Stream.first == 0;
        crc32Stream.deq;

        if (!isPassICrcChk) begin
            $display("mkUdpIpMetaDataAndDataStreamForRdma: ICRC Check Fails");
        end
        else begin
            $display("mkUdpIpMetaDataAndDataStreamForRdma: ICRC Check Passes");
        end

        if (isPassUdpIpHdrChk) begin
        // if check of UdpIpHeader fails, mkUdpIpMetaDataAndDataStream throws metadata and datastream
            let udpIpMetaData = udpIpMetaDataBuf.first;
            udpIpMetaDataBuf.deq;

            if (isPassICrcChk) begin
                udpIpMetaDataOutBuf.enq(udpIpMetaData);
            end

            if (dataStreamBuffered.notEmpty()) begin
                let dataStream = dataStreamBuffered.first;
                dataStreamBuffered.deq;
                if (isPassICrcChk) begin
                    dataStreamOutBuf.enq(dataStream);
                end
                if (!dataStream.isLast) begin
                    isPassDataStreamReg <= tagged Valid isPassICrcChk;
                end
            end
            else begin
                isPassDataStreamReg <= tagged Valid isPassICrcChk;
            end
        end

        integrityCheckOutBuf.enq(isPassICrcChk && isPassUdpIpHdrChk);
    endrule

    rule passDataStream if (isValid(isPassDataStreamReg));
        let dataStream = dataStreamBuffered.first;
        dataStreamBuffered.deq;

        if (fromMaybe(?, isPassDataStreamReg)) begin
            dataStreamOutBuf.enq(dataStream);
        end

        if (dataStream.isLast) begin
            isPassDataStreamReg <= tagged Invalid;
        end
    endrule

    interface udpIpMetaDataOut = convertFifoToFifoOut(udpIpMetaDataOutBuf);
    interface dataStreamOut = convertFifoToFifoOut(dataStreamOutBuf);
    interface integrityCheckOut = convertFifoToFifoOut(integrityCheckOutBuf);
endmodule
