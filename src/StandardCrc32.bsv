import Ports :: *;
import PAClib :: *;
import FIFOF :: *;
import RegFile :: *;
import BRAM :: *;
import Vector :: *;
import Printf :: *;
import GetPut :: *;

import Utils :: *;

// 256-bit fully pipelined
// 7 - 8 clock latency
// 36 * 256 * 4 36 KB ROM/RAM
// 

module mkCrcBramTable#(Integer offset)(BRAM1Port#(Byte, Crc32Checksum));
    let initFile = sprintf("/home/wengwz/workspace/udp-eth/crc32tab/crc32_tab_%d.txt", offset);
    BRAM_Configure bramConfig = BRAM_Configure{
        memorySize: 0,
        latency:    2,
        loadFormat: tagged Hex initFile,
        outFIFODepth: 4,
        allowWriteResponseBypass: False
    };
    BRAM1Port#(Byte, Crc32Checksum) bramPort <- mkBRAM1Server(bramConfig);
    return bramPort;    
endmodule

module mkCrcRegFileTable#(Integer offset)(RegFile#(Byte, Crc32Checksum));
    let initFile = sprintf("/home/wengwz/workspace/udp-eth/crc32tab/crc32_tab_%d.txt", offset);
    RegFile#(Byte, Crc32Checksum) regFile <- mkRegFileFullLoad(initFile);
    return regFile;
endmodule

function Crc32Checksum combineCrc(Crc32Checksum crc1, Crc32Checksum crc2);
    return crc1 ^ crc2;
endfunction

function Crc32Checksum passCrc(Crc32Checksum crc);
    return crc;
endfunction

typedef struct {
    Bool isLast;
    DataByteShiftAmt shiftAmt;
} Crc32CtrlSig deriving(Bits, FShow);

typedef struct {
    Data data;
    Crc32CtrlSig ctrlSig;
} PreProcessContext deriving(Bits, FShow);

typedef PreProcessContext ShiftContext;

typedef struct {
    Crc32Checksum curCrc;
    Crc32CtrlSig ctrlSig;
} ReduceContext deriving(Bits, FShow);

typedef struct {
    Crc32Checksum curCrc;
    Crc32Checksum interCrc;
    Crc32CtrlSig ctrlSig;
} AccumulateContext deriving(Bits, FShow);

typedef struct {
    Crc32Checksum curCrc;
    Crc32Checksum remainder;
    Data interCrc;
} LastShiftContext deriving(Bits, FShow);

module mkStandardCrc32#(
    DataStreamPipeOut dataStreamIn
)(PipeOut#(Crc32Checksum));

    FIFOF#(PreProcessContext) preProcessedStream <- mkFIFOF;
    FIFOF#(ShiftContext) shiftedStream <- mkFIFOF;
    FIFOF#(Vector#(TDiv#(DATA_BUS_BYTE_WIDTH, 4), Crc32Checksum)) crcVec8Stream <- mkFIFOF;
    FIFOF#(Crc32CtrlSig) crcCtrlSigBuf <- mkFIFOF;
    FIFOF#(ReduceContext) reducedStream <- mkFIFOF;
    FIFOF#(AccumulateContext) accumulatedStream <- mkFIFOF;
    FIFOF#(LastShiftContext) shiftedStreamLast <- mkFIFOF;
    FIFOF#(Vector#(TDiv#(DATA_BUS_BYTE_WIDTH, 4), Crc32Checksum)) crcVec8StreamLast <- mkFIFOF;
    FIFOF#(Crc32Checksum) curCrcBuf <- mkFIFOF;
    FIFOF#(Crc32Checksum) outputBuf <- mkFIFOF;
    //FIFOF#(Crc32CtrlSig) ctrlSignalBuf <- mkSizedFIFOF(6);

    Reg#(Crc32Checksum) interCrcResult <- mkReg(setAllBits);
    
    // Vector#(DATA_BUS_BYTE_WIDTH, BRAM1Port#(Byte, Crc32Checksum)) crcBramTabVec <- genWithM(mkCrcBramTable);
    Vector#(DATA_BUS_BYTE_WIDTH, RegFile#(Byte, Crc32Checksum)) crcDramTabVec <- genWithM(mkCrcRegFileTable);
    
    rule preProcessing;
        let dataIn = dataStreamIn.first;
        dataStreamIn.deq;
        
        // swap endian and reverse each byte
        dataIn.data = reverseBits(dataIn.data);
        dataIn.byteEn = reverseBits(dataIn.byteEn);
        
        let extraByteNum = countZerosLSB(dataIn.byteEn);
        
        Crc32CtrlSig ctrlSig = Crc32CtrlSig {
            isLast: dataIn.isLast,
            shiftAmt: pack(extraByteNum)
        };
        PreProcessContext crcContext = PreProcessContext {
            data: dataIn.data,
            ctrlSig: ctrlSig
        };
        preProcessedStream.enq(crcContext);
        $display("StandardCrc32 PreProcessing: ", fshow(crcContext));
    endrule

    rule shiftOutExtraByte;
        let crcContext = preProcessedStream.first;
        preProcessedStream.deq;
        let data = crcContext.data;
        let shiftAmt = crcContext.ctrlSig.shiftAmt;
        crcContext.data = byteRightShifter(data, shiftAmt);
        shiftedStream.enq(crcContext);
        $display("StandardCrc32 ShiftExtraByte: ", fshow(crcContext));
    endrule

    rule readCrcTable;
        let crcContext = shiftedStream.first;
        shiftedStream.deq;
        Vector#(DATA_BUS_BYTE_WIDTH, Byte) dataByteVec = unpack(crcContext.data);
        Vector#(DATA_BUS_BYTE_WIDTH, Crc32Checksum) crcVec32 = newVector;
        for (Integer i = 0; i < valueOf(DATA_BUS_BYTE_WIDTH); i = i + 1) begin
            crcVec32[i] = crcDramTabVec[i].sub(dataByteVec[i]);
        end
        let crcVec16 = mapPairs(combineCrc, passCrc, crcVec32);
        let crcVec8 = mapPairs(combineCrc, passCrc, crcVec16);
        crcVec8Stream.enq(crcVec8);
        crcCtrlSigBuf.enq(crcContext.ctrlSig);
    endrule

    rule reduceCrcStream;
        let crcVec8 = crcVec8Stream.first;
        crcVec8Stream.deq;
        let ctrlSig = crcCtrlSigBuf.first;
        crcCtrlSigBuf.deq;

        let crcVec4 = mapPairs(combineCrc, passCrc, crcVec8);
        let crcVec2 = mapPairs(combineCrc, passCrc, crcVec4);
        let crcVec1  = mapPairs(combineCrc, passCrc, crcVec2);

        ReduceContext crcContext = ReduceContext {
            ctrlSig: ctrlSig,
            curCrc: crcVec1[0]
        };
        reducedStream.enq(crcContext);
    endrule

    rule accumulateCrc;
        let crcContext = reducedStream.first;
        reducedStream.deq;

        // calculate previous checksum
        Vector#(CRC32_BYTE_WIDTH, Byte) interCrcVec = unpack(interCrcResult);
        Vector#(CRC32_BYTE_WIDTH, Crc32Checksum) preCrcVec4 = newVector;
        Integer interCrcOffset = valueOf(DATA_BUS_BYTE_WIDTH) - valueOf(CRC32_BYTE_WIDTH);
        for (Integer i = 0; i < valueOf(CRC32_BYTE_WIDTH); i = i + 1) begin
            preCrcVec4[i] = crcDramTabVec[i + 28].sub(interCrcVec[i]);
        end

        let preCrcVec2 = mapPairs(combineCrc, passCrc, preCrcVec4);
        let preCrcVec1 = mapPairs(combineCrc, passCrc, preCrcVec2);

        let nextCrc = crcContext.curCrc ^ preCrcVec1[0];
        AccumulateContext crcContextLast = AccumulateContext {
            curCrc  : crcContext.curCrc,
            interCrc: interCrcResult,
            ctrlSig : crcContext.ctrlSig
        };

        if (crcContext.ctrlSig.isLast) begin
            accumulatedStream.enq(crcContextLast);
            interCrcResult <= setAllBits;
        end
        else begin
            interCrcResult <= nextCrc;
        end
    endrule

    rule shiftLastCrc;
        let crcContext = accumulatedStream.first;
        accumulatedStream.deq;
        Bit#(TAdd#(DATA_BUS_WIDTH, CRC32_WIDTH)) interCrc = zeroExtend(crcContext.interCrc);
        interCrc = interCrc << valueOf(DATA_BUS_WIDTH);
        interCrc = byteRightShifter(interCrc, crcContext.ctrlSig.shiftAmt);
        LastShiftContext lastShiftContext = LastShiftContext {
            curCrc: crcContext.curCrc,
            remainder: truncate(interCrc),
            interCrc: truncateLSB(interCrc)
        };
        shiftedStreamLast.enq(lastShiftContext);
    endrule

    rule readCrcTableLast;
        let crcContext = shiftedStreamLast.first;
        shiftedStreamLast.deq;
        Vector#(DATA_BUS_BYTE_WIDTH, Byte) dataByteVec = unpack(crcContext.interCrc);
        Vector#(DATA_BUS_BYTE_WIDTH, Crc32Checksum) crcVec32 = newVector;
        for (Integer i = 0; i < valueOf(DATA_BUS_BYTE_WIDTH); i = i + 1) begin
            crcVec32[i] = crcDramTabVec[i].sub(dataByteVec[i]);
        end
        let crcVec16 = mapPairs(combineCrc, passCrc, crcVec32);
        let crcVec8 = mapPairs(combineCrc, passCrc, crcVec16);
        crcVec8StreamLast.enq(crcVec8);
        curCrcBuf.enq(crcContext.curCrc ^ crcContext.remainder);
    endrule

    rule calculateFinalCrc;
        let crcVec8 = crcVec8StreamLast.first;
        crcVec8StreamLast.deq;
        let curCrc = curCrcBuf.first;
        curCrcBuf.deq;

        let crcVec4 = mapPairs(combineCrc, passCrc, crcVec8);
        let crcVec2 = mapPairs(combineCrc, passCrc, crcVec4);
        let crcVec1  = mapPairs(combineCrc, passCrc, crcVec2);
        let finalCrcRes = crcVec1[0] ^ curCrc;
        outputBuf.enq(reverseBits(~finalCrcRes));
        $display("Finish computation of one case: %x", finalCrcRes);
    endrule

    return f_FIFOF_to_PipeOut(outputBuf);
endmodule

interface StandardCrc32Syn;
    interface Put#(DataStream) dataStreamIn;
    interface PipeOut#(Crc32Checksum) crcCheckSumOut;
endinterface

(* synthesize *)
module mkStandardCrc32Syn(StandardCrc32Syn);
    FIFOF#(DataStream) dataStreamInBuf <- mkFIFOF;
    PipeOut#(Crc32Checksum) standardCrc32 <- mkStandardCrc32(
        f_FIFOF_to_PipeOut(dataStreamInBuf)
    );

    interface Put dataStreamIn;
        method Action put(DataStream stream);
            dataStreamInBuf.enq(stream);
        endmethod
    endinterface

    interface crcCheckSumOut = standardCrc32;
endmodule
