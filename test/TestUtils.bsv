import GetPut::*;
import FIFOF::*;
import ClientServer::*;
import Randomizable::*;

typedef Server#(
    dType, dType
) RandomDelay#(type dType, numeric type maxDelay);

module mkRandomDelay(RandomDelay#(dType, delay)) 
    provisos(Bits#(dType, sz));

    FIFOF#(dType) buffer <- mkFIFOF;
    Reg#(Bool) hasInit <- mkReg(False);
    Reg#(Bit#(TLog#(delay))) delayCounter <- mkReg(0);
    Reg#(Bit#(TLog#(delay))) delayCountMax <- mkReg(0);
    let passData = delayCounter == delayCountMax;
    
    Randomize#(Bit#(TLog#(delay))) delayRand <- mkGenericRandomizer;
    rule doInit if (!hasInit);
        delayRand.cntrl.init;
        hasInit <= True;
    endrule

    rule doCount;
        if(delayCounter == delayCountMax) begin
            delayCounter <= 0;
            Bit#(TLog#(delay)) randDelay <- delayRand.next;
            delayCountMax <= randDelay;
        end
        else begin
            delayCounter <= delayCounter + 1;
        end
    endrule
    
    interface Put request = toPut(buffer);
    interface Get response;
        method ActionValue#(dType) get if(passData);
            let data = buffer.first;
            buffer.deq;
            return data;
        endmethod
    endinterface

endmodule