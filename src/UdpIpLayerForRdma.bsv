import FIFOF :: *;

import Ports :: *;
import Utils :: *;
import UdpIpLayer :: *;
import EthernetTypes :: *;

import SemiFifo :: *;
import CrcDefines :: *;
import AxiStreamTypes :: *;

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


module mkUdpIpStreamForICrcGen#(
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

    DataStreamPipeOut udpIpStream <- mkAppendDataStreamHead(
        HOLD,
        SWAP,
        convertFifoToPipeOut(dataStreamBuf),
        convertFifoToPipeOut(udpIpHeaderBuf)
    );
    DataStreamPipeOut dummyBitsAndUdpIpStream <- mkAppendDataStreamHead(
        HOLD,
        SWAP,
        udpIpStream,
        convertFifoToPipeOut(dummyBitsBuf)
    );
    return dummyBitsAndUdpIpStream;
endmodule


module mkUdpIpStreamForRdma#(
    UdpIpMetaDataPipeOut udpIpMetaDataIn,
    DataStreamPipeOut dataStreamIn,
    UdpConfig udpConfig
)(DataStreamPipeOut);

    FIFOF#(DataStream) dataStreamBuf <- mkFIFOF;
    FIFOF#(DataStream) dataStreamCrcBuf <- mkFIFOF;
    FIFOF#(UdpIpMetaData) udpIpMetaDataBuf <- mkFIFOF;
    FIFOF#(UdpIpMetaData) udpIpMetaDataCrcBuf <- mkFIFOF;
    FIFOF#(UdpLength) preComputeLengthBuf <- mkFIFOF;

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

    DataStreamPipeOut udpIpStream <- mkUdpIpStream(
        genUdpIpHeaderForRoCE,
        convertFifoToPipeOut(udpIpMetaDataBuf),
        convertFifoToPipeOut(dataStreamBuf),
        udpConfig
    );

    DataStreamPipeOut udpIpStreamForICrc <- mkUdpIpStreamForICrcGen(
        convertFifoToPipeOut(udpIpMetaDataCrcBuf),
        convertFifoToPipeOut(dataStreamCrcBuf),
        udpConfig
    );

    let crc32Stream <- mkCrc32AxiStream256PipeOut(
        CRC_MODE_SEND,
        convertDataStreamToAxiStream256(udpIpStreamForICrc)
    );

    DataStreamPipeOut udpIpStreamWithICrc <- mkAppendDataStreamTail(
        HOLD,
        HOLD,
        udpIpStream,
        crc32Stream,
        convertFifoToPipeOut(preComputeLengthBuf)
    );

    return udpIpStreamWithICrc;
endmodule


typedef 4096 RDMA_PACKET_SIZE;
typedef    2 RDMA_PACKET_NUM;
typedef TMul#(RDMA_PACKET_SIZE, RDMA_PACKET_NUM) RDMA_BUF_SIZE;
typedef TDiv#(RDMA_BUF_SIZE, DATA_BUS_BYTE_WIDTH) RDMA_BUF_DEPTH;

typedef enum {
    ICRC_IDLE,
    ICRC_PASS,
    ICRC_FAIL
} ICrcCheckState deriving(Bits, Eq, FShow);

function UdpIpMetaData extractUdpIpMetaDataForRoCE(UdpIpHeader hdr);
    let meta = extractUdpIpMetaData(hdr);
    meta.dataLen = meta.dataLen - fromInteger(valueOf(CRC32_BYTE_WIDTH));
    return meta;
endfunction

module mkUdpIpStreamForICrcCheck#(
    DataStreamPipeOut udpIpStreamIn
)(DataStreamPipeOut);
    Reg#(Bool) isFirst <- mkReg(True);
    FIFOF#(AxiStream512) interAxiStreamBuf <- mkFIFOF;
    FIFOF#(Bit#(DUMMY_BITS_WIDTH)) dummyBitsBuf <- mkFIFOF;
    let axiStream512PipeOut <- mkDataStreamToAxiStream512(udpIpStreamIn);
    let udpIpStreamPipeOut <- mkAxiStream512ToDataStream(
        convertFifoToPipeOut(interAxiStreamBuf)
    );
    let dummyBitsAndUdpIpStream <- mkAppendDataStreamHead(
        HOLD,
        SWAP,
        udpIpStreamPipeOut,
        convertFifoToPipeOut(dummyBitsBuf)
    );

    rule genDummyBits;
        dummyBitsBuf.enq(setAllBits);
    endrule

    rule doTransform;
        let axiStream512 = axiStream512PipeOut.first;
        axiStream512PipeOut.deq;
        if (isFirst) begin
            let tData = swapEndian(axiStream512.tData);
            BTHUdpIpHeader bthUdpIpHdr = unpack(truncateLSB(tData));
            bthUdpIpHdr.bth.fecn = setAllBits;
            bthUdpIpHdr.bth.becn = setAllBits;
            bthUdpIpHdr.bth.resv6 = setAllBits;
            bthUdpIpHdr.udpHeader.checksum = setAllBits;
            bthUdpIpHdr.ipHeader.ipDS = setAllBits;
            bthUdpIpHdr.ipHeader.ipTTL = setAllBits;
            bthUdpIpHdr.ipHeader.ipChecksum = setAllBits;
            tData = {pack(bthUdpIpHdr), truncate(tData)};
            axiStream512.tData = swapEndian(tData);
        end
        isFirst <= axiStream512.tLast;
        interAxiStreamBuf.enq(axiStream512);
    endrule

    return dummyBitsAndUdpIpStream;
endmodule


module mkRemoveICrcFromDataStream#(
    PipeOut#(Bit#(streamLenWidth)) streamLenIn,
    DataStreamPipeOut dataStreamIn
)(DataStreamPipeOut) provisos(
    NumAlias#(TLog#(DATA_BUS_BYTE_WIDTH), frameLenWidth),
    NumAlias#(TLog#(TAdd#(CRC32_BYTE_WIDTH, 1)), shiftAmtWidth),
    Add#(frameLenWidth, frameNumWidth, streamLenWidth)
);
    Integer crc32ByteWidth = valueOf(CRC32_BYTE_WIDTH);
    
    Reg#(Bool) isGetStreamLen <- mkReg(False);
    Reg#(Bool) isGetLastFrame <- mkReg(False);
    Reg#(Bit#(frameNumWidth)) lastFrameIdx <- mkRegU;
    Reg#(Bit#(frameNumWidth)) frameCounter <- mkRegU;
    Reg#(Bit#(shiftAmtWidth)) frameShiftAmt <- mkRegU;

    FIFOF#(DataStream) dataStreamOutBuf <- mkFIFOF;

    rule getStreamLen if (!isGetStreamLen);
        let streamLen = streamLenIn.first;
        streamLenIn.deq;
        Bit#(frameLenWidth) lastFrameLen = truncate(streamLen);
        if (lastFrameLen == 0) begin
            lastFrameIdx <= truncateLSB(streamLen) - 1;
            frameShiftAmt <= fromInteger(crc32ByteWidth);
        end
        else if (lastFrameLen > fromInteger(crc32ByteWidth)) begin
            lastFrameIdx <= truncateLSB(streamLen);
            frameShiftAmt <= fromInteger(crc32ByteWidth);
            $display("Remove ICRC shiftAmt=%d", frameShiftAmt);
        end
        else begin
            lastFrameIdx <= truncateLSB(streamLen) - 1;
            frameShiftAmt <= truncate(fromInteger(crc32ByteWidth) - lastFrameLen);
        end
        isGetStreamLen <= True;
        isGetLastFrame <= False;
        frameCounter <= 0;
    endrule

    rule passDataStream if (isGetStreamLen);
        let dataStream = dataStreamIn.first;
        dataStreamIn.deq;

        if (dataStream.isLast) begin
            isGetStreamLen <= False;
        end

        if (frameCounter == lastFrameIdx) begin
            let byteEn = dataStream.byteEn >> frameShiftAmt;
            dataStream.byteEn = byteEn;
            dataStream.data = bitMask(dataStream.data, byteEn);
            dataStream.isLast = True;
            isGetLastFrame <= True;
        end

        if (!isGetLastFrame) begin
            frameCounter <= frameCounter + 1;
            dataStreamOutBuf.enq(dataStream);
        end
    endrule

    return convertFifoToPipeOut(dataStreamOutBuf);
endmodule

module mkUdpIpMetaDataAndDataStreamForRdma#(
    DataStreamPipeOut udpIpStreamIn,
    UdpConfig udpConfig
)(UdpIpMetaDataAndDataStream);

    FIFOF#(DataStream) udpIpStreamBuf <- mkFIFOF;
    FIFOF#(DataStream) udpIpStreamForICrcBuf <- mkFIFOF;

    rule forkUdpIpStream;
        let udpIpStream = udpIpStreamIn.first;
        udpIpStreamIn.deq;
        udpIpStreamBuf.enq(udpIpStream);
        udpIpStreamForICrcBuf.enq(udpIpStream);
    endrule

    DataStreamPipeOut udpIpStreamForICrc <- mkUdpIpStreamForICrcCheck(
        convertFifoToPipeOut(udpIpStreamForICrcBuf)
    );

    let crc32Stream <- mkCrc32AxiStream256PipeOut(
        CRC_MODE_RECV,
        convertDataStreamToAxiStream256(udpIpStreamForICrc)
    );

    UdpIpMetaDataAndDataStream udpIpMetaAndDataStream <- mkUdpIpMetaDataAndDataStream(
        extractUdpIpMetaDataForRoCE,
        convertFifoToPipeOut(udpIpStreamBuf),
        udpConfig
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

    let udpIpMetaDataBuffered <- mkSizedFifoToPipeOut(
        valueOf(RDMA_PACKET_NUM),
        convertFifoToPipeOut(udpIpMetaDataBuf)
    );

    DataStreamPipeOut dataStreamWithOutICrc <- mkRemoveICrcFromDataStream(
        convertFifoToPipeOut(dataStreamLengthBuf),
        udpIpMetaAndDataStream.dataStreamOut
    );

    DataStreamPipeOut dataStreamBuffered <- mkSizedBramFifoToPipeOut(
        valueOf(RDMA_BUF_DEPTH),
        dataStreamWithOutICrc
    );

    Reg#(ICrcCheckState) iCrcCheckState <- mkReg(ICRC_IDLE);
    FIFOF#(DataStream) dataStreamOutBuf <- mkFIFOF;
    FIFOF#(UdpIpMetaData) udpIpMetaDataOutBuf <- mkFIFOF;
    rule doCrcCheck;
        case(iCrcCheckState) matches
            ICRC_IDLE: begin
                let crcChecksum = crc32Stream.first;
                crc32Stream.deq;
                let udpIpMetaData = udpIpMetaDataBuffered.first;
                udpIpMetaDataBuffered.deq;
                let dataStream = dataStreamBuffered.first;
                dataStreamBuffered.deq;
                $display("RdmaUdpIpEthRx gets iCRC result");
                if (crcChecksum == 0) begin
                    udpIpMetaDataOutBuf.enq(udpIpMetaData);
                    dataStreamOutBuf.enq(dataStream);
                    iCrcCheckState <= ICRC_PASS;
                    $display("Pass ICRC check");
                end
                else begin
                    iCrcCheckState <= ICRC_FAIL;
                    $display("FAIL ICRC check");
                end
            end
            ICRC_PASS: begin
                let dataStream = dataStreamBuffered.first;
                dataStreamOutBuf.enq(dataStream);
                dataStreamBuffered.deq;
                if (dataStream.isLast) begin
                    iCrcCheckState <= ICRC_IDLE;
                end
            end
            ICRC_FAIL: begin
                let dataStream = dataStreamBuffered.first;
                dataStreamBuffered.deq;
                if (dataStream.isLast) begin
                    iCrcCheckState <= ICRC_IDLE;
                end
            end
        endcase
    endrule

    interface PipeOut udpIpMetaDataOut = convertFifoToPipeOut(udpIpMetaDataOutBuf);
    interface PipeOut dataStreamOut = convertFifoToPipeOut(dataStreamOutBuf);

endmodule
