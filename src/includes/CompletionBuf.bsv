import Vector::*;
import PAClib::*;
import GetPut::*;


typedef Bit#(TLog#(size)) CBufIndex#(numeric type size);

interface CompletionBuf#(numeric type size, type dType);
    method Bool notFull;
    method ActionValue#(CBufIndex#(size)) reserve;
    method Action complete(Tuple2#(CBufIndex#(size), dType) x);
    method Bool notEmpty;
    method dType first;
    method Action deq;
endinterface


module mkCompletionBuf(CompletionBuf#(size, dType)) provisos(Bits#(dType, dSize));

    Vector#(size, Reg#(dType)) dataArray <- replicateM(mkRegU);
    Vector#(size, Array#(Reg#(Bool))) tagArray <- replicateM(mkCReg(2, False));
    // Vector#(size, )
    Reg#(Bool) full <- mkReg(False);
    Reg#(Bool) empty <- mkReg(True);
    Reg#(CBufIndex#(size)) enqP <- mkReg(0);
    Reg#(CBufIndex#(size)) deqP <- mkReg(0);
    CBufIndex#(size) maxIndex = fromInteger(valueOf(size) - 1);

    Reg#(Bool) deqReq[2] <- mkCReg(2, False);
    Reg#(Bool) reserveReq[2] <- mkCReg(2, False);
    Reg#(Maybe#(Tuple2#(CBufIndex#(size), dType))) completeReq[2] <- mkCReg(2, Invalid);


    function CBufIndex#(size) nextIndex(CBufIndex#(size) index);
        return (index == maxIndex) ? 0 : index + 1;
    endfunction

    (* fire_when_enabled *)         // WILL_FIRE == CAN_FIRE
    (* no_implicit_conditions *)    // CAN_FIRE == guard (True)
    rule canonicalize;
        let nextEnqP = nextIndex(enqP);
        let nextDeqP = nextIndex(deqP);
        if (reserveReq[1] && deqReq[1]) begin
            tagArray[enqP][0] <= False;
            enqP <= nextEnqP;
            deqP <= nextDeqP;
        end
        else if (reserveReq[1]) begin
            tagArray[enqP][0] <= False;
            enqP <= nextEnqP;
            empty <= False;
            full <= nextEnqP == deqP;
        end
        else if (deqReq[1]) begin
            deqP <= nextDeqP;
            full <= False;
            empty <= nextDeqP == enqP;
        end
        deqReq[1] <= False;
        reserveReq[1] <= False;
    endrule

    (* fire_when_enabled *)         // WILL_FIRE == CAN_FIRE
    (* no_implicit_conditions *)    // CAN_FIRE == guard (True)
    rule doComplete;
        if (isValid(completeReq[1])) begin
            match {.index, .data} = fromMaybe(?, completeReq[1]);
            tagArray[index][1] <= True;
            dataArray[index] <= data;
        end
        completeReq[1] <= tagged Invalid;
    endrule

    Bool reserveReady = !full;
    Bool deqReady = !empty && tagArray[deqP][0];

    method Bool notFull = reserveReady;
    
    method ActionValue#(CBufIndex#(size)) reserve if (reserveReady);
        reserveReq[0] <= True;
        return enqP;
    endmethod
    
    method Action complete(Tuple2#(CBufIndex#(size), dType) completeInfo);
        completeReq[0] <= tagged Valid completeInfo;
    endmethod

    method Bool notEmpty = deqReady;

    method dType first if (deqReady);
        return dataArray[deqP];
    endmethod

    method Action deq if (deqReady);
        deqReq[0] <= True;
    endmethod

endmodule

function PipeOut#(dType) completionBufToPipeOut(CompletionBuf#(size, dType) ifc);
    return(
        interface PipeOut;
            method dType first;
                return ifc.first;
            endmethod
            method Bool notEmpty;
                return ifc.notEmpty;
            endmethod
            method Action deq;
                ifc.deq;
            endmethod
        endinterface
    );
endfunction

instance ToGet#(CompletionBuf#(size, dType), dType);
    function Get#(dType) toGet(CompletionBuf#(size, dType) ifc);
        return(
            interface Get;
                method ActionValue#(dType) get;
                    ifc.deq;
                    return ifc.first;
                endmethod
            endinterface
        );
    endfunction

endinstance