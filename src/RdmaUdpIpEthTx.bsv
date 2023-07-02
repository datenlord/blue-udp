import GetPut :: *;
import FIFOF :: *;

import UdpIpLayer :: *;
import MacLayer :: *;
import Ports :: *;
import PortConversion :: *;
import EthernetTypes :: *;
import Utils :: *;
import SemiFifo :: *;
import AxiStreamTypes :: *;
import UdpIpEthTx :: *;
import Crc32AxiStream :: *;
import CrcAxiStream :: *;

(* synthesize *)
module mkRdmaUdpIpEthTx(UdpIpEthTx);

    FIFOF#(DataStream) dataStreamBuf <- mkFIFOF;
    FIFOF#(DataStream) dataStreamCrcBuf <- mkFIFOF;
    FIFOF#(UdpIpMetaData) udpIpMetaDataBuf <- mkFIFOF;
    FIFOF#(UdpIpMetaData) udpIpMetaDataCrcBuf <- mkFIFOF;
    FIFOF#(MacMetaData) macMetaDataBuf <- mkFIFOF;
    FIFOF#(UdpLength) preComputeLengthBuf <- mkFIFOF;
    
    Reg#(Maybe#(UdpConfig)) udpConfigReg <- mkReg(Invalid);
    let udpConfigVal = fromMaybe(?, udpConfigReg);
    
    DataStreamPipeOut udpIpStream <- mkUdpIpStreamGenerator(
        genUdpIpHeaderForRoCE,
        convertFifoToPipeOut(udpIpMetaDataBuf),
        convertFifoToPipeOut(dataStreamBuf),
        udpConfigVal
    );

    DataStreamPipeOut udpIpStreamForICrc <- mkUdpIpStreamForICrc(
        convertFifoToPipeOut(udpIpMetaDataCrcBuf),
        convertFifoToPipeOut(dataStreamCrcBuf),
        udpConfigVal
    );

    // TODO: to be modified
    Crc32AxiStream256 crc32Stream <- mkCrc32AxiStream256;
    FIFOF#(Bit#(32)) iCrcResultBuf <- mkFIFOF;
    rule putCrcInput;
        let udpIpStream = udpIpStreamForICrc.first;
        udpIpStreamForICrc.deq;
        CrcAxiStream::AxiStream#(32, 256) crcAxiStreamIn = CrcAxiStream::AxiStream {
            tData: udpIpStream.data,
            tKeep: udpIpStream.byteEn,
            tUser: False,
            tLast: udpIpStream.isLast
        };
        crc32Stream.crcReq.put(crcAxiStreamIn);
    endrule

    rule getCrcOutput;
        let crcResult <- crc32Stream.crcResp.get();
        iCrcResultBuf.enq(crcResult);
    endrule

    DataStreamPipeOut udpIpStreamWithICrc <- mkDataStreamAppend(
        HOLD,
        HOLD,
        udpIpStream,
        convertFifoToPipeOut(iCrcResultBuf),
        convertFifoToPipeOut(preComputeLengthBuf)
    );

    DataStreamPipeOut macStream <- mkMacStreamGenerator(
        udpIpStreamWithICrc,
        convertFifoToPipeOut(macMetaDataBuf), 
        udpConfigVal
    );

    AxiStream512PipeOut macAxiStream <- mkDataStreamToAxiStream(macStream);

    interface Put udpConfig;
        method Action put(UdpConfig conf);
            udpConfigReg <= tagged Valid conf;
        endmethod
    endinterface

    interface Put udpIpMetaDataIn;
        method Action put(UdpIpMetaData udpIpMeta) if (isValid(udpConfigReg));
            udpIpMetaDataBuf.enq(udpIpMeta);
            udpIpMetaDataCrcBuf.enq(udpIpMeta);
            let streamLength = udpIpMeta.dataLen
                             + fromInteger(valueOf(IP_HDR_BYTE_WIDTH))
                             + fromInteger(valueOf(UDP_HDR_BYTE_WIDTH));
            preComputeLengthBuf.enq(streamLength);
        endmethod
    endinterface

    interface Put dataStreamIn;
        method Action put(DataStream stream) if (isValid(udpConfigReg));
            dataStreamBuf.enq(stream);
            dataStreamCrcBuf.enq(stream);
        endmethod
    endinterface

    interface Put macMetaDataIn;
        method Action put(MacMetaData macMeta) if (isValid(udpConfigReg));
            macMetaDataBuf.enq(macMeta);
        endmethod
    endinterface

    interface PipeOut axiStreamOut = macAxiStream;
endmodule


module mkRawRdmaUdpIpEthTx(RawUdpIpEthTx);
    UdpIpEthTx rdmaUdpIpEthTx <- mkRdmaUdpIpEthTx;

    let rawUdpConfigBus <- mkRawUdpConfigBusSlave(rdmaUdpIpEthTx.udpConfig);
    let rawUdpIpMetaDataBus <- mkRawUdpIpMetaDataBusSlave(rdmaUdpIpEthTx.udpIpMetaDataIn);
    let rawMacMetaDataBus <- mkRawMacMetaDataBusSlave(rdmaUdpIpEthTx.macMetaDataIn);
    let rawDataStreamBus <- mkRawDataStreamBusSlave(rdmaUdpIpEthTx.dataStreamIn);

    let rawAxiStreamBus <- mkPipeOutToRawAxiStreamMaster(rdmaUdpIpEthTx.axiStreamOut);

    interface rawUdpConfig = rawUdpConfigBus;
    interface rawUdpIpMetaDataIn = rawUdpIpMetaDataBus;
    interface rawMacMetaDataIn = rawMacMetaDataBus;
    interface rawDataStreamIn = rawDataStreamBus;
    interface rawAxiStreamOut = rawAxiStreamBus;
endmodule

