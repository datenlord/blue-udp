import GetPut :: *;
import FIFOF :: *;
import Connectable :: *;

import Utils :: *;
import Ports :: *;
import MacLayer :: *;
import UdpIpEthTx :: *;
import EthernetTypes :: *;
import PortConversion :: *;
import UdpIpLayerForRdma :: *;

import SemiFifo :: *;
import CrcDefines :: *;
import AxiStreamTypes :: *;

(* synthesize *)
module mkRdmaUdpIpEthTx(UdpIpEthTx);

    FIFOF#(DataStream) dataStreamBuf <- mkFIFOF;
    FIFOF#(UdpIpMetaData) udpIpMetaDataBuf <- mkFIFOF;
    FIFOF#(MacMetaData) macMetaDataBuf <- mkFIFOF;

    
    Reg#(Maybe#(UdpConfig)) udpConfigReg <- mkReg(Invalid);
    let udpConfigVal = fromMaybe(?, udpConfigReg);
    
    DataStreamPipeOut udpIpStreamWithICrc <- mkUdpIpStreamForRdma(
        convertFifoToPipeOut(udpIpMetaDataBuf),
        convertFifoToPipeOut(dataStreamBuf),
        udpConfigVal
    );

    DataStreamPipeOut macStream <- mkMacStream(
        udpIpStreamWithICrc,
        convertFifoToPipeOut(macMetaDataBuf), 
        udpConfigVal
    );

    AxiStream512PipeOut macAxiStream <- mkDataStreamToAxiStream512(macStream);

    interface Put udpConfig;
        method Action put(UdpConfig conf);
            udpConfigReg <= tagged Valid conf;
        endmethod
    endinterface

    interface Put udpIpMetaDataIn;
        method Action put(UdpIpMetaData udpIpMeta) if (isValid(udpConfigReg));
            udpIpMetaDataBuf.enq(udpIpMeta);
        endmethod
    endinterface

    interface Put dataStreamIn;
        method Action put(DataStream stream) if (isValid(udpConfigReg));
            dataStreamBuf.enq(stream);
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

