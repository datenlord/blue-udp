import FIFOF :: *;
import GetPut :: *;
import BRAMFIFO :: *;
import Connectable :: *;

// import Utils :: *;
import EthUtils :: *;
import Ports :: *;
import ArpCache :: *;
import MacLayer :: *;
import UdpIpLayer :: *;
import ArpProcessor :: *;
import EthernetTypes :: *;
import StreamHandler :: *;
import PortConversion :: *;
import UdpIpLayerForRdma :: *;
//import XilinxCmacRxTxWrapper :: *;

import SemiFifo :: *;
import AxiStreamTypes :: *;
import BusConversion :: *;

interface UdpIpArpEthRxTx;
    interface Put#(UdpConfig) udpConfig;
    
    // Tx
    interface Put#(UdpIpMetaData) udpIpMetaDataTxIn;
    interface Put#(DataStream)    dataStreamTxIn;
    interface AxiStream256PipeOut axiStreamTxOut;
    
    // Rx
    interface Put#(AxiStream256)   axiStreamRxIn;
    interface UdpIpMetaDataPipeOut udpIpMetaDataRxOut;
    interface DataStreamPipeOut    dataStreamRxOut;
endinterface

typedef enum{
    INIT, IP, ARP
} MuxState deriving(Bits, Eq);
typedef MuxState DemuxState;

module mkGenericUdpIpArpEthRxTx#(Bool isSupportRdma)(UdpIpArpEthRxTx);
    Reg#(Maybe#(UdpConfig)) udpConfigReg <- mkReg(Invalid);
    let udpConfigVal = fromMaybe(?, udpConfigReg);

    // buffer of input ports
    FIFOF#(UdpIpMetaData) udpMetaDataTxBuf <- mkSizedFIFOF(valueOf(CACHE_CBUF_SIZE));
    FIFOF#(UdpIpMetaData) arpMetaDataTxBuf <- mkFIFOF;
    FIFOF#(DataStream)  dataStreamTxInBuf <- mkFIFOF;
    FIFOF#(AxiStream256)   axiStreamRxInBuf <- mkFIFOF;

    // state elements of Tx datapath
    Reg#(MuxState) muxState <- mkReg(INIT);
    FIFOF#(DataStream) macPayloadTxBuf <- mkFIFOF;
    FIFOF#(MacMetaData) macMetaDataTxBuf <- mkFIFOF;

    // state elements of Rx datapath
    Reg#(DemuxState) demuxState <- mkReg(INIT); 
    FIFOF#(DataStream) ipUdpStreamRxBuf <- mkFIFOF;
    FIFOF#(DataStream) arpStreamRxBuf <- mkFIFOF;

    // Arp Processor
    ArpProcessor arpProcessor <- mkArpProcessor(
        convertFifoToPipeOut(arpStreamRxBuf),
        convertFifoToPipeOut(arpMetaDataTxBuf)
    );

    // Tx datapath
    DataStreamPipeOut udpIpStreamTx = ?;
    if (isSupportRdma) begin
        udpIpStreamTx <- mkUdpIpStreamForRdma(
            convertFifoToPipeOut(udpMetaDataTxBuf),
            convertFifoToPipeOut(dataStreamTxInBuf),
            udpConfigVal
        );
    end
    else begin
        udpIpStreamTx <- mkUdpIpStream(
            udpConfigVal,
            convertFifoToPipeOut(dataStreamTxInBuf),
            convertFifoToPipeOut(udpMetaDataTxBuf),
            genUdpIpHeader
        );
    end

    rule doMux;
        if (muxState == INIT) begin
            let macMeta = arpProcessor.macMetaDataOut.first;
            arpProcessor.macMetaDataOut.deq;
            macMetaDataTxBuf.enq(macMeta);
            if (macMeta.ethType == fromInteger(valueOf(ETH_TYPE_ARP))) begin
                muxState <= ARP;
            end
            else if (macMeta.ethType == fromInteger(valueOf(ETH_TYPE_IP))) begin
                muxState <= IP;
            end
        end
        else if (muxState == IP) begin
            let ipUdpStream = udpIpStreamTx.first;
            udpIpStreamTx.deq;
            macPayloadTxBuf.enq(ipUdpStream);
            if (ipUdpStream.isLast) begin
                muxState <= INIT;
            end
        end
        else if (muxState == ARP) begin
            let arpStream = arpProcessor.arpStreamOut.first;
            arpProcessor.arpStreamOut.deq;
            macPayloadTxBuf.enq(arpStream);
            if (arpStream.isLast) begin
                muxState <= INIT;
            end           
        end

    endrule

    DataStreamPipeOut macStreamTx <- mkMacStream(
        convertFifoToPipeOut(macPayloadTxBuf), 
        convertFifoToPipeOut(macMetaDataTxBuf), 
        udpConfigVal
    );
    AxiStream256PipeOut macAxiStreamOut = convertDataStreamToAxiStream256(macStreamTx);

    // Rx Datapath
    DataStreamPipeOut macStreamRx <- mkAxiStream256ToDataStream(
        convertFifoToPipeOut(axiStreamRxInBuf)
    );

    MacMetaDataAndUdpIpStream macMetaAndUdpIpStream <- mkMacMetaDataAndUdpIpStream(
        macStreamRx, 
        udpConfigVal
    );

    rule doDemux;
        if (demuxState == INIT) begin
            let macMeta = macMetaAndUdpIpStream.macMetaDataOut.first;
            macMetaAndUdpIpStream.macMetaDataOut.deq;
            if (macMeta.ethType == fromInteger(valueOf(ETH_TYPE_ARP))) begin
                demuxState <= ARP;
            end
            else if (macMeta.ethType == fromInteger(valueOf(ETH_TYPE_IP))) begin
                demuxState <= IP;
            end
        end
        else if (demuxState == IP) begin
            let udpIpStream = macMetaAndUdpIpStream.udpIpStreamOut.first;
            macMetaAndUdpIpStream.udpIpStreamOut.deq;
            ipUdpStreamRxBuf.enq(udpIpStream);
            if (udpIpStream.isLast) begin
                demuxState <= INIT;
            end
        end
        else if (demuxState == ARP) begin
            let udpIpStream = macMetaAndUdpIpStream.udpIpStreamOut.first;
            macMetaAndUdpIpStream.udpIpStreamOut.deq;
            arpStreamRxBuf.enq(udpIpStream);
            if (udpIpStream.isLast) begin
                demuxState <= INIT;
            end 
        end
    endrule

    UdpIpMetaDataAndDataStream udpIpMetaAndDataStream;
    if (isSupportRdma) begin
        udpIpMetaAndDataStream <- mkUdpIpMetaDataAndDataStreamForRdma(
            convertFifoToPipeOut(ipUdpStreamRxBuf),
            udpConfigVal
        );
    end
    else begin
        udpIpMetaAndDataStream <- mkUdpIpMetaDataAndDataStream(
            udpConfigVal,
            convertFifoToPipeOut(ipUdpStreamRxBuf),
            extractUdpIpMetaData
        );
    end


    // Udp Config Interface
    interface Put udpConfig;
        method Action put(UdpConfig conf);
            udpConfigReg <= tagged Valid conf;
            arpProcessor.udpConfig.put(conf);
        endmethod
    endinterface

    // Tx interface
    interface Put udpIpMetaDataTxIn;
        method Action put(UdpIpMetaData meta) if (isValid(udpConfigReg));
            // generate ip packet
            udpMetaDataTxBuf.enq(meta);
            // mac address resolution request
            arpMetaDataTxBuf.enq(meta);
        endmethod
    endinterface
    interface Put dataStreamTxIn;
        method Action put(DataStream stream) if (isValid(udpConfigReg));
            dataStreamTxInBuf.enq(stream);
        endmethod
    endinterface
    interface PipeOut axiStreamTxOut = convertDataStreamToAxiStream256(macStreamTx);

    // Rx interface
    interface Put axiStreamRxIn;
        method Action put(AxiStream256 stream) if (isValid(udpConfigReg));
            axiStreamRxInBuf.enq(stream);
        endmethod
    endinterface
    interface PipeOut udpIpMetaDataRxOut = udpIpMetaAndDataStream.udpIpMetaDataOut;
    interface PipeOut dataStreamRxOut  = udpIpMetaAndDataStream.dataStreamOut;
endmodule


interface RawUdpIpArpEthRxTx;
    (* prefix = "s_udp_config" *)
    interface RawUdpConfigBusSlave rawUdpConfig;
    // Tx
    (* prefix = "s_udp_meta" *)
    interface RawUdpIpMetaDataBusSlave rawUdpIpMetaDataTxIn;
    (* prefix = "s_data_stream" *)
    interface RawDataStreamBusSlave rawDataStreamTxIn;
    (* prefix = "m_axi_stream" *)
    interface RawAxiStreamMaster#(AXIS256_TKEEP_WIDTH, AXIS_TUSER_WIDTH) rawAxiStreamTxOut;
    
    // Rx
    (* prefix = "m_udp_meta" *)
    interface RawUdpIpMetaDataBusMaster rawUdpIpMetaDataRxOut;
    (* prefix = "m_data_stream" *)
    interface RawDataStreamBusMaster rawDataStreamRxOut;
    (* prefix = "s_axi_stream" *)
    interface RawAxiStreamSlave#(AXIS256_TKEEP_WIDTH, AXIS_TUSER_WIDTH) rawAxiStreamRxIn;
endinterface


module mkGenericRawUdpIpArpEthRxTx#(Bool isSupportRdma)(RawUdpIpArpEthRxTx);
    UdpIpArpEthRxTx udpRxTx <- mkGenericUdpIpArpEthRxTx(isSupportRdma);

    let rawConfig <- mkRawUdpConfigBusSlave(udpRxTx.udpConfig);
    let rawUdpIpMetaDataTx <- mkRawUdpIpMetaDataBusSlave(udpRxTx.udpIpMetaDataTxIn);
    let rawDataStreamTx <- mkRawDataStreamBusSlave(udpRxTx.dataStreamTxIn);
    let rawAxiStreamTx <- mkPipeOutToRawAxiStreamMaster(udpRxTx.axiStreamTxOut);

    let rawUdpIpMetaDataRx <- mkRawUdpIpMetaDataBusMaster(udpRxTx.udpIpMetaDataRxOut);
    let rawDataStreamRx <- mkRawDataStreamBusMaster(udpRxTx.dataStreamRxOut);
    let rawAxiStreamRx <- mkPutToRawAxiStreamSlave(udpRxTx.axiStreamRxIn, CF);

    interface rawUdpConfig = rawConfig;

    interface rawUdpIpMetaDataTxIn = rawUdpIpMetaDataTx;
    interface rawDataStreamTxIn = rawDataStreamTx;
    interface rawAxiStreamTxOut = rawAxiStreamTx;

    interface rawUdpIpMetaDataRxOut = rawUdpIpMetaDataRx;
    interface rawDataStreamRxOut = rawDataStreamRx;
    interface rawAxiStreamRxIn = rawAxiStreamRx;
endmodule

(* synthesize *)
module mkRawUdpIpArpEthRxTx(RawUdpIpArpEthRxTx);
    let rawUdpIpArpEthRxTx <- mkGenericRawUdpIpArpEthRxTx(`IS_SUPPORT_RDMA);
    return rawUdpIpArpEthRxTx;
endmodule

