import FIFOF :: *;
import Connectable :: *;

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
        let dataStream = dataStreamIn.first; 
        dataStreamIn.deq;
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
        DataStream dataStream = DataStream {
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

    rule doHeadExtraction if (state == EXTRACT);
        let dataStream = dataStreamIn.first; 
        dataStreamIn.deq;

        SepDataStream#(dWidth, dByteWidth) sepData = seperateDataStream(dataStream);
        residueBuf <= sepData.highData;
        residueByteEnBuf <= sepData.highByteEn;
        extractDataBuf.enq(unpack(swapEndian(sepData.lowData))); // change to little endian
        if (dataStream.isLast) begin
            if (sepData.highByteEn != 0) begin
                dataStreamBuf.enq(
                    DataStream {
                        data: zeroExtend(sepData.highData),
                        byteEn: zeroExtend(sepData.highByteEn),
                        isFirst: True,
                        isLast: True
                    }
                );
            end
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

        if (dataStreamIn.notEmpty && extractDataBuf.notFull) begin
            let newDataStream = dataStreamIn.first; 
            dataStreamIn.deq;

            SepDataStream#(dWidth, dByteWidth) sepData = seperateDataStream(newDataStream);
            residueBuf <= sepData.highData;
            residueByteEnBuf <= sepData.highByteEn;
            extractDataBuf.enq(unpack(swapEndian(sepData.lowData))); // change to little endian
            
            if (newDataStream.isLast) begin
                if (sepData.highByteEn != 0) begin
                    state <= CLEAN;
                end
                else begin
                    state <= EXTRACT;
                end
            end
            else begin
                state <= PASS;
            end
            isFirstReg <= True;
        end
        else begin
            state <= EXTRACT; 
        end
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
    FifoOut#(AxiStream#(tKeepW, tUserW)) axiStreamIn
)(FifoOut#(AxiStream#(tKeepW2, tUserW))) provisos(
    Add#(tKeepW, tKeepW, tKeepW2),
    Add#(TMul#(tKeepW, 8), TMul#(tKeepW, 8), TMul#(tKeepW2, 8)),
    NumAlias#(tDataW, TMul#(tKeepW, 8))
);
    Reg#(Bit#(tDataW)) dataBuf <- mkRegU;
    Reg#(Bit#(tKeepW)) keepBuf <- mkRegU;
    Reg#(Bool) bufValid <- mkReg(False);

    FIFOF#(AxiStream#(tKeepW2, tUserW)) axiStreamExtOutBuf <- mkFIFOF;

    rule doStreamExtension;
        let axiStream = axiStreamIn.first;
        axiStreamIn.deq;
        if (bufValid) begin
            AxiStream#(tKeepW2, tUser) axiStreamExt = AxiStream {
                tData: {axiStream.tData, dataBuf},
                tKeep: {axiStream.tKeep, keepBuf},
                tUser: 0,
                tLast: axiStream.tLast
            };
            axiStreamExtOutBuf.enq(axiStreamExt);
            bufValid <= False;
        end
        else begin
            if (axiStream.tLast) begin
                AxiStream#(tKeepW2, tUser) axiStreamExt = AxiStream {
                    tData: zeroExtend(axiStream.tData),
                    tKeep: zeroExtend(axiStream.tKeep),
                    tUser: 0,
                    tLast: True
                };
                axiStreamExtOutBuf.enq(axiStreamExt);
            end
            else begin
                dataBuf <= axiStream.tData;
                keepBuf <= axiStream.tKeep;
                bufValid <= True;
            end
        end
    endrule

    return convertFifoToFifoOut(axiStreamExtOutBuf);
endmodule


module mkHalfAxiStreamFifoOut#(
    FifoOut#(AxiStream#(tKeepW2, tUserW)) axiStreamIn
)(FifoOut#(AxiStream#(tKeepW, tUserW))) provisos(
    Add#(tKeepW, tKeepW, tKeepW2),
    Add#(TMul#(tKeepW, 8), TMul#(tKeepW, 8), TMul#(tKeepW2, 8))
);
    Reg#(Maybe#(AxiStream#(tKeepW, tUserW))) axiStreamInterBuf <- mkReg(Invalid);
    FIFOF#(AxiStream#(tKeepW, tUserW)) axiStreamOutBuf <- mkFIFOF;

    rule doStreamReduction;
        if (axiStreamInterBuf matches tagged Valid .axiStream) begin
            axiStreamOutBuf.enq(axiStream);
            axiStreamInterBuf <= tagged Invalid;
        end
        else begin
            let axiStream = axiStreamIn.first;
            axiStreamIn.deq;

            AxiStream#(tKeepW, tUserW) axiStreamMSB = AxiStream {
                tData: truncateLSB(axiStream.tData),
                tKeep: truncateLSB(axiStream.tKeep),
                tUser: axiStream.tUser,
                tLast: axiStream.tLast
            };

            AxiStream#(tKeepW, tUserW) axiStreamLSB = AxiStream {
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
            axiStreamOutBuf.enq(axiStreamLSB);
        end
    endrule

    return convertFifoToFifoOut(axiStreamOutBuf);
endmodule


module mkDoubleDataStreamFifoOut#(
    DataStreamFifoOut dataStreamIn
)(DoubleDataStreamFifoOut);

    Reg#(Maybe#(DataStream)) dataStreamBuf <- mkReg(tagged Invalid);
    FIFOF#(DoubleDataStream) doubleDataStreamOutBuf <- mkFIFOF;

    rule doStreamExtension;
        if (isValid(dataStreamBuf)) begin
            let dataStream = dataStreamIn.first;
            dataStreamIn.deq;

            let preDataStream = fromMaybe(?, dataStreamBuf);

            let doubleDataStream = DoubleDataStream {
                data: {dataStream.data, preDataStream.data},
                byteEn: {dataStream.byteEn, preDataStream.byteEn},
                isFirst: preDataStream.isFirst,
                isLast: dataStream.isLast
            };
            doubleDataStreamOutBuf.enq(doubleDataStream);
            dataStreamBuf <= tagged Invalid;
        end
        else begin
            let dataStream = dataStreamIn.first;
            dataStreamIn.deq;
            if (dataStream.isLast) begin
                let doubleDataStream = DoubleDataStream {
                    data: zeroExtend(dataStream.data),
                    byteEn: zeroExtend(dataStream.byteEn),
                    isFirst: dataStream.isFirst,
                    isLast: dataStream.isLast
                };
                doubleDataStreamOutBuf.enq(doubleDataStream);
            end
            else begin
                dataStreamBuf <= tagged Valid dataStream;
            end
        end
    endrule

    return convertFifoToFifoOut(doubleDataStreamOutBuf);
endmodule

module mkHalfDataStreamFifoOut#(
    DoubleDataStreamFifoOut doubleDataStreamIn
)(DataStreamFifoOut);
    Reg#(Maybe#(DataStream)) extraDataStreamBuf <- mkReg(Invalid);

    FIFOF#(DataStream) dataStreamOutBuf <- mkFIFOF;

    rule doStreamReduction;
        if (extraDataStreamBuf matches tagged Valid .dataStream) begin
            dataStreamOutBuf.enq(dataStream);
            extraDataStreamBuf <= tagged Invalid;
        end
        else begin
            let doubleDataStream = doubleDataStreamIn.first;
            doubleDataStreamIn.deq;

            let extraDataStream = DataStream {
                data: truncateLSB(doubleDataStream.data),
                byteEn: truncateLSB(doubleDataStream.byteEn),
                isFirst: False,
                isLast: doubleDataStream.isLast
            };

            let dataStreamOut = DataStream {
                data: truncate(doubleDataStream.data),
                byteEn: truncate(doubleDataStream.byteEn),
                isFirst: doubleDataStream.isFirst,
                isLast: False
            };

            if (extraDataStream.byteEn == 0) begin
                dataStreamOut.isLast = True;
            end
            else begin
                extraDataStreamBuf <= tagged Valid extraDataStream;
            end
            dataStreamOutBuf.enq(dataStreamOut);
        end
    endrule

    return convertFifoToFifoOut(dataStreamOutBuf);
endmodule


typeclass AxiStream512Conversion#(numeric type keepW, numeric type userW);
    module mkAxiStream512FifoOut#(
        FifoOut#(AxiStream#(keepW, userW)) streamIn
    )(AxiStream512FifoOut);

    module mkAxiStream512FifoIn#(
        FifoIn#(AxiStream#(keepW, userW)) streamOut
    )(AxiStream512FifoIn);
endtypeclass

instance AxiStream512Conversion#(AXIS256_TKEEP_WIDTH, AXIS_TUSER_WIDTH);
    module mkAxiStream512FifoOut#(
        FifoOut#(AxiStream#(AXIS256_TKEEP_WIDTH, AXIS_TUSER_WIDTH)) axiStreamIn
    )(AxiStream512FifoOut);
        let axiStreamOut <- mkDoubleAxiStreamFifoOut(axiStreamIn);
        return axiStreamOut;
    endmodule

    module mkAxiStream512FifoIn#(
        FifoIn#(AxiStream#(AXIS256_TKEEP_WIDTH, AXIS_TUSER_WIDTH)) axiStreamOut
    )(AxiStream512FifoIn);
        FIFOF#(AxiStream512) axiStreamInBuf <- mkFIFOF;
        let halfAxiStreamFifoOut <- mkHalfAxiStreamFifoOut(
            convertFifoToFifoOut(axiStreamInBuf)
        );
        mkConnection(halfAxiStreamFifoOut, axiStreamOut);
        return convertFifoToFifoIn(axiStreamInBuf);
    endmodule
endinstance

instance AxiStream512Conversion#(AXIS512_TKEEP_WIDTH, AXIS_TUSER_WIDTH);
    module mkAxiStream512FifoOut#(
        FifoOut#(AxiStream#(AXIS512_TKEEP_WIDTH, AXIS_TUSER_WIDTH)) axiStream
    )(AxiStream512FifoOut);
        return axiStream;
    endmodule

    module mkAxiStream512FifoIn#(
        FifoIn#(AxiStream#(AXIS512_TKEEP_WIDTH, AXIS_TUSER_WIDTH)) axiStream
    )(AxiStream512FifoIn);
        return axiStream;
    endmodule
endinstance

instance AxiStream512Conversion#(AXIS1024_TKEEP_WIDTH, AXIS_TUSER_WIDTH);
    module mkAxiStream512FifoOut#(
        FifoOut#(AxiStream#(AXIS1024_TKEEP_WIDTH, AXIS_TUSER_WIDTH)) axiStreamIn
    )(AxiStream512FifoOut);
        let axiStreamOut <- mkHalfAxiStreamFifoOut(axiStreamIn);
        return axiStreamOut;
    endmodule

    module mkAxiStream512FifoIn#(
        FifoIn#(AxiStream#(AXIS1024_TKEEP_WIDTH, AXIS_TUSER_WIDTH)) axiStreamOut
    )(AxiStream512FifoIn);
        FIFOF#(AxiStream512) axiStreamInBuf <- mkFIFOF;
        let doubleAxiStreamFifoOut <- mkDoubleAxiStreamFifoOut(
            convertFifoToFifoOut(axiStreamInBuf)
        );
        mkConnection(doubleAxiStreamFifoOut, axiStreamOut);
        return convertFifoToFifoIn(axiStreamInBuf);
    endmodule
endinstance

interface ForkAxiStreamByHead#(numeric type tKeepW, numeric type tUserW);
    interface FifoOut#(AxiStream#(tKeepW, tUserW)) trueAxiStreamOut;
    interface FifoOut#(AxiStream#(tKeepW, tUserW)) falseAxiStreamOut;
endinterface

module mkForkAxiStreamByHead#(
    FifoOut#(AxiStream#(tKeepW, tUserW)) axiStreamIn,
    function Bool checkStreamHead(AxiStream#(tKeepW, tUserW) axiStream)
)(ForkAxiStreamByHead#(tKeepW, tUserW));
    FIFOF#(AxiStream#(tKeepW, tUserW)) trueAxiStreamOutBuf <- mkFIFOF;
    FIFOF#(AxiStream#(tKeepW, tUserW)) falseAxiStreamOutBuf <- mkFIFOF;

    Reg#(Bool) isFirstReg <- mkReg(True);
    Reg#(Bool) checkResultReg <- mkReg(False);

    rule checkStream if (isFirstReg);
        let axiStream = axiStreamIn.first;
        axiStreamIn.deq;
        Bool checkResult = checkStreamHead(axiStream);
        if (checkResult) begin
            trueAxiStreamOutBuf.enq(axiStream);
        end
        else begin
            falseAxiStreamOutBuf.enq(axiStream);
        end
        checkResultReg <= checkResult;
        isFirstReg <= axiStream.tLast;
    endrule

    rule forkAxiStream if (!isFirstReg);
        let axiStream = axiStreamIn.first;
        axiStreamIn.deq;
        if (checkResultReg) begin
            trueAxiStreamOutBuf.enq(axiStream);
        end
        else begin
            falseAxiStreamOutBuf.enq(axiStream);
        end
        isFirstReg <= axiStream.tLast;
    endrule

    interface FifoOut trueAxiStreamOut = convertFifoToFifoOut(trueAxiStreamOutBuf);
    interface FifoOut falseAxiStreamOut = convertFifoToFifoOut(falseAxiStreamOutBuf);
endmodule