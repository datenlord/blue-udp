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

interface UdpEthRx;
    interface Put#(UdpConfig) udpConfig;
    
    interface Put#(AxiStream512) axiStreamIn;
    
    interface MacMetaDataPipeOut macMetaDataOut;
    interface UdpIpMetaDataPipeOut udpIpMetaDataOut;
    interface DataStreamPipeOut  dataStreamOut;
endinterface

(* synthesize *)
module mkUdpEthRx (UdpEthRx);
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


interface RawUdpEthRx;
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

module mkRawUdpEthRx(RawUdpEthRx);
    UdpEthRx udpEthRx <- mkUdpEthRx;

    let rawUdpConfigBus <- mkRawUdpConfigBusSlave(udpEthRx.udpConfig);
    let rawMacMetaDataBus <- mkRawMacMetaDataBusMaster(udpEthRx.macMetaDataOut);
    let rawUdpIpMetaDataBus <- mkRawUdpIpMetaDataBusMaster(udpEthRx.udpIpMetaDataOut);
    let rawDataStreamBus <- mkRawDataStreamBusMaster(udpEthRx.dataStreamOut);
    let rawAxiStreamBus <- mkPutToRawAxiStreamSlave(udpEthRx.axiStreamIn, CF);

    interface rawUdpConfig = rawUdpConfigBus;
    interface rawAxiStreamIn = rawAxiStreamBus;
    interface rawMacMetaDataOut = rawMacMetaDataBus;
    interface rawUdpIpMetaDataOut = rawUdpIpMetaDataBus;
    interface rawDataStreamOut = rawDataStreamBus;
endmodule

