import FIFOF :: *;
import PrimUtils :: *;
import Randomizable :: *;
import CRC :: *;
import Vector :: *;

import Ports :: *;
import SemiFifo :: *;
import StandardCrc32 :: *;
import Utils :: *;

typedef 16 CYCLE_COUNT_WIDTH;
typedef 50000 MAX_CYCLE;
typedef 32 CASE_NUM;
typedef TLog#(TAdd#(CASE_NUM, 1)) CASE_COUNT_WIDTH;
typedef 133 CASE_BYTE_WIDTH;
typedef TMul#(CASE_BYTE_WIDTH, BYTE_WIDTH) CASE_WIDTH;
typedef TLog#(TAdd#(CASE_BYTE_WIDTH, 1)) CASE_BYTE_COUNT_WIDTH;
typedef TDiv#(CASE_WIDTH, DATA_BUS_WIDTH) FRAGMENT_NUM;
typedef TLog#(FRAGMENT_NUM) FRAGMENT_COUNT_WIDTH;
typedef TSub#(TMul#(FRAGMENT_NUM, DATA_BUS_BYTE_WIDTH), CASE_BYTE_WIDTH) EXTRA_BYTE_NUM;

module mkTestStandardCrc32 (Empty);
    Reg#(Bit#(CASE_COUNT_WIDTH)) inputCaseCount <- mkReg(0);
    Reg#(Bit#(CASE_COUNT_WIDTH)) outputCaseCount <- mkReg(0);
    Reg#(Bit#(CASE_BYTE_COUNT_WIDTH)) caseByteCount <- mkReg(0);
    Reg#(Bit#(FRAGMENT_COUNT_WIDTH))  fragmentCount <- mkReg(0);
    
    FIFOF#(Crc32Checksum) refOutputBuf <- mkFIFOF;
    FIFOF#(Bit#(CASE_WIDTH)) caseDataBuf <- mkFIFOF;
    FIFOF#(DataStream) dataStreamBuf <- mkFIFOF;

    CRC#(CRC32_WIDTH) refCrcModel <- mkCRC32;
    PipeOut#(Crc32Checksum) dutCrcModel <- mkStandardCrc32(
        convertFifoToPipeOut(dataStreamBuf)
    );
    
    Reg#(Bool) isInit <- mkReg(False);
    Reg#(Bit#(CYCLE_COUNT_WIDTH)) cycle <- mkReg(0);
    Randomize#(Bit#(CASE_WIDTH)) caseDataRand <- mkGenericRandomizer;
    
    rule doRandInit if (!isInit);
        caseDataRand.cntrl.init;
        refCrcModel.clear;
        isInit <= True;
    endrule

    rule doCycleCount if (isInit);
        cycle <= cycle + 1;
        immAssert(
            cycle != fromInteger(valueOf(MAX_CYCLE)),
            "Testbench timeout assertion @ mkTestUdpEthRxTx",
            $format("Cycle count can't overflow %d", valueOf(MAX_CYCLE))
        );
        $display("\nCycle %d -----------------------------------",cycle);
    endrule
    
    Reg#(Bit#(CASE_WIDTH)) tempCaseData <- mkRegU;
    rule genTestCase if (isInit && inputCaseCount < fromInteger(valueOf(CASE_NUM)));
        if (caseByteCount == 0) begin
            let randData <- caseDataRand.next;
            tempCaseData <= randData;
            refCrcModel.add(truncateLSB(randData));
            caseByteCount <= caseByteCount + 1;
            $display("Gen random test case: %x", randData);
        end
        else if (caseByteCount < fromInteger(valueOf(CASE_BYTE_WIDTH))) begin
            Vector#(CASE_BYTE_WIDTH, Byte) caseDataVec = unpack(tempCaseData);
            caseDataVec = reverse(caseDataVec);
            refCrcModel.add(caseDataVec[caseByteCount]);
            caseByteCount <= caseByteCount + 1;
            $display("Add Ref Crc32: %x", caseDataVec[caseByteCount]);
        end
        else begin
            caseByteCount <= 0;
            inputCaseCount <= inputCaseCount + 1;
            caseDataBuf.enq(tempCaseData);
            let refCheckSum <- refCrcModel.complete;
            refOutputBuf.enq(refCheckSum);
            $display("Generate %d input case: %x crc: %x", inputCaseCount, tempCaseData, refCheckSum);
        end
    endrule

    rule driveDutInput if (isInit);
        Integer maxFragmentCount = valueOf(FRAGMENT_NUM) - 1;
        let isFirstFrag = fragmentCount == 0;
        let isLastFrag = fragmentCount == fromInteger(maxFragmentCount);
        Bit#(TMul#(FRAGMENT_NUM, DATA_BUS_WIDTH)) extCaseData = {caseDataBuf.first, 0};
        Vector#(FRAGMENT_NUM, Bit#(DATA_BUS_WIDTH)) fragmentDataVec = unpack(extCaseData);
        fragmentDataVec = reverse(fragmentDataVec);
        ByteEn byteEn = setAllBits;
        if (isLastFrag) begin
            byteEn = byteEn >> valueOf(EXTRA_BYTE_NUM);
        end
        DataStream fragment = DataStream {
            data: swapEndian(fragmentDataVec[fragmentCount]),
            byteEn: byteEn,
            isFirst: isFirstFrag,
            isLast: isLastFrag
        };
        dataStreamBuf.enq(fragment);
        $display("Drive Dut CRC32: %x", fshow(fragment));
        if (isLastFrag) begin
            fragmentCount <= 0;
            $display("Drive dut input ports: %x", caseDataBuf.first);
            caseDataBuf.deq;
        end
        else begin
            fragmentCount <= fragmentCount + 1;
        end
    endrule

    rule checkDutOuput if (isInit && outputCaseCount < fromInteger(valueOf(CASE_NUM)));
        let refOutput = refOutputBuf.first;
        refOutputBuf.deq;
        let dutOutput = dutCrcModel.first;
        dutCrcModel.deq;
        $display("Revc case %d output: DUT=%x REF=%x", outputCaseCount,dutOutput, refOutput);
        immAssert(
            dutOutput == refOutput,
            "Check meta data from dstUdp @ mkTestUdpEth",
            $format("The output of dut and ref are inconsistent")
        );
        outputCaseCount <= outputCaseCount + 1;
    endrule

    rule doFinish if (outputCaseCount == fromInteger(valueOf(CASE_NUM)));
        $display("Pass all %d test cases!", valueOf(CASE_NUM));
        $finish;
    endrule
endmodule