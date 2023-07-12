import GetPut :: *;
import FIFOF :: *;
import Connectable :: *;

import Ports :: *;
import Utils :: *;
import MacLayer :: *;
import UdpIpLayer :: *;
import UdpIpEthRx :: *;
import EthernetTypes :: *;
import PortConversion :: *;
import UdpIpLayerForRdma :: *;

import SemiFifo :: *;
import CrcDefines :: *;
import AxiStreamTypes :: *;
import BusConversion :: *;

// module mkRemoveICrcFromUdpIpStream#(
//     DataStreamPipeOut udpIpStreamIn
// )(DataStreamPipeOut) provisos(
//     NumAlias#(TLog#(CRC32_BYTE_WIDTH), shiftAmtWidth)
// );
//     Wire#(Bit#(shiftAmtWidth)) shiftAmtW <- mkWire;
//     Wire#(Bool) isLastW <- mkWire;
//     FIFOF#(DataStream) interUdpIpStreamBuf <- mkFIFOF;
//     FIFOF#(DataStream) udpIpStreamOutBuf <- mkFIFOF;

//     rule genInterUdpIpStream;
//         let udpIpStream = udpIpStreamIn.first;
//         udpIpStreamIn.deq;
//         Bit#(shiftAmtWidth) foreFrameShiftAmt = 0;
//         Bool foreFrameIsLast = False;
//         Bit#(CRC32_BYTE_WIDTH) byteEnLSB = truncate(udpIpStream.byteEn); 
//         if (udpIpStream.isLast) begin
//             if (byteEnLSB < setAllBits) begin
//                 let zerosNum = pack(countZerosMSB(byteEnLSB));
//                 foreFrameShiftAmt = truncate(zerosNum);
//                 foreFrameIsLast = True;
//             end
//             else begin
//                 let byteEn = udpIpStream.byteEn >> valueOf(CRC32_BYTE_WIDTH);
//                 if (byteEn != 0) begin
//                     udpIpStream.byteEn = byteEn;
//                     udpIpStream.data = bitMask(udpIpStream.data, byteEn);
//                     interUdpIpStreamBuf.enq(udpIpStream);
//                 end
//                 else begin
//                     foreFrameIsLast = True;
//                 end
//             end
//         end
//         else begin
//             interUdpIpStreamBuf.enq(udpIpStream);
//         end
//         shiftAmtW <= foreFrameShiftAmt;
//         isLastW <= foreFrameIsLast;
//     endrule

//     rule genUdpIpStreamOut;
//         let interUdpIpStream = interUdpIpStreamBuf.first;
//         interUdpIpStreamBuf.deq;

//         if (!interUdpIpStream.isLast) begin
//             let shiftAmt = shiftAmtW;
//             if (shiftAmt != 0) begin
//                 let byteEn = interUdpIpStream.byteEn >> shiftAmt;
//                 interUdpIpStream.byteEn = byteEn;
//                 interUdpIpStream.data = bitMask(interUdpIpStream.data, byteEn);
//             end
//             interUdpIpStream.isLast = isLastW;
//         end

//         $display("removeICrcFromUdpIpStream: ", fshow(interUdpIpStream));
//         udpIpStreamOutBuf.enq(interUdpIpStream);
//     endrule

//     return convertFifoToPipeOut(udpIpStreamOutBuf);
// endmodule

interface RdmaUdpIpEthRx;
    interface Put#(UdpConfig) udpConfig;
    
    interface Put#(AxiStream512) axiStreamIn;
    
    interface MacMetaDataPipeOut macMetaDataOut;
    interface UdpIpMetaDataPipeOut udpIpMetaDataOut;
    interface DataStreamPipeOut  dataStreamOut;
endinterface

(* synthesize *)
module mkRdmaUdpIpEthRx(UdpIpEthRx);
    FIFOF#(AxiStream512) axiStreamInBuf <- mkFIFOF;
    
    Reg#(Maybe#(UdpConfig)) udpConfigReg <- mkReg(Invalid);
    let udpConfigVal = fromMaybe(?, udpConfigReg);

    DataStreamPipeOut macStream <- mkAxiStream512ToDataStream(
        convertFifoToPipeOut(axiStreamInBuf)
    );

    let macMetaAndUdpIpStream <- mkMacMetaDataAndUdpIpStream(
        macStream, 
        udpConfigVal
    );

    let udpIpMetaAndDataStream <- mkUdpIpMetaDataAndDataStreamForRdma(
        macMetaAndUdpIpStream.udpIpStreamOut,
        udpConfigVal
    );

    interface Put udpConfig;
        method Action put(UdpConfig conf);
            udpConfigReg <= tagged Valid conf;
        endmethod
    endinterface

    interface Put axiStreamIn;
        method Action put(AxiStream512 stream) if (isValid(udpConfigReg));
            axiStreamInBuf.enq(stream);
        endmethod
    endinterface

    interface PipeOut macMetaDataOut = macMetaAndUdpIpStream.macMetaDataOut;
    interface PipeOut udpIpMetaDataOut = udpIpMetaAndDataStream.udpIpMetaDataOut;
    interface PipeOut dataStreamOut = udpIpMetaAndDataStream.dataStreamOut;
endmodule


module mkRawRdmaUdpIpEthRx(RawUdpIpEthRx);
    UdpIpEthRx udpIpEthRx <- mkRdmaUdpIpEthRx;

    let rawUdpConfigBus <- mkRawUdpConfigBusSlave(udpIpEthRx.udpConfig);
    let rawMacMetaDataBus <- mkRawMacMetaDataBusMaster(udpIpEthRx.macMetaDataOut);
    let rawUdpIpMetaDataBus <- mkRawUdpIpMetaDataBusMaster(udpIpEthRx.udpIpMetaDataOut);
    let rawDataStreamBus <- mkRawDataStreamBusMaster(udpIpEthRx.dataStreamOut);
    let rawAxiStreamBus <- mkPutToRawAxiStreamSlave(udpIpEthRx.axiStreamIn, CF);

    interface rawUdpConfig = rawUdpConfigBus;
    interface rawAxiStreamIn = rawAxiStreamBus;
    interface rawMacMetaDataOut = rawMacMetaDataBus;
    interface rawUdpIpMetaDataOut = rawUdpIpMetaDataBus;
    interface rawDataStreamOut = rawDataStreamBus;
endmodule

