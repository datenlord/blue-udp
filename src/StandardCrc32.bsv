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
    let initFile = sprintf("/home/wengwz/workspace/udp-eth/crc32tab/crc32_tab_%d.txt", offset + 28);
    RegFile#(Byte, Crc32Checksum) regFile <- mkRegFileFullLoad(initFile);
    return regFile;
endmodule

function Crc32Checksum combineCrc(Crc32Checksum crc1, Crc32Checksum crc2);
    return crc1 ^ crc2;
endfunction

function Crc32Checksum passCrc(Crc32Checksum crc);
    return crc;
endfunction


module mkStandardCrc32#(
    DataStreamPipeOut dataStreamIn
)(PipeOut#(Crc32Checksum));

    FIFOF#(DataStream) reflectedStream <- mkFIFOF;
    //FIFOF#(DataStream) shiftedStream <- mkFIFOF;
    FIFOF#(Vector#(TDiv#(DATA_BUS_BYTE_WIDTH, 4), Crc32Checksum)) reducedStream8 <- mkFIFOF;
    FIFOF#(Vector#(TDiv#(DATA_BUS_BYTE_WIDTH, 16), Crc32Checksum)) reducedStream2 <- mkFIFOF;
    FIFOF#(Crc32Checksum) outputBuf <- mkFIFOF;
    FIFOF#(Tuple2#(Bool, Bool)) ctrlSignalBuf <- mkSizedFIFOF(6);

    Reg#(Crc32Checksum) interChecksum <- mkReg(setAllBits);
    
    Vector#(DATA_BUS_BYTE_WIDTH, BRAM1Port#(Byte, Crc32Checksum)) crcBramTabVec <- genWithM(mkCrcBramTable);
    Vector#(CRC32_BYTE_WIDTH, RegFile#(Byte, Crc32Checksum)) crcDramTabVec <- genWithM(mkCrcRegFileTable);
    
    rule reflectInput;
        let dataIn = dataStreamIn.first;
        dataStreamIn.deq;
        dataIn.data = swapEndian(reverseBits(dataIn.data));
        reflectedStream.enq(dataIn);
    endrule

    // rule resolveUnalign;
    //     let dataIn = reflectedStream.first;
    //     reflectedStream.deq

    //     if (isAllOnes(dataIn.byteEn)) begin
    //         shiftedStream.enq(dataIn);
    //     end
    //     else begin
    //         Bit#(TLog#(DATA_BUS_WIDTH)) shiftAmt = zeroExtend(countZerosLSB(dataIn.byteEn));
    //         shiftAmt = shiftAmt << 3;
    //         Bit#(TAdd#(CRC32_WIDTH, DATA_BUS_WIDTH)) temp = { interChecksum, dataIn.data };
    //         temp = temp >> shiftAmt;
    //         Tuple2#(CRC32_WIDTH, DATA_BUS_WIDTH) tempTuple = split(temp);
    //         interChecksum <= tpl_1(tempTuple);
    //         dataIn.data = tpl_2(tempTuple);
    //         shiftedStream.enq(dataIn);
    //     end
    // endrule

    rule sendCrc32TabReq;
        // let dataIn = shiftedStream.first;
        // shiftedStream.deq;

        let dataIn = reflectedStream.first;
        reflectedStream.deq;
        Vector#(DATA_BUS_BYTE_WIDTH, Byte) dataByteVec = unpack(dataIn.data);
        for (Integer i = 0; i < fromInteger(valueOf(DATA_BUS_BYTE_WIDTH)); i = i + 1) begin
            BRAMRequest#(Byte, Crc32Checksum) bramReq = BRAMRequest {
                write: False,
                responseOnWrite: False,
                address: dataByteVec[i],
                datain: 0
            };
            crcBramTabVec[i].portA.request.put(bramReq);
        end

        ctrlSignalBuf.enq(tuple2(dataIn.isFirst, dataIn.isLast));
    endrule

    rule recvCrc32TabReq;
        Vector#(DATA_BUS_BYTE_WIDTH, Crc32Checksum) crcVec32 = newVector;
        for (Integer i = 0; i < fromInteger(valueOf(DATA_BUS_BYTE_WIDTH)); i = i + 1) begin
            let bramRead <- crcBramTabVec[i].portA.response.get;
            crcVec32[i] = bramRead;
        end

        let crcVec16 = mapPairs(combineCrc, passCrc, crcVec32);
        let crcVec8 = mapPairs(combineCrc, passCrc, crcVec16);
        reducedStream8.enq(crcVec8);
    endrule

    rule reduceCrcStream;
        let crcVec8 = reducedStream8.first;
        reducedStream8.deq;

        let crcVec4 = mapPairs(combineCrc, passCrc, crcVec8);
        let crcVec2 = mapPairs(combineCrc, passCrc, crcVec4);
        reducedStream2.enq(crcVec2);
    endrule

    rule getFinalChecksum;
        let crcVec2 = reducedStream2.first;
        reducedStream2.deq;
        let currentCrc = crcVec2[0] ^ crcVec2[1];

        // calculate previous checksum
        Vector#(CRC32_BYTE_WIDTH, Byte) interCrcVec = unpack(interChecksum);
        Vector#(CRC32_BYTE_WIDTH, Crc32Checksum) preCrcVec4 = newVector;
        for (Integer i = 0; i < fromInteger(valueOf(CRC32_BYTE_WIDTH)); i = i + 1) begin
            preCrcVec4[i] = crcDramTabVec[i].sub(interCrcVec[i]);
        end

        let preCrcVec2 = mapPairs(combineCrc, passCrc, preCrcVec4);
        let preCrc = preCrcVec2[0] ^ preCrcVec2[1];

        //
        let ctrlSignal = ctrlSignalBuf.first;
        ctrlSignalBuf.deq;

        let nextCrc = preCrc ^ currentCrc;
        if (tpl_2(ctrlSignal) == True) begin
            outputBuf.enq(reverseBits(~nextCrc));
            interChecksum <= setAllBits;
        end
        else begin
            interChecksum <= nextCrc;
        end
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
