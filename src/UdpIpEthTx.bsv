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
    interface AxiStream256FifoOut axiStreamOut;
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

    interface FifoOut axiStreamOut = convertDataStreamToAxiStream256(macStream);
endmodule

interface UdpIpEthBypassTx;
    interface Put#(UdpConfig) udpConfig;
    interface Put#(UdpIpMetaData) udpIpMetaDataIn;
    interface Put#(MacMetaDataWithBypassTag) macMetaDataIn;
    interface Put#(DataStream) dataStreamIn;
    interface AxiStream512FifoOut axiStreamOut;
endinterface

module mkGenericUdpIpEthBypassTx#(Bool isSupportRdma)(UdpIpEthBypassTx);

    Reg#(Maybe#(UdpConfig)) udpConfigReg <- mkReg(Invalid);
    let udpConfigVal = fromMaybe(?, udpConfigReg);

    FIFOF#(DataStream) dataStreamInBuf <- mkFIFOF;
    FIFOF#(UdpIpMetaData) udpIpMetaDataInBuf <- mkFIFOF;
    FIFOF#(MacMetaData) macMetaDataInBuf <- mkFIFOF;

    FIFOF#(Bool) isForkBypassChannelBuf <- mkFIFOF;
    FIFOF#(Bool) isJoinBypassChannelBuf <- mkFIFOF;
    FIFOF#(DataStream) dataStreamInterBuf <- mkFIFOF;
    FIFOF#(DataStream) rawPktStreamInterBuf <- mkFIFOF;
    FIFOF#(DataStream) macPayloadStreamInterBuf <- mkFIFOF;

    rule forkDataStream if (isForkBypassChannelBuf.notEmpty);
        let dataStream = dataStreamInBuf.first;
        dataStreamInBuf.deq;

        if (isForkBypassChannelBuf.first) begin
            rawPktStreamInterBuf.enq(dataStream);
        end
        else begin
            dataStreamInterBuf.enq(dataStream);
        end
        if (dataStream.isLast) begin
            isForkBypassChannelBuf.deq;
        end
    endrule

    
    DataStreamFifoOut udpIpStream = ?;
    if (isSupportRdma) begin
        udpIpStream <- mkUdpIpStreamForRdma(
            convertFifoToFifoOut(udpIpMetaDataInBuf),
            convertFifoToFifoOut(dataStreamInterBuf),
            udpConfigVal
        );
    end
    else begin
        udpIpStream <- mkUdpIpStream(
            udpConfigVal,
            convertFifoToFifoOut(dataStreamInterBuf),
            convertFifoToFifoOut(udpIpMetaDataInBuf),
            genUdpIpHeader
        );
    end

    rule joinDataStream if (isJoinBypassChannelBuf.notEmpty);
        DataStream dataStream;

        if (isJoinBypassChannelBuf.first) begin
            dataStream = rawPktStreamInterBuf.first;
            rawPktStreamInterBuf.deq;
        end
        else begin
            dataStream = udpIpStream.first;
            udpIpStream.deq;
        end
        if (dataStream.isLast) begin
            isJoinBypassChannelBuf.deq;
        end
        macPayloadStreamInterBuf.enq(dataStream);
    endrule

    DataStreamFifoOut macStream <- mkMacStream(
        convertFifoToFifoOut(macPayloadStreamInterBuf), 
        convertFifoToFifoOut(macMetaDataInBuf), 
        udpConfigVal
    );
    let macAxiStream <- mkDoubleAxiStreamFifoOut(convertDataStreamToAxiStream256(macStream));

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
        method Action put(MacMetaDataWithBypassTag macMetaAndTag) if (isValid(udpConfigReg));
            macMetaDataInBuf.enq(macMetaAndTag.macMetaData);
            isForkBypassChannelBuf.enq(macMetaAndTag.isBypass);
            isJoinBypassChannelBuf.enq(macMetaAndTag.isBypass);
        endmethod
    endinterface
    interface FifoOut axiStreamOut = macAxiStream;
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
    interface RawAxiStreamMaster#(AXIS256_TKEEP_WIDTH, AXIS_TUSER_WIDTH) rawAxiStreamOut;
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





