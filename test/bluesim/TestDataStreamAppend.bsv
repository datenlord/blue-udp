import FIFOF :: *;

import Ports :: *;
import Utils :: *;
import SemiFifo :: *;
import PrimUtils :: *;
import TestUtils :: *;
import Randomizable :: *;

typedef 16 CYCLE_COUNT_WIDTH;
typedef 16 CASE_COUNT_WIDTH;
typedef 20000 MAX_CYCLE_NUM;

typedef 7 MAX_FRAGMENT_NUM;
typedef TMul#(MAX_FRAGMENT_NUM, DATA_BUS_WIDTH) MAX_RAW_DATA_WIDTH;
typedef TMul#(MAX_FRAGMENT_NUM, DATA_BUS_BYTE_WIDTH) MAX_RAW_BYTE_NUM;
typedef TLog#(TAdd#(MAX_RAW_BYTE_NUM, 1)) MAX_RAW_BYTE_NUM_WIDTH;

typedef 6 TEST_FRAGMENT_NUM;
typedef TMul#(TEST_FRAGMENT_NUM, DATA_BUS_BYTE_WIDTH) TEST_CASE_NUM;

(* synthesize *)
module mkTestDataStreamAppend();

    Integer testCaseNum = valueOf(TEST_CASE_NUM);
    Integer maxCycleNum = valueOf(MAX_CYCLE_NUM);

    // Common Signals
    Reg#(Bool) isInit <- mkReg(False);
    Reg#(Bit#(CASE_COUNT_WIDTH)) inputCaseCount <- mkReg(0);
    Reg#(Bit#(CASE_COUNT_WIDTH)) outputCaseCount <- mkReg(0);
    Reg#(Bit#(CYCLE_COUNT_WIDTH)) cycleCount <- mkReg(0);
    
    // Random Signals
    Randomize#(Bit#(MAX_RAW_DATA_WIDTH)) randRawData <- mkGenericRandomizer;
    Randomize#(Bit#(CRC32_WIDTH)) randAppendData <- mkGenericRandomizer;

    // DUT And Ref Model
    FIFOF#(Bit#(MAX_RAW_DATA_WIDTH)) dutRawDataBuf <- mkFIFOF;
    FIFOF#(Bit#(MAX_RAW_BYTE_NUM_WIDTH)) dutRawByteNumBuf <- mkFIFOF;
    FIFOF#(Bit#(CRC32_WIDTH)) dutAppendDataBuf <- mkFIFOF;
    FIFOF#(Bit#(MAX_RAW_BYTE_NUM_WIDTH)) dutStreamLengthBuf <- mkFIFOF;

    FIFOF#(Bit#(MAX_RAW_DATA_WIDTH)) refRawDataBuf <- mkFIFOF;
    FIFOF#(Bit#(MAX_RAW_BYTE_NUM_WIDTH)) refRawByteNumBuf <- mkFIFOF;

    let refDataStreamOut <- mkDataStreamSender(
        "RefDataStreamSender",
        convertFifoToPipeOut(refRawByteNumBuf),
        convertFifoToPipeOut(refRawDataBuf)
    );

    let dutDataStreamIn <- mkDataStreamSender(
        "DutDataStreamSender",
        convertFifoToPipeOut(dutRawByteNumBuf),
        convertFifoToPipeOut(dutRawDataBuf)
    );

    let dutDataStreamOut <- mkDataStreamAppend(
        HOLD,
        HOLD,
        dutDataStreamIn,
        convertFifoToPipeOut(dutAppendDataBuf),
        convertFifoToPipeOut(dutStreamLengthBuf)
    );

    // Initialize Testbench
    rule initTest if (!isInit);
        randRawData.cntrl.init;
        randAppendData.cntrl.init;
        isInit <= True;
    endrule

    // Count Cycle Number
    rule doCycleCount if (isInit);
        cycleCount <= cycleCount + 1;
        $display("\nCycle %d ----------------------------------------", cycleCount);
        immAssert(
            cycleCount < fromInteger(maxCycleNum),
            "Testbench timeout assertion @ mkTestCompletionBuf",
            $format("Cycle number overflow %d", maxCycleNum)
        );
    endrule

    rule driveDutInput if (isInit && (inputCaseCount < fromInteger(testCaseNum)));
        let rawData <- randRawData.next;
        let appendData <- randAppendData.next;
        Bit#(MAX_RAW_BYTE_NUM_WIDTH) dutRawByteNum = truncate(inputCaseCount + 1);
        Bit#(MAX_RAW_BYTE_NUM) mask = (1 << dutRawByteNum) - 1;
        let dutRawData = bitMask(rawData, mask);
        Bit#(MAX_RAW_DATA_WIDTH) extAppendData = zeroExtend(appendData);
        let refRawData = dutRawData | byteLeftShift(extAppendData, dutRawByteNum);
        let refRawByteNum = dutRawByteNum + 4;

        dutRawDataBuf.enq(dutRawData);
        dutRawByteNumBuf.enq(dutRawByteNum);
        dutAppendDataBuf.enq(appendData);
        dutStreamLengthBuf.enq(dutRawByteNum);
        refRawDataBuf.enq(refRawData);
        refRawByteNumBuf.enq(refRawByteNum);

        inputCaseCount <= inputCaseCount + 1;
        $display("Generate %6d test case:\n dataStream=%x\n appendData=%x\n", inputCaseCount, dutRawData, appendData);
    endrule

    rule checkDutOutput if (isInit && (outputCaseCount < fromInteger(testCaseNum)));
        let dutDataStream = dutDataStreamOut.first;
        dutDataStreamOut.deq;
        let refDataStream = refDataStreamOut.first;
        refDataStreamOut.deq;
        $display("Receive %5d case:", outputCaseCount);
        $display("REF: ", fshow(refDataStream));
        $display("DUT: ", fshow(dutDataStream));
        immAssert(
            dutDataStream == refDataStream,
            "Compare DUT And REF output @ mkTestDataStreamAppend",
            $format("Case %5d incorrect", outputCaseCount)
        );

        if (dutDataStream.isLast) begin
            outputCaseCount <= outputCaseCount + 1;
        end
    endrule

    // Finish Testbench
    rule finishTest if (outputCaseCount == fromInteger(testCaseNum));
        $display("Pass all %d tests", testCaseNum);
        $finish;
    endrule

endmodule

