import FIFOF :: *;
import GetPut :: *;
import Vector :: *;
import ClientServer :: *;
import Randomizable :: *;

import Ports :: *;
import Utils :: *;
import SemiFifo :: *;

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
        if (delayCounter == delayCountMax) begin
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
        method ActionValue#(dType) get if (passData);
            let data = buffer.first;
            buffer.deq;
            return data;
        endmethod
    endinterface

endmodule


module mkDataStreamSender#(
    String instanceName,
    PipeOut#(Bit#(maxRawByteNumWidth)) rawByteNumIn,
    PipeOut#(Bit#(maxRawDataWidth)) rawDataIn
)(DataStreamPipeOut) 
    provisos(
        Mul#(maxRawByteNum, BYTE_WIDTH, maxRawDataWidth),
        Mul#(DATA_BUS_BYTE_WIDTH, maxFragNum, maxRawByteNum),
        NumAlias#(TLog#(TAdd#(maxRawByteNum, 1)), maxRawByteNumWidth),
        NumAlias#(TLog#(maxFragNum), maxFragNumWidth)
    );
    Reg#(Bit#(maxRawByteNumWidth)) rawByteCounter <- mkReg(0);
    Reg#(Bit#(maxFragNumWidth)) fragCounter <- mkReg(0);
    FIFOF#(DataStream) outputBuf <- mkFIFOF;

    rule doFragment;
        let rawData = rawDataIn.first;
        Vector#(maxFragNum, Data) rawDataVec = unpack(rawData);
        let rawByteNum = rawByteNumIn.first;

        DataStream dataStream = DataStream {
            data: rawDataVec[fragCounter],
            byteEn: setAllBits,
            isFirst: fragCounter == 0,
            isLast: False
        };

        let nextRawByteCountVal = rawByteCounter + fromInteger(valueOf(DATA_BUS_BYTE_WIDTH));
        if (nextRawByteCountVal >= rawByteNum) begin
            let extraByteNum = nextRawByteCountVal - rawByteNum;
            dataStream.byteEn = dataStream.byteEn >> extraByteNum;
            dataStream.data = bitMask(dataStream.data, dataStream.byteEn);
            dataStream.isLast = True;
            fragCounter <= 0;
            rawByteCounter <= 0;
            rawDataIn.deq;
            rawByteNumIn.deq;
        end
        else begin
            fragCounter <= fragCounter + 1;
            rawByteCounter <= nextRawByteCountVal;
        end

        outputBuf.enq(dataStream);
        $display("%s: send %8d fragment ", instanceName, fragCounter, fshow(dataStream));
    endrule
    
    return convertFifoToPipeOut(outputBuf);
endmodule
