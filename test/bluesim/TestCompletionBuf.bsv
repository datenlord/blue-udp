import EthUtils :: *;
import FIFOF :: *;
import CompletionBuf :: *;
import Randomizable :: *;

typedef Bit#(32) CBufData;
typedef 7 CBUF_SIZE;

(* synthesize *)
module mkTestCompletionBuf();

    Integer caseNum = 8192;
    Integer maxCycle = 20000;

    Reg#(Bit#(16)) inputCount <- mkReg(0);
    Reg#(Bit#(16)) outputCount <- mkReg(0);
    Reg#(Bit#(16)) cycle <- mkReg(0);
    Randomize#(CBufData) dataRand <- mkGenericRandomizer;
    Randomize#(Bool) completeRand <- mkGenericRandomizer;
    Randomize#(Bool) deqRand <- mkGenericRandomizer;

    CompletionBuf#(CBUF_SIZE, CBufData) cBuf <- mkCompletionBuf;
    FIFOF#(CBufData) refBuf <- mkSizedFIFOF(valueOf(CBUF_SIZE));
    FIFOF#(Tuple2#(CBufIndex#(CBUF_SIZE), CBufData)) completeBuf <- mkFIFOF;
    FIFOF#(Tuple2#(CBufIndex#(CBUF_SIZE), CBufData)) reorderBuf <- mkSizedFIFOF(valueOf(CBUF_SIZE));

    rule test;
        if (cycle == 0) begin
            dataRand.cntrl.init;
            completeRand.cntrl.init;
            deqRand.cntrl.init;
        end
        cycle <= cycle + 1;
        $display("\nCycle %d -----------------------------------",cycle);
        immAssert(
            cycle != fromInteger(maxCycle),
            "Testbench timeout assertion @ mkTestCompletionBuf",
            $format("Cycle count can't overflow %d", maxCycle)
        );
    endrule

    rule reserveCBuf if (inputCount < fromInteger(caseNum));
        let data <- dataRand.next;
        let token <- cBuf.reserve;
        refBuf.enq(data);
        completeBuf.enq(tuple2(token, data));
        $display("Reserve CBuf %d: token=%d data=%d", inputCount, token, data);
    endrule

    rule completeCBuf;
        let completeSelect <- completeRand.next;
        if (completeSelect) begin
            if (completeBuf.notEmpty) begin
                let tokenAndData = completeBuf.first;
                completeBuf.deq;
                reorderBuf.enq(tokenAndData);
            end
            if (reorderBuf.notEmpty) begin
                let tokenAndData = reorderBuf.first;
                reorderBuf.deq;
                cBuf.complete(tokenAndData);
                $display("Complete CBuf: index=%d data=%d", tpl_1(tokenAndData), tpl_2(tokenAndData));
            end
        end
        else begin

            if (completeBuf.notEmpty) begin
                let tokenAndData = completeBuf.first;
                completeBuf.deq;
                cBuf.complete(tokenAndData);
                $display("Complete CBuf: index=%d data=%d", tpl_1(tokenAndData), tpl_2(tokenAndData));
            end
            if (reorderBuf.notEmpty) begin
                let tokenAndData = reorderBuf.first;
                reorderBuf.deq;
                reorderBuf.enq(tokenAndData);
            end
            
        end
    endrule

    rule deqCBuf if (outputCount < fromInteger(caseNum));
        let idDeq <- deqRand.next;
        if (idDeq) begin
            let dutData = cBuf.first;
            cBuf.deq;
            let refData = refBuf.first;
            refBuf.deq;
            $display("CBuf Output %d: dut data=%x ref data=%x",  outputCount, dutData, refData);
            outputCount <= outputCount + 1;
            immAssert(
                refData == dutData,
                "check output of completion buf and reference buf @ mkTestCompletionBuf",
                $format("dut data is inconsistent with ref data")
            );
        end
    endrule

    rule finishTest if (outputCount == fromInteger(caseNum));
        $display("Pass all %d tests", caseNum);
        $finish;
    endrule

endmodule