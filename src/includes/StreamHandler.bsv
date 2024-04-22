import FIFOF :: *;

import EthUtils :: *;
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
    DataStreamFifoOut dataStreamIn,
    FifoOut#(dType) appendDataIn
)(DataStreamFifoOut)
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

    return convertFifoToFifoOut(outputBuf);

endmodule


module mkAppendDataStreamTail#(
    IsSwapEndian swapDataStream,
    IsSwapEndian swapAppendData,
    DataStreamFifoOut dataStreamIn,
    FifoOut#(dType) appendDataIn,
    FifoOut#(Bit#(streamLenWidth)) streamLengthIn
)(DataStreamFifoOut)
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
    return convertFifoToFifoOut(dataStreamOutBuf);
endmodule


interface ExtractDataStream#(type dType);
    interface FifoOut#(dType) extractDataOut;
    interface DataStreamFifoOut dataStreamOut;
endinterface

typedef enum{
    EXTRACT, PASS, CLEAN
} ExtractState deriving(Bits, Eq, FShow);

module mkExtractDataStreamHead#(
    DataStreamFifoOut dataStreamIn
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

    interface FifoOut extractDataOut = convertFifoToFifoOut(extractDataBuf);
    interface FifoOut dataStreamOut = convertFifoToFifoOut(dataStreamBuf);
endmodule

// ToDo: 
// module mkExtractDataStreamTail#(
//     DataStreamFifoOut dataStreamIn,
//     FifoOut#(Bit#(streamLenWidth)) streamLengthIn
// )(ExtractDataStream#(dType)) provisos(
//     NumAlias#(TLog#(DATA_BUS_BYTE_WIDTH), frameLenWidth),
//     Bits#(dType, dWidth),
//     Add#(dWidth, rWidth, DATA_BUS_WIDTH),
//     Mul#(dByteWidth, BYTE_WIDTH, dWidth),
//     Add#(dByteWidth, rByteWidth, DATA_BUS_BYTE_WIDTH),
//     Add#(frameLenWidth, , streamLenWidth)
// );

// endmodule


module mkDoubleAxiStreamFifoOut#(
    AxiStream256FifoOut axiStreamIn
)(AxiStream512FifoOut);
    Reg#(Bit#(AXIS256_TDATA_WIDTH)) dataBuf <- mkRegU;
    Reg#(Bit#(AXIS256_TKEEP_WIDTH)) keepBuf <- mkRegU;
    Reg#(Bool) bufValid <- mkReg(False);

    FIFOF#(AxiStream512) axiStreamOutBuf <- mkFIFOF;

    rule doStreamExtension;
        let axiStream = axiStreamIn.first;
        axiStreamIn.deq;
        if (bufValid) begin
            AxiStream512 axiStreamExt = AxiStream {
                tData: {axiStream.tData, dataBuf},
                tKeep: {axiStream.tKeep, keepBuf},
                tUser: 0,
                tLast: axiStream.tLast
            };
            axiStreamOutBuf.enq(axiStreamExt);
            bufValid <= False;
        end
        else begin
            if (axiStream.tLast) begin
                AxiStream512 axiStreamExt = AxiStream {
                    tData: zeroExtend(axiStream.tData),
                    tKeep: zeroExtend(axiStream.tKeep),
                    tUser: 0,
                    tLast: True
                };
                axiStreamOutBuf.enq(axiStreamExt);
            end
            else begin
                dataBuf <= axiStream.tData;
                keepBuf <= axiStream.tKeep;
                bufValid <= True;
            end
        end
    endrule

    return convertFifoToFifoOut(axiStreamOutBuf);
endmodule

module mkDoubleAxiStreamFifoIn#(
    AxiStream256FifoIn axiStreamOut
)(AxiStream512FifoIn);
    Reg#(Maybe#(AxiStream256)) axiStreamInterBuf <- mkReg(Invalid);

    FIFOF#(AxiStream512) axiStreamInBuf <- mkFIFOF;

    rule doStreamReduction;
        if (axiStreamInterBuf matches tagged Valid .axiStream) begin
            axiStreamOut.enq(axiStream);
            axiStreamInterBuf <= tagged Invalid;
        end
        else begin
            let axiStream = axiStreamInBuf.first;
            axiStreamInBuf.deq;

            AxiStream256 axiStreamMSB = AxiStream {
                tData: truncateLSB(axiStream.tData),
                tKeep: truncateLSB(axiStream.tKeep),
                tUser: axiStream.tUser,
                tLast: axiStream.tLast
            };

            AxiStream256 axiStreamLSB = AxiStream {
                tData: truncate(axiStream.tData),
                tKeep: truncate(axiStream.tKeep),
                tUser: axiStream.tUser,
                tLast: False
            };

            if (axiStreamMSB.tKeep == 0) begin
                axiStreamLSB.tLast = True;
            end
            else begin
                axiStreamInterBuf <= tagged Valid axiStreamMSB;
            end
            axiStreamOut.enq(axiStreamLSB);
        end
    endrule

    return convertFifoToFifoIn(axiStreamInBuf);
endmodule

function AxiStream512FifoOut mkDataStreamToAxiStream512(DataStreamFifoOut stream);
    return (
        interface AxiStream512FifoOut;
            method AxiStream512 first();
                return AxiStream256 {
                    tData: stream.first.data,
                    tKeep: stream.first.byteEn,
                    tUser: 0,
                    tLast: stream.first.isLast
                };
            endmethod
                 
            method Action deq();
                stream.deq;
            endmethod
           
            method Bool notEmpty();
                return stream.notEmpty;
            endmethod
        endinterface
    );
endfunction

module mkAxiStream512ToDataStream#(AxiStream512FifoOut axiStreamIn)(DataStreamFifoOut);
    Reg#(Bool) isFirstReg <- mkReg(True);

    FIFOF#(DataStream) dataStreamOutBuf <- mkFIFOF;

    rule doStreamReduction;
        let axiStream = axiStreamIn.first;
        axiStreamIn.deq;
        let dataStream = DataStream {
            data: axiStream.tData,
            byteEn: axiStream.tKeep,
            isFirst: isFirstReg,
            isLast: axiStream.tLast
        };
        dataStreamOutBuf.enq(dataStream);
        isFirstReg <= axiStream.tLast;
    endrule

    return convertFifoToFifoOut(dataStreamOutBuf);
endmodule
