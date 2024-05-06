import GetPut :: *;
import FIFOF :: *;

import Ports :: *;
import EthUtils :: *;
import MacLayer :: *;
import UdpIpLayer :: *;
import EthernetTypes :: *;
import StreamHandler :: *;
import PortConversion :: *;
import UdpIpLayerForRdma :: *;

import SemiFifo :: *;
import AxiStreamTypes :: *;

interface UdpIpEthTx;
    interface Put#(UdpConfig) udpConfig;
    interface Put#(UdpIpMetaData) udpIpMetaDataIn;
    interface Put#(MacMetaData) macMetaDataIn;
    interface Put#(DataStream) dataStreamIn;
    interface AxiStreamLocalFifoOut axiStreamOut;
endinterface

module mkGenericUdpIpEthTx#(Bool isSupportRdma)(UdpIpEthTx);
    FIFOF#(   DataStream) dataStreamInBuf <- mkFIFOF;
    FIFOF#(UdpIpMetaData) udpIpMetaDataInBuf <- mkFIFOF;
    FIFOF#(  MacMetaData) macMetaDataInBuf <- mkFIFOF;
    
    Reg#(Maybe#(UdpConfig)) udpConfigReg <- mkReg(Invalid);
    let udpConfigVal = fromMaybe(?, udpConfigReg);
    
    DataStreamFifoOut udpIpStream = ?;
    if (isSupportRdma) begin
        udpIpStream <- mkUdpIpStreamForRdma(
            convertFifoToFifoOut(udpIpMetaDataInBuf),
            convertFifoToFifoOut(dataStreamInBuf),
            udpConfigVal
        );
    end
    else begin
        udpIpStream <- mkUdpIpStream(
            udpConfigVal,
            convertFifoToFifoOut(dataStreamInBuf),
            convertFifoToFifoOut(udpIpMetaDataInBuf),
            genUdpIpHeader
        );
    end

    DataStreamFifoOut macStream <- mkMacStream(
        udpIpStream, 
        convertFifoToFifoOut(macMetaDataInBuf), 
        udpConfigVal
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

    interface FifoOut axiStreamOut = convertDataStreamToAxiStream(macStream);
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
    interface RawAxiStreamLocalMaster rawAxiStreamOut;
endinterface

module mkGenericRawUdpIpEthTx#(Bool isSupportRdma)(RawUdpIpEthTx);
    UdpIpEthTx udpIpEthTx <- mkGenericUdpIpEthTx(isSupportRdma);

    let rawUdpConfigBus <- mkRawUdpConfigBusSlave(udpIpEthTx.udpConfig);
    let rawUdpIpMetaDataBus <- mkRawUdpIpMetaDataBusSlave(udpIpEthTx.udpIpMetaDataIn);
    let rawMacMetaDataBus <- mkRawMacMetaDataBusSlave(udpIpEthTx.macMetaDataIn);
    let rawDataStreamBus <- mkRawDataStreamBusSlave(udpIpEthTx.dataStreamIn);
    
    let rawAxiStreamBus <- mkFifoOutToRawAxiStreamMaster(udpIpEthTx.axiStreamOut);

    interface rawUdpConfig = rawUdpConfigBus;
    interface rawUdpIpMetaDataIn = rawUdpIpMetaDataBus;
    interface rawMacMetaDataIn = rawMacMetaDataBus;
    interface rawDataStreamIn = rawDataStreamBus;
    interface rawAxiStreamOut = rawAxiStreamBus;
endmodule


(* synthesize *)
module mkRawUdpIpEthTx(RawUdpIpEthTx);
    let rawUdpIpEth <- mkGenericRawUdpIpEthTx(`IS_SUPPORT_RDMA);
    return rawUdpIpEth;
endmodule
