import GetPut::*;
import FIFOF::*;
import Connectable :: *;

import SemiFifo :: *;
import UdpIpLayer::*;
import MacLayer::*;
import Ports::*;
import PortConversion :: *;
import EthernetTypes::*;
import Utils::*;
import AxiStreamTypes :: *;
import BusConversion :: *;

interface UdpIpEthRx;
    interface Put#(UdpConfig) udpConfig;
    
    interface Put#(AxiStream512) axiStreamIn;
    
    interface MacMetaDataPipeOut macMetaDataOut;
    interface UdpIpMetaDataPipeOut udpIpMetaDataOut;
    interface DataStreamPipeOut  dataStreamOut;
endinterface

(* synthesize *)
module mkUdpIpEthRx (UdpIpEthRx);
    FIFOF#(AxiStream512) axiStreamInBuf <- mkFIFOF;
    
    Reg#(Maybe#(UdpConfig)) udpConfigReg <- mkReg(Invalid);
    let udpConfigVal = fromMaybe(?, udpConfigReg);

    DataStreamPipeOut macStream <- mkAxiStreamToDataStream(
        convertFifoToPipeOut(axiStreamInBuf)
    );

    MacMetaDataAndUdpIpStream macMetaAndUdpIpStream <- mkMacStreamExtractor(
        macStream, 
        udpConfigVal
    );

    UdpIpMetaDataAndDataStream udpIpMetaAndDataStream <- mkUdpIpStreamExtractor(
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


interface RawUdpIpEthRx;
    (* prefix = "s_udp_config" *) 
    interface RawUdpConfigBusSlave rawUdpConfig;
    (* prefix = "s_axis" *) 
    interface RawAxiStreamSlave#(AXIS_TKEEP_WIDTH, AXIS_TUSER_WIDTH) rawAxiStreamIn;
    
    (* prefix = "m_mac_meta" *) 
    interface RawMacMetaDataBusMaster rawMacMetaDataOut;
    (* prefix = "m_udp_meta" *)
    interface RawUdpIpMetaDataBusMaster rawUdpIpMetaDataOut;
    (* prefix = "m_data_stream" *)
    interface RawDataStreamBusMaster rawDataStreamOut;
endinterface

module mkRawUdpIpEthRx(RawUdpIpEthRx);
    UdpIpEthRx udpIpEthRx <- mkUdpIpEthRx;

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

