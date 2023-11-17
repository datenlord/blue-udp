import FIFOF :: *;
import Clocks :: *;
import Connectable :: *;
import Randomizable :: *;

import Utils :: *;
import XilinxAxiStreamAsyncFifo :: *;

import AxiStreamTypes :: *;
import SemiFifo :: *;

typedef 16 CASE_COUNT_WIDTH;
typedef 1024 TEST_CASE_NUM;

typedef 0 CLK_START;
typedef 0 CLK_INIT_VALUE;
typedef 1 CLK500MHZ_HALF_PERIOD;
typedef 2 CLK250MHZ_HALF_PERIOD;
typedef 10 RESET_CYCLES;

typedef 32 TEST_FIFO_DEPTH;
typedef  4 TEST_FIFO_SYNC_STAGES;
typedef 32 TEST_AXIS_TKEEP_WIDTH;
typedef 1  TEST_AXIS_TUSER_WIDTH;

(* synthesize, no_default_clock, no_default_reset *)
module mkTestXilinxAxiStreamAsyncFifo();
    Integer testCaseNum = valueOf(TEST_CASE_NUM);

    // Clock Signals
    let clk500MHz <- mkAbsoluteClockFull(
        valueOf(CLK_START),
        fromInteger(valueOf(CLK_INIT_VALUE)),
        valueOf(CLK500MHZ_HALF_PERIOD),
        valueOf(CLK500MHZ_HALF_PERIOD)
    );

    let clk250MHz <- mkAbsoluteClockFull(
        valueOf(CLK_START),
        fromInteger(valueOf(CLK_INIT_VALUE)),
        valueOf(CLK250MHZ_HALF_PERIOD),
        valueOf(CLK250MHZ_HALF_PERIOD)
    );

    let rst500Mhz <- mkInitialReset(10, clocked_by clk500MHz);
    let rst250MHz <- mkInitialReset(100, clocked_by clk250MHz);

    // Common Signals
    Reg#(Bool) isInputInit <- mkReg(False, clocked_by clk500MHz, reset_by rst500Mhz);
    Reg#(Bool) isOutputInit <- mkReg(False, clocked_by clk250MHz, reset_by rst250MHz);
    //Reg#(Bit#(CYCLE_COUNT_WIDTH)) cycleCount <- mkReg(0);
    Reg#(Bit#(CASE_COUNT_WIDTH)) inputCaseCount <- mkReg(0, clocked_by clk500MHz, reset_by rst500Mhz);
    Reg#(Bit#(CASE_COUNT_WIDTH)) outputCaseCount <- mkReg(0, clocked_by clk250MHz, reset_by rst250MHz);

    // Random Signals
    Randomize#(
        AxiStream#(TEST_AXIS_TKEEP_WIDTH, TEST_AXIS_TUSER_WIDTH)
    ) randAxiStream <- mkGenericRandomizer(clocked_by clk500MHz, reset_by rst500Mhz);
    Randomize#(Bool) randInputPause <- mkGenericRandomizer(clocked_by clk500MHz, reset_by rst500Mhz);
    Randomize#(Bool) randOutputPause <- mkGenericRandomizer(clocked_by clk250MHz, reset_by rst250MHz);
    
    FIFOF#(AxiStream#(TEST_AXIS_TKEEP_WIDTH, TEST_AXIS_TUSER_WIDTH)) inputBuf <- mkFIFOF(clocked_by clk500MHz, reset_by rst500Mhz);
    FIFOF#(AxiStream#(TEST_AXIS_TKEEP_WIDTH, TEST_AXIS_TUSER_WIDTH)) outputBuf <- mkFIFOF(clocked_by clk250MHz, reset_by rst250MHz);
    // DUT
    SyncFIFOIfc#(AxiStream#(TEST_AXIS_TKEEP_WIDTH, TEST_AXIS_TUSER_WIDTH)) dutFifo <- mkXilinxAxiStreamAsyncFifo(
        valueOf(TEST_FIFO_DEPTH),
        valueOf(TEST_FIFO_SYNC_STAGES),
        clk500MHz,
        rst500Mhz,
        clk250MHz,
        rst250MHz
    );

    SyncFIFOIfc#(AxiStream#(TEST_AXIS_TKEEP_WIDTH, TEST_AXIS_TUSER_WIDTH)) refFifo <- mkSyncFIFO(
        valueOf(TEST_FIFO_DEPTH),
        clk500MHz,
        rst500Mhz,
        clk250MHz
    );

    mkConnection(convertSyncFifoToPipeOut(dutFifo), convertFifoToPipeIn(outputBuf));
    mkConnection(convertSyncFifoToPipeIn(dutFifo), convertFifoToPipeOut(inputBuf));

    // Initialize Testbench
    rule initInput if (!isInputInit);
        randAxiStream.cntrl.init;
        randInputPause.cntrl.init;
        isInputInit <= True;
    endrule

    rule initOutput if (!isOutputInit);
        randOutputPause.cntrl.init;
        isOutputInit <= True;
    endrule


    rule genInput if (isInputInit && inputCaseCount < fromInteger(testCaseNum));
        let randFrame <- randAxiStream.next;
        let pause <- randInputPause.next;
        if (!pause) begin
            inputBuf.enq(randFrame);
            refFifo.enq(randFrame);
            inputCaseCount <= inputCaseCount + 1;
            $display("Generate %d input frame: ", inputCaseCount, randFrame);            
        end
    endrule

    rule checkOutput if (isOutputInit);
        let pause <- randOutputPause.next;
        if (!pause) begin
            let dutFrame = outputBuf.first;
            outputBuf.deq;
            let refFrame = refFifo.first;
            refFifo.deq;
            immAssert(
                dutFrame == refFrame,
                "Compare DUT And REF output @ mkTestXilinxAxiStreamAsyncFifo",
                $format("The %d testcase is incorrect", outputCaseCount)
            );
            $display("DUT output %d frame: ", outputCaseCount, dutFrame);
            outputCaseCount <= outputCaseCount + 1;
        end
    endrule

    rule finishTestbench if (outputCaseCount == fromInteger(testCaseNum));
        $display("Testbench: XilinxAxiStreamAsyncFifo passes all %d testcases", testCaseNum);
        $finish(0);
    endrule
endmodule