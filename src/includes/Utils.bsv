import PAClib::*;
import Ports::*;
import Vector::*;

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


// module mkDataStreamFragment#(
//     PipeOut#( type dataType ) pipeIn
// )( PipeOut#(DataStream) ) provisos( Bits#(dataType,sz), Div#(sz, DATA_BUS_WIDTH, fragNum));


// endmodule


// One's Complement addition function
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

// function Vector#(n, Bit#(k)) bitToVector( Bit#(w) x ) provisos(Div#(w,n,k));
//     Vector#(n, Bit#(k)) result;
//     Integer fragWidth = valueOf(k);
//     for(Integer i=0; i < valueOf(n); i=i+1) begin
//         result[i] = x[(i+1)*fragWidth-1: i*fragWidth];
//     end
//     return result;
// endfunction

// function Bit#(TMul#(n,w)) vectorToBit( Vector#(n, Bit#(w)) x) provisos( Add#(a__, w, TMul#(n, w)) );
//     Bit#(TMul#(n,w)) result;
//     for(Integer i=0; i < valueOf(n); i=i+1) begin
//         result[(i+1)*valueOf(w) : i*valueOf(w)] = x[i];
//     end
//     return result;
// endfunction

