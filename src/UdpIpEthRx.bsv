import FIFOF :: *;
import GetPut :: *;
import Connectable :: *;

import Ports :: *;
import EthUtils :: *;
import MacLayer :: *;
import UdpIpLayer :: *;
import StreamHandler :: *;
import EthernetTypes :: *;
import PortConversion :: *;
import UdpIpLayerForRdma :: *;

import SemiFifo :: *;
import AxiStreamTypes :: *;
import BusConversion :: *;

interface UdpIpEthRx;
    interface Put#(UdpConfig) udpConfig;
    
    interface Put#(AxiStreamLocal) axiStreamIn;
    
    interface MacMetaDataFifoOut macMetaDataOut;
    interface UdpIpMetaDataFifoOut udpIpMetaDataOut;
    interface DataStreamFifoOut  dataStreamOut;
endinterface

module mkGenericUdpIpEthRx#(Bool isSupportRdma)(UdpIpEthRx);
    FIFOF#(AxiStreamLocal) axiStreamInBuf <- mkFIFOF;
    
    Reg#(Maybe#(UdpConfig)) udpConfigReg <- mkReg(Invalid);
    let udpConfigVal = fromMaybe(?, udpConfigReg);

    let macStream <- mkAxiStreamToDataStream(
        convertFifoToFifoOut(axiStreamInBuf)
    );

    let macMetaAndUdpIpStream <- mkMacMetaDataAndUdpIpStream(
        macStream, 
        udpConfigVal
    );

    UdpIpMetaDataAndDataStream udpIpMetaAndDataStream;
    if (isSupportRdma) begin
        udpIpMetaAndDataStream <- mkUdpIpMetaDataAndDataStreamForRdma(
            macMetaAndUdpIpStream.udpIpStreamOut,
            udpConfigVal
        );
    end
    else begin
        udpIpMetaAndDataStream <- mkUdpIpMetaDataAndDataStream(
            udpConfigVal,
            macMetaAndUdpIpStream.udpIpStreamOut,
            extractUdpIpMetaData
        );
    end

    interface Put udpConfig;
        method Action put(UdpConfig conf);
            udpConfigReg <= tagged Valid conf;
        endmethod
    endinterface

    interface Put axiStreamIn;
        method Action put(AxiStreamLocal stream) if (isValid(udpConfigReg));
            axiStreamInBuf.enq(stream);
        endmethod
    endinterface

    interface FifoOut macMetaDataOut = macMetaAndUdpIpStream.macMetaDataOut;
    interface FifoOut udpIpMetaDataOut = udpIpMetaAndDataStream.udpIpMetaDataOut;
    interface FifoOut dataStreamOut = udpIpMetaAndDataStream.dataStreamOut;
endmodule

interface RawUdpIpEthRx;
    (* prefix = "s_udp_config" *) 
    interface RawUdpConfigBusSlave rawUdpConfig;
    (* prefix = "s_axis" *) 
    interface RawAxiStreamLocalSlave rawAxiStreamIn;
    
    (* prefix = "m_mac_meta" *)
    interface RawMacMetaDataBusMaster rawMacMetaDataOut;
    (* prefix = "m_udp_meta" *)
    interface RawUdpIpMetaDataBusMaster rawUdpIpMetaDataOut;
    (* prefix = "m_data_stream" *)
    interface RawDataStreamBusMaster rawDataStreamOut;
endinterface

module mkGenericRawUdpIpEthRx#(Bool isSupportRdma)(RawUdpIpEthRx);
    UdpIpEthRx udpIpEthRx <- mkGenericUdpIpEthRx(isSupportRdma);

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

(* synthesize *)
module mkRawUdpIpEthRx(RawUdpIpEthRx);
    let rawUdpIpEthRx <- mkGenericRawUdpIpEthRx(`IS_SUPPORT_RDMA);
    return rawUdpIpEthRx;
endmodule
