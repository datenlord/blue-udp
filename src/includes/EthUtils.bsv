import FIFOF :: *;
import Vector :: *;
import Clocks :: *;
import BRAMFIFO :: *;
import Connectable :: *;

import Ports :: *;
import EthernetTypes :: *;

import SemiFifo :: *;
import CrcDefines :: *;
import CrcAxiStream :: *;
import AxiStreamTypes :: *;

function Bool isZero(Bit#(nSz) bits) provisos(Add#(1, anysize, nSz));
    // TODO: consider using fold
    Bool ret = unpack(|bits);
    return !ret;
endfunction

function Bool isLessOrEqOne(Bit#(nSz) bits) provisos(Add#(1, anysize, nSz));
    Bool ret = isZero(bits >> 1);
    // Bool ret = isZero(bits >> 1) && unpack(bits[0]);
    return ret;
endfunction

function Bool isOne(Bit#(nSz) bits) provisos(Add#(1, anysize, nSz));
    return isLessOrEqOne(bits) && unpack(bits[0]);
endfunction

function Bool isAllOnes(Bit#(nSz) bits);
    Bool ret = unpack(&bits);
    return ret;
endfunction

function Bool isLargerThanOne(Bit#(tSz) bits) provisos(Add#(1, anysize, tSz));
    return !isZero(bits >> 1);
endfunction

function Bit#(nSz) zeroExtendLSB(Bit#(mSz) bits) provisos(Add#(mSz, anysize, nSz));
    return { bits, 0 };
endfunction

function Bit#(1) getMSB(Bit#(nSz) bits) provisos(Add#(1, anysize, nSz));
    return (reverseBits(bits))[0];
endfunction

function Bit#(TSub#(nSz, 1)) removeMSB(Bit#(nSz) bits) provisos(Add#(1, anysize, nSz));
    return truncateLSB(bits << 1);
endfunction

function anytype dontCareValue() provisos(Bits#(anytype, anysize));
    return ?;
endfunction

function anytype unwrapMaybe(Maybe#(anytype) maybe) provisos(Bits#(anytype, anysize));
    return fromMaybe(?, maybe);
endfunction

function anytype unwrapMaybeWithDefault(
    Maybe#(anytype) maybe, anytype defaultVal
) provisos(Bits#(anytype, nSz));
    return fromMaybe(defaultVal, maybe);
endfunction

function anytype1 getTupleFirst(Tuple2#(anytype1, anytype2) tupleVal);
    return tpl_1(tupleVal);
endfunction

function anytype2 getTupleSecond(Tuple2#(anytype1, anytype2) tupleVal);
    return tpl_2(tupleVal);
endfunction

function anytype identityFunc(anytype inputVal);
    return inputVal;
endfunction

function Action immAssert(Bool condition, String assertName, Fmt assertFmtMsg);
    action
        let pos = printPosition(getStringPosition(assertName));
        // let pos = printPosition(getEvalPosition(condition));
        if (!condition) begin
            $display(
              "ImmAssert failed in %m @time=%0t: %s-- %s: ",
              $time, pos, assertName, assertFmtMsg
            );
            $finish(1);
        end
    endaction
endfunction

function Action immFail(String assertName, Fmt assertFmtMsg);
    action
        let pos = printPosition(getStringPosition(assertName));
        // let pos = printPosition(getEvalPosition(condition));
        $display(
            "ImmAssert failed in %m @time=%0t: %s-- %s: ",
            $time, pos, assertName, assertFmtMsg
        );
        $finish(1);
    endaction
endfunction

function FifoOut#(anytype) muxFifoOut2(
    Bool sel, FifoOut#(anytype) pipeIn1, FifoOut#(anytype) pipeIn0
);
    FifoOut#(anytype) resultFifoOut = interface FifoOut;
        method anytype first;
            return sel ? pipeIn1.first : pipeIn0.first;
        endmethod

        method Bool notEmpty;
            return (sel && pipeIn1.notEmpty) || (!sel && pipeIn0.notEmpty);
        endmethod

        method Action deq;
            if (sel) begin pipeIn1.deq; end 
            else begin pipeIn0.deq; end
        endmethod
        
    endinterface;

    return resultFifoOut;

endfunction

function FifoOut#(type2) translateFifoOut(FifoOut#(type1) pipeIn, type2 payload);
    return (interface FifoOut;
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

function FifoOut#(anyType) continueFifoOutWhen(FifoOut#(anyType) pipeIn, Bool cond);
    return (interface FifoOut;
                method anyType first if (cond);
                    return pipeIn.first;
                endmethod
                method Bool notEmpty;
                    return pipeIn.notEmpty && cond;
                endmethod
                method Action deq if (cond);
                    pipeIn.deq;
                endmethod
            endinterface);
endfunction

typeclass OneHotMux#(numeric type num, numeric type width);
    function Bit#(width) oneHotMux(Vector#(num, Bool) selVec, Vector#(num, Bit#(width)) dataVec);
endtypeclass

instance OneHotMux#(1, width);
    function oneHotMux(selVec, dataVec) = selVec[0] ? dataVec[0] : 0;
endinstance

instance OneHotMux#(dNum, dWidth)
    provisos (
        Div#(dNum, 2, firstHalf),
        Add#(firstHalf, secondHalf, dNum),
        OneHotMux#(firstHalf, dWidth),
        OneHotMux#(secondHalf, dWidth)
    );
    function oneHotMux(selVec, dataVec);
        Vector#(firstHalf, Bool)  firstSelVec = take(selVec);
        Vector#(secondHalf, Bool) secondSelVec = takeTail(selVec);
        Vector#(firstHalf, Bit#(dWidth))  firstDataVec = take(dataVec);
        Vector#(secondHalf, Bit#(dWidth)) secondDataVec = takeTail(dataVec);
        return oneHotMux(firstSelVec, firstDataVec) | oneHotMux(secondSelVec, secondDataVec);
    endfunction
endinstance

typeclass CombAdderTree#(numeric type num, numeric type width);
    function Bit#(TAdd#(TLog#(num), width)) combAdderTree(Vector#(num, Bit#(width)) vecIn);
endtypeclass

instance CombAdderTree#(1, width);
    function combAdderTree(vecIn) = vecIn[0];
endinstance

instance CombAdderTree#(2, width);
    function combAdderTree(vecIn) = extend(vecIn[0]) + extend(vecIn[1]);
endinstance

instance CombAdderTree#(num, width)
    provisos (
        Div#(num, 2, firstHalf), 
        Add#(firstHalf, secondHalf, num),
        Add#(a__, TAdd#(TLog#(firstHalf), width), TAdd#(TLog#(num), width)),
        Add#(b__, TAdd#(TLog#(secondHalf), width), TAdd#(TLog#(num), width)),
        CombAdderTree#(firstHalf, width),
        CombAdderTree#(secondHalf, width)
    );
    function combAdderTree(vecIn);
        Vector#(firstHalf, Bit#(width)) firstHalfVec  = take(vecIn);
        Vector#(secondHalf, Bit#(width)) secondHalfVec = takeTail(vecIn);
        let firstHalfRes  = combAdderTree(firstHalfVec);
        let secondHalfRes = combAdderTree(secondHalfVec);
        return extend(firstHalfRes) + extend(secondHalfRes);
    endfunction
endinstance

function Bit#(width) oneComplementAdd( Vector#(n, Bit#(width)) op ) provisos(Add#(a__, TLog#(width), width));
    Bit#( TAdd#(TLog#(width), width) ) temp = 0;
    for (Integer i = 0; i < valueOf(n); i = i + 1) begin
        temp = temp + zeroExtend(op[i]);
    end
    Bit#( TLog#(width) ) overFlow = truncateLSB( temp );
    Bit#( width ) remainder = truncate( temp );
    return remainder + zeroExtend(overFlow);
endfunction

function Bit#(width) getCheckSum(Vector#(n, Bit#(width)) op) 
    provisos(CombAdderTree#(n, width), Add#(a__, TLog#(width), width), Add#(TLog#(width), b__, TAdd#(TLog#(n), width)));
    let temp = combAdderTree(op);
    Bit#(TLog#(width)) overFlow = truncateLSB(temp);
    Bit#(width) remainder = truncate(temp);
    Bit#(width) complementRes = remainder + zeroExtend(overFlow);
    return ~complementRes;
endfunction

function Bit#(w) bitMask(Bit#(w) data, Bit#(m) mask) provisos(Div#(w,m,8));
    Bit#(w) fullMask = 0;
    for (Integer i = 0; i < valueOf(m); i = i + 1) begin
        for (Integer j = 0; j < 8; j = j + 1) begin
            fullMask[i*8+j] = mask[i];
        end
    end
    return fullMask & data;
endfunction

function Bit#(w) setAllBits;
    Bit#(TAdd#(w,1)) result = 1;
    return truncate((result << valueOf(w)) - 1);
endfunction

function Bit#(width) byteRightShift(Bit#(width) dataIn, Bit#(shiftAmtWidth) shiftAmt) 
    provisos(Mul#(BYTE_WIDTH, byteNum, width));
    Vector#(byteNum, Byte) dataInVec = unpack(dataIn);
    dataInVec = shiftOutFrom0(0, dataInVec, shiftAmt);
    return pack(dataInVec);
endfunction

function Bit#(width) byteLeftShift(Bit#(width) dataIn, Bit#(shiftAmtWidth) shiftAmt) 
    provisos(Mul#(BYTE_WIDTH, byteNum, width));
    
    Vector#(byteNum, Byte) dataInVec = unpack(dataIn);
    dataInVec = shiftOutFromN(0, dataInVec, shiftAmt);
    return pack(dataInVec);
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

function Bit#(width) swapEndian(Bit#(width) data) provisos(Mul#(8, byteNum, width));
    Vector#(byteNum, Byte) dataVec = unpack(data);
    return pack(reverse(dataVec));
endfunction

function Bool isInGateWay(IpNetMask netMask, IpAddr host, IpAddr target);
    return (netMask & host) == (netMask & target);
endfunction

function Bit#(TLog#(oneHotWidth)) convertOneHotToIndex(Vector#(oneHotWidth, Bool) oneHotVec);
    Bit#(TLog#(oneHotWidth)) index = 0;
    for (Integer i = 0; i < valueOf(oneHotWidth); i = i + 1) begin
        if (oneHotVec[i]) begin
            index = fromInteger(i);
        end
    end
    return index;
endfunction

module mkCrc32AxiStream512FifoOut#(
    CrcMode crcMode,
    AxiStream512FifoOut crcReq
)(FifoOut#(Crc32Checksum));
    CrcConfig#(CRC32_WIDTH) conf = CrcConfig {
        polynominal: fromInteger(valueOf(CRC32_IEEE_POLY)),
        initVal    : fromInteger(valueOf(CRC32_IEEE_INIT_VAL)),
        finalXor   : fromInteger(valueOf(CRC32_IEEE_FINAL_XOR)),
        revInput   : BIT_ORDER_REVERSE,
        revOutput  : BIT_ORDER_REVERSE,
        memFilePrefix: "crc_tab",
        crcMode    : crcMode
    };
    let crcResp <- mkCrcAxiStreamFifoOut(conf, crcReq);
    return crcResp;
endmodule

module mkSizedBramFifoToFifoOut#(
    Integer depth, 
    FifoOut#(dType) pipe
)(FifoOut#(dType)) provisos(Bits#(dType, dSize), Add#(1, a__, dSize), FShow#(dType));

    FIFOF#(dType) fifo <- mkSizedBRAMFIFOF(depth);
    rule doEnq;
        fifo.enq(pipe.first);
        pipe.deq;
    endrule
    return convertFifoToFifoOut(fifo);
endmodule

module mkSizedFifoToFifoOut#(
    Integer depth, 
    FifoOut#(dType) pipe
)(FifoOut#(dType)) provisos(Bits#(dType, dSize), Add#(1, a__, dSize));

    FIFOF#(dType) fifo <- mkSizedFIFOF(depth);
    rule doEnq;
        fifo.enq(pipe.first);
        pipe.deq;
    endrule

    return convertFifoToFifoOut(fifo);
endmodule

interface Counter#(type countType);
    method countType _read;
    method Action incr(countType amt);
    method Action decr(countType amt);
    method Action clear;
endinterface

interface MultiPortCounter#(numeric type portNum, type countType);
    interface Vector#(portNum, Counter#(countType)) countPorts;
endinterface

module  mkMultiPortCounter#(countType initVal)(MultiPortCounter#(portNum, countType))
    provisos(Arith#(countType), Bits#(countType, countSize));

    Reg#(countType) countReg <- mkReg(initVal);
    Vector#(portNum, Wire#(countType)) incrementVec <- replicateM(mkDWire(0));
    Vector#(portNum, Wire#(countType)) decrementVec <- replicateM(mkDWire(0));
    let isClear <- mkPulseWireOR;

    rule updateCounterValue;
        countType totalIncr = 0, totalDecr = 0;
        for (Integer i = 0; i < valueOf(portNum); i = i + 1) begin
            totalIncr = totalIncr + incrementVec[i];
            totalDecr = totalDecr + decrementVec[i];
        end
        if (isClear) begin
            countReg <= 0;
        end
        else begin
            countReg <= countReg + totalIncr - totalDecr;
        end
    endrule

    Vector#(portNum, Counter#(countType)) ports = newVector;
    for (Integer i = 0; i < valueOf(portNum); i = i + 1) begin
        ports[i] = (
            interface Counter;
                method countType _read = countReg;
                method Action incr(countType amt);
                    incrementVec[i] <= amt;
                endmethod
                method Action decr(countType amt);
                    decrementVec[i] <= amt;
                endmethod
                method Action clear;
                    isClear.send;
                endmethod
            endinterface
        );
    end
    interface countPorts = ports;
endmodule

// typedef Server#(Vector#(num, Bit#(width)), Bit#(TAdd#(TLog#(num), width))) 
//     AdderTree#(numeric type num, numeric type width);
// typeclass PipeAdderTree#(numeric type num, numeric type width);
//     module mkPipeAdderTree(AdderTree#(num, width));
// endtypeclass

// instance PipeAdderTree#(1, numeric type width);
//     module mkPipeAdderTree#(AdderTree#(1, width));
//         FIFOF#(Bit#(width)) sumBuf <- mkPipelineFIFOF;
//         interface Put request;
//             method Action put(Vector#(1, Bit#(width)) inputVec);
//                 let sum = combAdderTree(inputVec);
//                 sumBuf.enq(sum);
//             endmethod
//         endinterface
//         interface response = toGet(sumBuf);
//     endmodule
// endinstance

// instance PipeAdderTree#(2, numeric type width);
//     module mkPipeAdderTree#(AdderTree#(2, width));
//         FIFOF#(Bit#(TAdd#(width, 1))) sumBuf <- mkPipelineFIFOF;
//         interface Put request;
//             method Action put(Vector#(2, Bit#(width)) inputVec);
//                 let sum = combAdderTree(inputVec);
//                 sumBuf.enq(sum);
//             endmethod
//         endinterface
//         interface response = toGet(sumBuf);
//     endmodule
// endinstance

// instance PipeAdderTree#(3, numeric type width);
//     module mkPipeAdderTree#(AdderTree#(3, width));
//         FIFOF#(Bit#(TAdd#(width, 2))) sumBuf <- mkPipelineFIFOF;
//         interface Put request;
//             method Action put(Vector#(3, Bit#(width)) inputVec);
//                 let sum = combAdderTree(inputVec);
//                 sumBuf.enq(sum);
//             endmethod
//         endinterface
//         interface response = toGet(sumBuf);
//     endmodule
// endinstance

// instance PipeAdderTree#(4, numeric type width);
//     module mkPipeAdderTree#(AdderTree#(4, width));
//         FIFOF#(Bit#(TAdd#(width, 2))) sumBuf <- mkPipelineFIFOF;
//         interface Put request;
//             method Action put(Vector#(4, Bit#(width)) inputVec);
//                 let sum = combAdderTree(inputVec);
//                 sumBuf.enq(sum);
//             endmethod
//         endinterface
//         interface response = toGet(sumBuf);
//     endmodule
// endinstance

// instance PipeAdderTree#(numeric type num, numeric type width)
//     provisos(Div#(num, 4, subTreeNum), Add#(num, appendNum, TMul#(subTreeNum, 4)));
//     module mkPipeAdderTree#(AdderTree#(num, width));
//         FIFOF#(Bit#(TAdd#(width, TLog#(num)))) sumBuf <- mkPipelineFIFOF;

//         Vector#(4, AdderTree#(subTreeNum, width)) subAdderTreeVec <- replicateM(mkPipeAdderTree);
//         Vector#(4, Bit#(TAdd#(TLog#(subTreeNum), width))) subTreeSumVec;
//         rule getSubTreeResult;
//             for (Integer i = 0; i < 4; i = i + 1) begin
//                 let sum <- subAdderTreeVec(i).response.get;
//                 subTreeSumVec(i) = sum;
//             end
//             sumBuf.enq(combAdderTree(subTreeSumVec));
//         endrule
        
//         interface Put request;
//             method Action put(Vector#(num, Bit#(width)) inputVec);
//                 Vector#(appendNum, Bit#(width)) zeroVec = replicate(0);
//                 let appendedVec = append(inputVec, zeroVec);
//                 for (Integer i = 0; i < 4; i = i + 1) begin
//                     subAdderTreeVec[i].request.put(takeAt(i*valueOf(subTreeNum), appendedVec));
//                 end
//             endmethod
//         endinterface

//         interface response = toGet(sumBuf);
//     endmodule
// endinstance

