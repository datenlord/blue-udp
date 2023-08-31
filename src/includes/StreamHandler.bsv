import FIFOF :: *;

import Utils :: *;
import Ports :: *;

import SemiFifo :: *;
import AxiStreamTypes :: *;

typedef enum {
    SWAP, HOLD
} IsSwapEndian deriving(Eq);

typedef enum {
    INSERT, PASS, CLEAN
} AppendState deriving(Bits, Eq, FShow);
// Insert dType into the head of DataStream
module mkAppendDataStreamHead#(
    IsSwapEndian swapDataStream,
    IsSwapEndian swapAppendData,
    DataStreamPipeOut dataStreamIn,
    PipeOut#(dType) appendDataIn
)(DataStreamPipeOut)
provisos(
    Bits#(dType, dWidth), 
    Add#(dWidth, rWidth, DATA_BUS_WIDTH),
    Mul#(dByteWidth, BYTE_WIDTH, dWidth), 
    Add#(dByteWidth, rByteWidth, DATA_BUS_BYTE_WIDTH)
);
    
    FIFOF#(DataStream) outputBuf <- mkFIFOF;
    Reg#(AppendState) state <- mkReg(INSERT);
    Reg#(Bit#(dWidth)) residueBuf <- mkRegU;
    Reg#(Bit#(dByteWidth)) residueByteEnBuf <- mkRegU;

    rule doInsertion if (state == INSERT);
        let dataStream = dataStreamIn.first;
        if (swapDataStream == SWAP) begin
            dataStream.data = swapEndian(dataStreamIn.first.data);
            dataStream.byteEn = reverseBits(dataStreamIn.first.byteEn);
        end
        dataStreamIn.deq;
        
        SepDataStream#(rWidth, rByteWidth) sepData = seperateDataStream(dataStream);

        Bit#(dWidth) additionData;
        if (swapAppendData == SWAP) begin
            additionData = swapEndian(pack(appendDataIn.first));
        end
        else begin
            additionData = pack(appendDataIn.first);
        end
        appendDataIn.deq;
 
        dataStream.data = {sepData.lowData, additionData};
        dataStream.byteEn = {sepData.lowByteEn, setAllBits};
        residueBuf <= sepData.highData;
        residueByteEnBuf <= sepData.highByteEn;
        if (dataStream.isLast) begin
            if (sepData.highByteEn != 0) begin
                dataStream.isLast = False;
                state <= CLEAN;
            end
        end
        else begin
            state <= PASS;
        end
        outputBuf.enq(dataStream);
    endrule

    rule doPass if (state == PASS);
        let dataStream = dataStreamIn.first; dataStreamIn.deq;
        SepDataStream#(rWidth, rByteWidth) sepData = seperateDataStream(dataStream);
        
        dataStream.data = {sepData.lowData, residueBuf};
        dataStream.byteEn = {sepData.lowByteEn, residueByteEnBuf};
        residueBuf <= sepData.highData;
        residueByteEnBuf <= sepData.highByteEn;
        
        if (dataStream.isLast) begin
            if (sepData.highByteEn == 0 ) begin
                state <= INSERT;
            end
            else begin
                dataStream.isLast = False;
                state <= CLEAN;
            end
        end
        outputBuf.enq(dataStream);
    endrule

    rule doClean if (state == CLEAN);
        DataStream dataStream = DataStream{
            isFirst: False,
            isLast: True,
            data: zeroExtend(residueBuf),
            byteEn: zeroExtend(residueByteEnBuf)
        };
        outputBuf.enq(dataStream);
        state <= INSERT;
    endrule

    return convertFifoToPipeOut(outputBuf);

endmodule


module mkAppendDataStreamTail#(
    IsSwapEndian swapDataStream,
    IsSwapEndian swapAppendData,
    DataStreamPipeOut dataStreamIn,
    PipeOut#(dType) appendDataIn,
    PipeOut#(Bit#(streamLenWidth)) streamLengthIn
)(DataStreamPipeOut)
provisos(
    NumAlias#(TLog#(DATA_BUS_BYTE_WIDTH), frameLenWidth),

    Bits#(dType, dWidth),
    Add#(dWidth, rWidth, DATA_BUS_WIDTH),
    Mul#(dByteWidth, BYTE_WIDTH, dWidth),
    Add#(dByteWidth, rByteWidth, DATA_BUS_BYTE_WIDTH),
    Mul#(BYTE_WIDTH, a__, TAdd#(dWidth, DATA_BUS_WIDTH)),
    Add#(frameLenWidth, b__, streamLenWidth)
);
    FIFOF#(DataStream) dataStreamOutBuf <- mkFIFOF;
    Reg#(Bit#(dWidth)) residueDataBuf <- mkRegU;
    Reg#(Bit#(dByteWidth)) residueByteEnBuf <- mkRegU;
    Reg#(AppendState) state <- mkReg(PASS);

    rule doPass if (state == PASS);
        let dataStream = dataStreamIn.first;
        dataStreamIn.deq;

        if (swapDataStream == SWAP) begin
            dataStream.data = swapEndian(dataStream.data);
            dataStream.byteEn = reverseBits(dataStream.byteEn);
        end

        if (dataStream.isLast) begin
            Bit#(dWidth) appendData = pack(appendDataIn.first);
            appendDataIn.deq;
            if (swapAppendData == SWAP) begin
                appendData = swapEndian(appendData);
            end
            let streamLength = streamLengthIn.first;
            streamLengthIn.deq;
            Bit#(frameLenWidth) lastFrameLength = truncate(streamLength);
            
            Bit#(TAdd#(dWidth, DATA_BUS_WIDTH)) tempData = extend(appendData);
            Bit#(TAdd#(dByteWidth, DATA_BUS_BYTE_WIDTH)) tempByteEn = ((1 << valueOf(dByteWidth)) - 1);
            Bit#(TAdd#(frameLenWidth, 1)) shiftAmt = zeroExtend(lastFrameLength);
            if (shiftAmt == 0) begin
                shiftAmt = 1 << valueOf(frameLenWidth);
            end

            let shiftedTempData = byteLeftShift(tempData, shiftAmt);
            let shiftedTempByteEn = tempByteEn << shiftAmt;
            Bit#(dWidth) residueData = truncateLSB(shiftedTempData);
            Bit#(dByteWidth) residueByteEn = truncateLSB(shiftedTempByteEn);

            let originByteEn = dataStream.byteEn;
            let originData = bitMask(dataStream.data, originByteEn);
            dataStream.data = truncate(shiftedTempData) | originData;
            dataStream.byteEn = truncate(shiftedTempByteEn) | originByteEn;
            dataStream.isLast = residueByteEn == 0;

            residueDataBuf <= residueData;
            residueByteEnBuf <= residueByteEn;

            if (!dataStream.isLast) state <= CLEAN;
        end
        dataStreamOutBuf.enq(dataStream);
    endrule

    rule doClean if (state == CLEAN);
        DataStream dataStream = DataStream {
            data: zeroExtend(residueDataBuf),
            byteEn: zeroExtend(residueByteEnBuf),
            isFirst: False,
            isLast: True
        };
        dataStreamOutBuf.enq(dataStream);
        state <= PASS;
    endrule
    return convertFifoToPipeOut(dataStreamOutBuf);
endmodule


interface ExtractDataStream#(type dType);
    interface PipeOut#(dType) extractDataOut;
    interface DataStreamPipeOut dataStreamOut;
endinterface

typedef enum{
    EXTRACT, PASS, CLEAN
} ExtractState deriving(Bits, Eq, FShow);

module mkExtractDataStreamHead#(
    DataStreamPipeOut dataStreamIn
)(ExtractDataStream#(dType)) provisos(
    Bits#(dType, dWidth),
    Add#(dWidth, rWidth, DATA_BUS_WIDTH),
    Mul#(dByteWidth, BYTE_WIDTH, dWidth),
    Add#(dByteWidth, rByteWidth, DATA_BUS_BYTE_WIDTH)
);

    FIFOF#(dType) extractDataBuf <- mkFIFOF;
    FIFOF#(DataStream) dataStreamBuf <- mkFIFOF;
    Reg#(ExtractState) state <- mkReg(EXTRACT);
    Reg#(Bool) isFirstReg <- mkReg(False);
    Reg#(Bit#(rWidth)) residueBuf <- mkRegU;
    Reg#(Bit#(rByteWidth)) residueByteEnBuf <- mkRegU;

    rule doExtraction if (state == EXTRACT);
        let dataStream = dataStreamIn.first; 
        dataStreamIn.deq;

        SepDataStream#(dWidth, dByteWidth) sepData = seperateDataStream(dataStream);
        residueBuf <= sepData.highData;
        residueByteEnBuf <= sepData.highByteEn;
        extractDataBuf.enq(unpack(swapEndian(sepData.lowData))); // change to little endian
        if (dataStream.isLast) begin
            if (sepData.highByteEn != 0) state <= CLEAN;
        end
        else begin
            state <= PASS;
        end
        isFirstReg <= True;
    endrule

    rule doPass if (state == PASS);
        let dataStream = dataStreamIn.first; 
        dataStreamIn.deq;

        SepDataStream#(dWidth, dByteWidth) sepData = seperateDataStream(dataStream);
        dataStream.data = {sepData.lowData, residueBuf};
        dataStream.byteEn = {sepData.lowByteEn, residueByteEnBuf};
        dataStream.isFirst = isFirstReg;
        residueBuf <= sepData.highData;
        residueByteEnBuf <= sepData.highByteEn;

        if (dataStream.isLast) begin
            if (sepData.highByteEn != 0) begin
                state <= CLEAN;
                dataStream.isLast = False;
            end
            else begin
                state <= EXTRACT;
            end
        end

        dataStreamBuf.enq(dataStream);
        isFirstReg <= False;
    endrule

    rule doClean if (state == CLEAN);
        DataStream dataStream = DataStream{
            isFirst: isFirstReg,
            isLast: True,
            data: zeroExtend(residueBuf),
            byteEn: zeroExtend(residueByteEnBuf)
        };
        dataStreamBuf.enq(dataStream);
        state <= EXTRACT;
    endrule

    interface PipeOut extractDataOut = convertFifoToPipeOut(extractDataBuf);
    interface PipeOut dataStreamOut = convertFifoToPipeOut(dataStreamBuf);
endmodule

// ToDo: 
// module mkExtractDataStreamTail#(
//     DataStreamPipeOut dataStreamIn,
//     PipeOut#(Bit#(streamLenWidth)) streamLengthIn
// )(ExtractDataStream#(dType)) provisos(
//     NumAlias#(TLog#(DATA_BUS_BYTE_WIDTH), frameLenWidth),
//     Bits#(dType, dWidth),
//     Add#(dWidth, rWidth, DATA_BUS_WIDTH),
//     Mul#(dByteWidth, BYTE_WIDTH, dWidth),
//     Add#(dByteWidth, rByteWidth, DATA_BUS_BYTE_WIDTH),
//     Add#(frameLenWidth, , streamLenWidth)
// );

// endmodule


module mkDataStreamToAxiStream512#(DataStreamPipeOut dataStreamIn)(AxiStream512PipeOut);
    Reg#(Data) dataBuf <- mkRegU;
    Reg#(ByteEn) byteEnBuf <- mkRegU;
    Reg#(Bool) bufValid <- mkReg(False);

    FIFOF#(AxiStream512) axiStreamOutBuf <- mkFIFOF;

    rule doStreamExtension;
        if (bufValid) begin
            let dataStream = dataStreamIn.first;
            dataStreamIn.deq;
            AxiStream512 axiStream = AxiStream {
                tData: { dataStream.data, dataBuf },
                tKeep: { dataStream.byteEn, byteEnBuf },
                tUser: 0,
                tLast: dataStream.isLast
            };
            axiStreamOutBuf.enq(axiStream);
            bufValid <= False;
        end
        else begin
            let dataStream = dataStreamIn.first;
            dataStreamIn.deq;
            if (dataStream.isLast) begin
                AxiStream512 axiStream = AxiStream {
                    tData: zeroExtend(dataStream.data),
                    tKeep: zeroExtend(dataStream.byteEn),
                    tUser: 0,
                    tLast: True
                };
                axiStreamOutBuf.enq(axiStream);
            end
            else begin
                dataBuf <= dataStream.data;
                byteEnBuf <= dataStream.byteEn;
                bufValid <= True;
            end
        end
    endrule

    return convertFifoToPipeOut(axiStreamOutBuf);
endmodule

module mkAxiStream512ToDataStream#(AxiStream512PipeOut axiStreamIn)(DataStreamPipeOut);
    Reg#(Bool) isFirstReg <- mkReg(True);
    Reg#(Maybe#(DataStream)) extraDataStreamBuf <- mkReg(Invalid);

    FIFOF#(DataStream) dataStreamOutBuf <- mkFIFOF;

    rule doStreamReduction;
        if (extraDataStreamBuf matches tagged Valid .dataStream) begin
            dataStreamOutBuf.enq(dataStream);
            extraDataStreamBuf <= tagged Invalid;
        end
        else begin
            let axiStream = axiStreamIn.first;
            axiStreamIn.deq;

            let extraDataStream = DataStream{
                data: truncateLSB(axiStream.tData),
                byteEn: truncateLSB(axiStream.tKeep),
                isFirst: False,
                isLast: axiStream.tLast
            };

            let dataStreamOut = DataStream{
                data: truncate(axiStream.tData),
                byteEn: truncate(axiStream.tKeep),
                isFirst: isFirstReg,
                isLast: False
            };

            if (extraDataStream.byteEn == 0) begin
                dataStreamOut.isLast = True;
            end
            else begin
                extraDataStreamBuf <= tagged Valid extraDataStream;
            end
            dataStreamOutBuf.enq(dataStreamOut);
            isFirstReg <= axiStream.tLast;
        end
    endrule

    return convertFifoToPipeOut(dataStreamOutBuf);

endmodule