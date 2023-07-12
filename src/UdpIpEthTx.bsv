import GetPut :: *;
import FIFOF :: *;

import Ports :: *;
import Utils :: *;
import MacLayer :: *;
import UdpIpLayer :: *;
import PortConversion :: *;
import EthernetTypes :: *;

import SemiFifo :: *;
import AxiStreamTypes :: *;

interface UdpIpEthTx;
    interface Put#(UdpConfig) udpConfig;
    interface Put#(UdpIpMetaData) udpIpMetaDataIn;
    interface Put#(MacMetaData) macMetaDataIn;
    interface Put#(DataStream) dataStreamIn;
    interface AxiStream512PipeOut axiStreamOut;
endinterface

(* synthesize *)
module mkUdpIpEthTx(UdpIpEthTx);
    FIFOF#( DataStream) dataStreamInBuf <- mkFIFOF;
    FIFOF#(UdpIpMetaData) udpIpMetaDataInBuf <- mkFIFOF;
    FIFOF#(MacMetaData) macMetaDataInBuf <- mkFIFOF;
    
    Reg#(Maybe#(UdpConfig)) udpConfigReg <- mkReg(Invalid);
    let udpConfigVal = fromMaybe(?, udpConfigReg);
    
    DataStreamPipeOut ipUdpStream <- mkUdpIpStream(
        genUdpIpHeader,
        convertFifoToPipeOut(udpIpMetaDataInBuf),
        convertFifoToPipeOut(dataStreamInBuf),
        udpConfigVal
    );

    DataStreamPipeOut macStream <- mkMacStream(
        ipUdpStream, 
        convertFifoToPipeOut(macMetaDataInBuf), 
        udpConfigVal
    );

    AxiStream512PipeOut macAxiStream <- mkDataStreamToAxiStream512(
        macStream
    );

    interface Put udpConfig;
        method Action put(UdpConfig conf);
            udpConfigReg <= tagged Valid conf;
        endmethod
    endinterface

    interface Put udpIpMetaDataIn;
        method Action put(UdpIpMetaData udpIpMeta) if (isValid(udpConfigReg));
            udpIpMetaDataInBuf.enq(udpIpMeta);
        endmethod
    endinterface

    interface Put dataStreamIn;
        method Action put(DataStream stream) if (isValid(udpConfigReg));
            dataStreamInBuf.enq(stream);
        endmethod
    endinterface

    interface Put macMetaDataIn;
        method Action put(MacMetaData macMeta) if (isValid(udpConfigReg));
            macMetaDataInBuf.enq(macMeta);
        endmethod
    endinterface

    interface PipeOut axiStreamOut = macAxiStream;
endmodule


interface RawUdpIpEthTx;
    (* prefix = "s_udp_config" *)
    interface RawUdpConfigBusSlave rawUdpConfig;
    (* prefix = "s_udp_meta" *)
    interface RawUdpIpMetaDataBusSlave rawUdpIpMetaDataIn;
    (* prefix = "s_mac_meta" *)
    interface RawMacMetaDataBusSlave rawMacMetaDataIn;
    (* prefix = "s_data_stream" *)
    interface RawDataStreamBusSlave rawDataStreamIn;
    
    (* prefix = "m_axis" *)
    interface RawAxiStreamMaster#(AXIS_TKEEP_WIDTH, AXIS_TUSER_WIDTH) rawAxiStreamOut;
endinterface

module mkRawUdpIpEthTx(RawUdpIpEthTx);
    UdpIpEthTx udpIpEthTx <- mkUdpIpEthTx;

    let rawUdpConfigBus <- mkRawUdpConfigBusSlave(udpIpEthTx.udpConfig);
    let rawUdpIpMetaDataBus <- mkRawUdpIpMetaDataBusSlave(udpIpEthTx.udpIpMetaDataIn);
    let rawMacMetaDataBus <- mkRawMacMetaDataBusSlave(udpIpEthTx.macMetaDataIn);
    let rawDataStreamBus <- mkRawDataStreamBusSlave(udpIpEthTx.dataStreamIn);
    
    let rawAxiStreamBus <- mkPipeOutToRawAxiStreamMaster(udpIpEthTx.axiStreamOut);

    interface rawUdpConfig = rawUdpConfigBus;
    interface rawUdpIpMetaDataIn = rawUdpIpMetaDataBus;
    interface rawMacMetaDataIn = rawMacMetaDataBus;
    interface rawDataStreamIn = rawDataStreamBus;
    interface rawAxiStreamOut = rawAxiStreamBus;
endmodule


