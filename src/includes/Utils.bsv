import Ports :: *;
import Vector :: *;
import FIFOF :: *;
import Connectable :: *;
import BRAMFIFO :: *;

import SemiFifo :: *;
import PrimUtils :: *;
import EthernetTypes :: *;

import CrcDefines :: *;
import CrcAxiStream :: *;
import AxiStreamTypes :: *;

function PipeOut#(anytype) muxPipeOut2(
    Bool sel, PipeOut#(anytype) pipeIn1, PipeOut#(anytype) pipeIn0
);
    PipeOut#(anytype) resultPipeOut = interface PipeOut;
        method anytype first;
            return sel ? pipeIn1.first : pipeIn0.first;
        endmethod

        method Bool notEmpty;
            return (sel && pipeIn1.notEmpty) || (!sel && pipeIn0.notEmpty);
        endmethod

        method Action deq;
            if (sel) begin pipeIn1.deq; end 
            else begin pipeIn0.deq; end
        endmethod
        
    endinterface;

    return resultPipeOut;

endfunction

function PipeOut#(type2) translatePipeOut(PipeOut#(type1) pipeIn, type2 payload);
    return (interface PipeOut;
                method type2 first;
                    return payload;
                endmethod
                method Bool notEmpty;
                    return pipeIn.notEmpty;
                endmethod
                method Action deq;
                    pipeIn.deq;
                endmethod
            endinterface);

endfunction

function PipeOut#(anyType) continuePipeOutWhen(PipeOut#(anyType) pipeIn, Bool cond);
    return (interface PipeOut;
                method anyType first if (cond);
                    return pipeIn.first;
                endmethod
                method Bool notEmpty;
                    return pipeIn.notEmpty && cond;
                endmethod
                method Action deq if (cond);
                    pipeIn.deq;
                endmethod
            endinterface);
endfunction

// typedef Server#(Vector#(num, Bit#(width)), Bit#(TAdd#(TLog#(num), width))) 
//     AdderTree#(numeric type num, numeric type width);
// typeclass PipeAdderTree#(numeric type num, numeric type width);
//     module mkPipeAdderTree(AdderTree#(num, width));
// endtypeclass

// instance PipeAdderTree#(1, numeric type width);
//     module mkPipeAdderTree#(AdderTree#(1, width));
//         FIFOF#(Bit#(width)) sumBuf <- mkPipelineFIFOF;
//         interface Put request;
//             method Action put(Vector#(1, Bit#(width)) inputVec);
//                 let sum = combAdderTree(inputVec);
//                 sumBuf.enq(sum);
//             endmethod
//         endinterface
//         interface response = toGet(sumBuf);
//     endmodule
// endinstance

// instance PipeAdderTree#(2, numeric type width);
//     module mkPipeAdderTree#(AdderTree#(2, width));
//         FIFOF#(Bit#(TAdd#(width, 1))) sumBuf <- mkPipelineFIFOF;
//         interface Put request;
//             method Action put(Vector#(2, Bit#(width)) inputVec);
//                 let sum = combAdderTree(inputVec);
//                 sumBuf.enq(sum);
//             endmethod
//         endinterface
//         interface response = toGet(sumBuf);
//     endmodule
// endinstance

// instance PipeAdderTree#(3, numeric type width);
//     module mkPipeAdderTree#(AdderTree#(3, width));
//         FIFOF#(Bit#(TAdd#(width, 2))) sumBuf <- mkPipelineFIFOF;
//         interface Put request;
//             method Action put(Vector#(3, Bit#(width)) inputVec);
//                 let sum = combAdderTree(inputVec);
//                 sumBuf.enq(sum);
//             endmethod
//         endinterface
//         interface response = toGet(sumBuf);
//     endmodule
// endinstance

// instance PipeAdderTree#(4, numeric type width);
//     module mkPipeAdderTree#(AdderTree#(4, width));
//         FIFOF#(Bit#(TAdd#(width, 2))) sumBuf <- mkPipelineFIFOF;
//         interface Put request;
//             method Action put(Vector#(4, Bit#(width)) inputVec);
//                 let sum = combAdderTree(inputVec);
//                 sumBuf.enq(sum);
//             endmethod
//         endinterface
//         interface response = toGet(sumBuf);
//     endmodule
// endinstance

// instance PipeAdderTree#(numeric type num, numeric type width)
//     provisos(Div#(num, 4, subTreeNum), Add#(num, appendNum, TMul#(subTreeNum, 4)));
//     module mkPipeAdderTree#(AdderTree#(num, width));
//         FIFOF#(Bit#(TAdd#(width, TLog#(num)))) sumBuf <- mkPipelineFIFOF;

//         Vector#(4, AdderTree#(subTreeNum, width)) subAdderTreeVec <- replicateM(mkPipeAdderTree);
//         Vector#(4, Bit#(TAdd#(TLog#(subTreeNum), width))) subTreeSumVec;
//         rule getSubTreeResult;
//             for (Integer i = 0; i < 4; i = i + 1) begin
//                 let sum <- subAdderTreeVec(i).response.get;
//                 subTreeSumVec(i) = sum;
//             end
//             sumBuf.enq(combAdderTree(subTreeSumVec));
//         endrule
        
//         interface Put request;
//             method Action put(Vector#(num, Bit#(width)) inputVec);
//                 Vector#(appendNum, Bit#(width)) zeroVec = replicate(0);
//                 let appendedVec = append(inputVec, zeroVec);
//                 for (Integer i = 0; i < 4; i = i + 1) begin
//                     subAdderTreeVec[i].request.put(takeAt(i*valueOf(subTreeNum), appendedVec));
//                 end
//             endmethod
//         endinterface

//         interface response = toGet(sumBuf);
//     endmodule
// endinstance

typeclass CombAdderTree#(numeric type num, numeric type width);
    function Bit#(TAdd#(TLog#(num), width)) combAdderTree(Vector#(num, Bit#(width)) vecIn);
endtypeclass

instance CombAdderTree#(1, width);
    function combAdderTree(vecIn) = vecIn[0];
endinstance

instance CombAdderTree#(2, width);
    function combAdderTree(vecIn) = extend(vecIn[0]) + extend(vecIn[1]);
endinstance

instance CombAdderTree#(num, width)
    provisos (
        Div#(num, 2, firstHalf), Add#(firstHalf, secondHalf, num),
        Add#(a__, TAdd#(TLog#(firstHalf), width), TAdd#(TLog#(num), width)),
        Add#(b__, TAdd#(TLog#(secondHalf), width), TAdd#(TLog#(num), width)),
        CombAdderTree#(firstHalf, width),
        CombAdderTree#(secondHalf, width)
    );
    function combAdderTree(vecIn);
        Vector#(firstHalf, Bit#(width)) firstHalfVec  = take(vecIn);
        Vector#(secondHalf, Bit#(width)) secondHalfVec = takeTail(vecIn);
        let firstHalfRes  = combAdderTree(firstHalfVec);
        let secondHalfRes = combAdderTree(secondHalfVec);
        return extend(firstHalfRes) + extend(secondHalfRes);
    endfunction
endinstance

// function Bit#(width) oneComplementAdd( Vector#(n, Bit#(width)) op ) provisos(Add#(a__, TLog#(width), width));
//     Bit#( TAdd#(TLog#(width), width) ) temp = 0;
//     for (Integer i = 0; i < valueOf(n); i = i + 1) begin
//         temp = temp + zeroExtend(op[i]);
//     end
//     Bit#( TLog#(width) ) overFlow = truncateLSB( temp );
//     Bit#( width ) remainder = truncate( temp );
//     return remainder + zeroExtend(overFlow);
// endfunction

function Bit#(width) getCheckSum(Vector#(n, Bit#(width)) op) 
    provisos(CombAdderTree#(n, width), Add#(a__, TLog#(width), width), Add#(TLog#(width), b__, TAdd#(TLog#(n), width)));
    let temp = combAdderTree(op);
    Bit#(TLog#(width)) overFlow = truncateLSB(temp);
    Bit#(width) remainder = truncate(temp);
    Bit#(width) complementRes = remainder + zeroExtend(overFlow);
    return ~complementRes;
endfunction

function Bit#(w) bitMask(Bit#(w) data, Bit#(m) mask) provisos(Div#(w,m,8));
    Bit#(w) fullMask = 0;
    for (Integer i = 0; i < valueOf(m); i = i + 1) begin
        for (Integer j = 0; j < 8; j = j + 1) begin
            fullMask[i*8+j] = mask[i];
        end
    end
    return fullMask & data;
endfunction

function Bit#(w) setAllBits;
    Bit#(TAdd#(w,1)) result = 1;
    return truncate((result << valueOf(w)) - 1);
endfunction

function Bool isAllOnes(Bit#(nSz) bits);
    Bool ret = unpack(&bits);
    return ret;
endfunction

function Bit#(width) byteRightShift(Bit#(width) dataIn, Bit#(shiftAmtWidth) shiftAmt) 
    provisos(Mul#(BYTE_WIDTH, byteNum, width));
    Vector#(byteNum, Byte) dataInVec = unpack(dataIn);
    dataInVec = shiftOutFrom0(0, dataInVec, shiftAmt);
    return pack(dataInVec);
endfunction

function Bit#(width) byteLeftShift(Bit#(width) dataIn, Bit#(shiftAmtWidth) shiftAmt) 
    provisos(Mul#(BYTE_WIDTH, byteNum, width));
    
    Vector#(byteNum, Byte) dataInVec = unpack(dataIn);
    dataInVec = shiftOutFromN(0, dataInVec, shiftAmt);
    return pack(dataInVec);
endfunction

typedef struct{
    Bit#(lw) lowData;
    Bit#(TSub#(DATA_BUS_WIDTH,lw)) highData;
    Bit#(lbw) lowByteEn;
    Bit#(TSub#(DATA_BUS_BYTE_WIDTH, lbw)) highByteEn;
} SepDataStream#(numeric type lw, numeric type lbw) deriving(Bits,Eq);

function SepDataStream#(lw, lbw) seperateDataStream(DataStream dIn)
    provisos(Add#(lw,hw,DATA_BUS_WIDTH), Add#(lbw,hbw,DATA_BUS_BYTE_WIDTH));
    return SepDataStream{
        lowData: truncate(dIn.data),
        highData: truncateLSB(dIn.data),
        lowByteEn: truncate(dIn.byteEn),
        highByteEn: truncateLSB(dIn.byteEn)
    };
endfunction

function Bit#(width) swapEndian(Bit#(width) data) provisos(Mul#(8, byteNum, width));
    Vector#(byteNum, Byte) dataVec = unpack(data);
    return pack(reverse(dataVec));
endfunction

function Bool isInGateWay(IpNetMask netMask, IpAddr host, IpAddr target);
    return (netMask & host) == (netMask & target);
endfunction

function Bit#(TLog#(oneHotWidth)) convertOneHotToIndex(Vector#(oneHotWidth, Bool) oneHotVec);
    Bit#(TLog#(oneHotWidth)) index = 0;
    for (Integer i = 0; i < valueOf(oneHotWidth); i = i + 1) begin
        if (oneHotVec[i]) begin
            index = fromInteger(i);
        end
    end
    return index;
endfunction

function AxiStream256PipeOut convertDataStreamToAxiStream256(DataStreamPipeOut stream);
    return (
        interface AxiStream256PipeOut;
            method AxiStream256 first();
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

typedef enum {
    SWAP, HOLD
} IsSwapEndian deriving(Eq);

typedef enum {
    INSERT, PASS, CLEAN
} AppendState deriving(Bits, Eq, FShow);
// Insert dType into the head of DataStream
module mkAppendDataStreamHead#(
    IsSwapEndian swapDataStream,
    IsSwapEndian swapInsertData,
    DataStreamPipeOut dataStreamIn,
    PipeOut#(dType) insertDataIn
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
        if (swapInsertData == SWAP) begin
            additionData = swapEndian(pack(insertDataIn.first));
        end
        else begin
            additionData = pack(insertDataIn.first);
        end
        insertDataIn.deq;
                
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

// typedef enum{
//     PASS, CLEAN
// } AppendState deriving(Bits, Eq, FShow);

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


module mkCrc32AxiStream256PipeOut#(
    CrcMode crcMode,
    AxiStream256PipeOut crcReq
)(PipeOut#(Crc32Checksum));
    CrcConfig#(CRC32_WIDTH) conf = CrcConfig {
        polynominal: fromInteger(valueOf(CRC32_IEEE_POLY)),
        initVal    : fromInteger(valueOf(CRC32_IEEE_INIT_VAL)),
        finalXor   : fromInteger(valueOf(CRC32_IEEE_FINAL_XOR)),
        revInput   : BIT_ORDER_REVERSE,
        revOutput  : BIT_ORDER_REVERSE,
        memFilePrefix: "crc_tab",
        crcMode    : crcMode
    };
    let crcResp <- mkCrcAxiStreamPipeOut(conf, crcReq);
    return crcResp;
endmodule

module mkSizedBramFifoToPipeOut#(
    Integer depth, 
    PipeOut#(dType) pipe
)(PipeOut#(dType)) provisos(Bits#(dType, dSize), Add#(1, a__, dSize), FShow#(dType));

    FIFOF#(dType) fifo <- mkSizedBRAMFIFOF(depth);
    rule doEnq;
        if (fifo.notFull) begin
            fifo.enq(pipe.first);
            pipe.deq;
            $display("BramFifo enq ", fshow(pipe.first));
        end
        else begin
            $display("BramFifo is Full");
        end
    endrule
    return convertFifoToPipeOut(fifo);
endmodule

module mkSizedFifoToPipeOut#(
    Integer depth, 
    PipeOut#(dType) pipe
)(PipeOut#(dType)) provisos(Bits#(dType, dSize), Add#(1, a__, dSize));

    FIFOF#(dType) fifo <- mkSizedFIFOF(depth);
    rule doEnq;
        fifo.enq(pipe.first);
        pipe.deq;
    endrule

    return convertFifoToPipeOut(fifo);
endmodule


