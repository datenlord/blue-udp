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

interface UdpEthTx;
    interface Put#(UdpConfig) udpConfig;
    interface Put#(UdpIpMetaData) udpIpMetaDataIn;
    interface Put#(MacMetaData) macMetaDataIn;
    interface Put#(DataStream) dataStreamIn;
    interface AxiStream512PipeOut axiStreamOut;
endinterface

(* synthesize *)
module mkUdpEthTx (UdpEthTx);
    FIFOF#( DataStream) dataStreamInBuf <- mkFIFOF;
    FIFOF#(UdpIpMetaData) udpIpMetaDataInBuf <- mkFIFOF;
    FIFOF#(MacMetaData) macMetaDataInBuf <- mkFIFOF;
    
    Reg#(Maybe#(UdpConfig)) udpConfigReg <- mkReg(Invalid);
    let udpConfigVal = fromMaybe(?, udpConfigReg);
    
    DataStreamPipeOut ipUdpStream <- mkUdpIpStreamGenerator(
        convertFifoToPipeOut(udpIpMetaDataInBuf),
        convertFifoToPipeOut(dataStreamInBuf),
        udpConfigVal
    );

    DataStreamPipeOut macStream <- mkMacStreamGenerator(
        ipUdpStream, 
        convertFifoToPipeOut(macMetaDataInBuf), 
        udpConfigVal
    );

    AxiStream512PipeOut macAxiStream <- mkDataStreamToAxiStream(
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


interface RawUdpEthTx;
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

module mkRawUdpEthTx(RawUdpEthTx);
    UdpEthTx udpEthTx <- mkUdpEthTx;

    let rawUdpConfigBus <- mkRawUdpConfigBusSlave(udpEthTx.udpConfig);
    let rawUdpIpMetaDataBus <- mkRawUdpIpMetaDataBusSlave(udpEthTx.udpIpMetaDataIn);
    let rawMacMetaDataBus <- mkRawMacMetaDataBusSlave(udpEthTx.macMetaDataIn);
    let rawDataStreamBus <- mkRawDataStreamBusSlave(udpEthTx.dataStreamIn);
    
    let rawAxiStreamBus <- mkPipeOutToRawAxiStreamMaster(udpEthTx.axiStreamOut);

    interface rawUdpConfig = rawUdpConfigBus;
    interface rawUdpIpMetaDataIn = rawUdpIpMetaDataBus;
    interface rawMacMetaDataIn = rawMacMetaDataBus;
    interface rawDataStreamIn = rawDataStreamBus;
    interface rawAxiStreamOut = rawAxiStreamBus;
endmodule


