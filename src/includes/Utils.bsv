import PAClib::*;
import Ports::*;
import Vector::*;
import FIFOF::*;

import PrimUtils::*;

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
            if( sel ) begin pipeIn1.deq; end 
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
                method anyType first if(cond);
                    return pipeIn.first;
                endmethod
                method Bool notEmpty;
                    return pipeIn.notEmpty && cond;
                endmethod
                method Action deq if(cond);
                    pipeIn.deq;
                endmethod
            endinterface);
endfunction


function Bit#(width) oneComplementAdd( Vector#(n, Bit#(width)) op ) provisos(Add#(a__, TLog#(width), width));
    Bit#( TAdd#(TLog#(width), width) ) temp = 0;
    for(Integer i=0; i < valueOf(n); i=i+1) begin
        temp = temp + zeroExtend(op[i]);
    end
    Bit#( TLog#(width) ) overFlow = truncateLSB( temp );
    Bit#( width ) remainder = truncate( temp );
    return remainder + zeroExtend(overFlow);
endfunction

function Bit#(width) getCheckSum( Vector#(n, Bit#(width)) op ) provisos(Add#(a__, TLog#(width), width));
    Bit#( width) temp = oneComplementAdd( op );
    return ~temp;
endfunction

function Bit#(w) bitMask(Bit#(w) data, Bit#(m) mask) provisos(Div#(w,m,8));
    Bit#(w) fullMask = 0;
    for(Integer i=0; i < valueOf(m); i=i+1) begin
        for(Integer j=0; j < 8; j=j+1) begin
            fullMask[i*8+j] = mask[i];
        end
    end
    return fullMask & data;
endfunction

function Bit#(w) setAllBits;
    Bit#(TAdd#(w,1)) result = 1;
    return truncate((result << valueOf(w)) - 1);
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


typedef enum{
    INSERT, PASS, CLEAN
} InsertState deriving(Bits, Eq, FShow);
// Insert Bit#(w) into the head of DataStream
module mkDataStreamInsert#(
    DataStreamPipeOut dataStreamIn,
    PipeOut#(iType) insertDataIn
)(DataStreamPipeOut)
provisos(
    Bits#(iType, iWidth), 
    Add#(iWidth, rWidth, DATA_BUS_WIDTH),
    Mul#(iByteWidth, BYTE_WIDTH, iWidth), 
    Add#(iByteWidth, rByteWidth, DATA_BUS_BYTE_WIDTH)
);
    
    FIFOF#(DataStream) outputBuf <- mkFIFOF;
    Reg#(InsertState) insertState <- mkReg(INSERT);
    Reg#(Bit#(iWidth)) residueBuf <- mkRegU;
    Reg#(Bit#(iByteWidth)) residueByteEnBuf <- mkRegU;

    rule doInsertion;
        case (insertState)
            INSERT: begin
                let dataStream = dataStreamIn.first; dataStreamIn.deq;
                SepDataStream#(rWidth,rByteWidth) sepData = seperateDataStream(dataStream);
                let additionData = pack(insertDataIn.first); insertDataIn.deq;
                
                dataStream.data = {sepData.lowData, additionData};
                dataStream.byteEn = {sepData.lowByteEn, setAllBits};
                residueBuf <= sepData.highData;
                residueByteEnBuf <= sepData.highByteEn;
                if (dataStream.isLast) begin
                    if (sepData.highByteEn != 0) begin
                        dataStream.isLast = False;
                        insertState <= CLEAN;
                    end
                end
                else begin
                    insertState <= PASS;
                end
                outputBuf.enq(dataStream);
            end
            PASS: begin
                let dataStream = dataStreamIn.first; dataStreamIn.deq;
                SepDataStream#(rWidth, rByteWidth) sepData = seperateDataStream(dataStream);
                
                dataStream.data = {sepData.lowData, residueBuf};
                dataStream.byteEn = {sepData.lowByteEn, residueByteEnBuf};
                residueBuf <= sepData.highData;
                residueByteEnBuf <= sepData.highByteEn;
                
                if(dataStream.isLast) begin
                    if(sepData.highByteEn == 0 ) begin
                        insertState <= INSERT;
                    end
                    else begin
                        dataStream.isLast = False;
                        insertState <= CLEAN;
                    end
                end
                outputBuf.enq(dataStream);
            end
            CLEAN: begin
                DataStream dataStream = DataStream{
                    isFirst: False,
                    isLast: True,
                    data: zeroExtend(residueBuf),
                    byteEn: zeroExtend(residueByteEnBuf)
                };
                outputBuf.enq(dataStream);
                insertState <= INSERT;
            end
            // default: begin
            //     immFail(
            //         "unreachible case @ mkDataStreamInsert",
            //         $format("insertState=", fshow(insertState))
            //     );
            // end
        endcase
    endrule

    return f_FIFOF_to_PipeOut(outputBuf);

endmodule

interface DataStreamExtract#(type eType);
    interface PipeOut#(eType) extractDataOut;
    interface DataStreamPipeOut dataStreamOut;
endinterface

typedef enum{
    EXTRACT, PASS, CLEAN
} ExtractState deriving(Bits, Eq, FShow);

module mkDataStreamExtract#(
    DataStreamPipeOut dataStreamIn
)(DataStreamExtract#(eType)) 
provisos(
    Bits#(eType, eWidth),
    Add#(eWidth, rWidth, DATA_BUS_WIDTH),
    Mul#(eByteWidth, BYTE_WIDTH, eWidth),
    Add#(eByteWidth, rByteWidth, DATA_BUS_BYTE_WIDTH)
);

    FIFOF#(eType) extractDataBuf <- mkFIFOF;
    FIFOF#(DataStream) dataStreamBuf <- mkFIFOF;
    Reg#(ExtractState) extractState <- mkReg(EXTRACT);
    Reg#(Bool) isFirstReg <- mkReg(False);
    Reg#(Bit#(rWidth)) residueBuf <- mkRegU;
    Reg#(Bit#(rByteWidth)) residueByteEnBuf <- mkRegU;
    
    rule doExtraction;
        case(extractState)
            EXTRACT: begin
                let dataStream = dataStreamIn.first; dataStreamIn.deq;

                SepDataStream#(eWidth, eByteWidth) sepData = seperateDataStream(dataStream);
                residueBuf <= sepData.highData;
                residueByteEnBuf <= sepData.highByteEn;
                extractDataBuf.enq(unpack(sepData.lowData));
                if (dataStream.isLast) begin
                    if (sepData.highByteEn != 0) extractState <= CLEAN;
                end
                else begin
                    extractState <= PASS;
                end
                isFirstReg <= True;
            end
            PASS: begin
                let dataStream = dataStreamIn.first; dataStreamIn.deq;

                SepDataStream#(eWidth, eByteWidth) sepData = seperateDataStream(dataStream);
                dataStream.data = {sepData.lowData, residueBuf};
                dataStream.byteEn = {sepData.lowByteEn, residueByteEnBuf};
                dataStream.isFirst = isFirstReg;
                residueBuf <= sepData.highData;
                residueByteEnBuf <= sepData.highByteEn;

                if (dataStream.isLast) begin
                    if (sepData.highByteEn != 0) begin
                        extractState <= CLEAN;
                        dataStream.isLast = False;
                    end
                    else begin
                        extractState <= EXTRACT;
                    end
                end

                dataStreamBuf.enq(dataStream);
                isFirstReg <= False;
            end
            CLEAN: begin
                DataStream dataStream = DataStream{
                    isFirst: isFirstReg,
                    isLast: True,
                    data: zeroExtend(residueBuf),
                    byteEn: zeroExtend(residueByteEnBuf)
                };
                dataStreamBuf.enq(dataStream);
                extractState <= EXTRACT;
            end
            // default: begin
            //     immFail(
            //         "unreachible case @ mkDataStreamExtract",
            //         $format("extractState = %", extractState)
            //     );
            // end
        endcase

    endrule

    interface PipeOut extractDataOut = f_FIFOF_to_PipeOut(extractDataBuf);
    interface PipeOut dataStreamOut = f_FIFOF_to_PipeOut(dataStreamBuf);
endmodule


