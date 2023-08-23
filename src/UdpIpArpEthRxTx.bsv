import FIFOF :: *;
import GetPut :: *;
import Clocks :: *;
import BRAMFIFO :: *;
import Connectable :: *;

import Utils :: *;
import Ports :: *;
import ArpCache :: *;
import MacLayer :: *;
import UdpIpLayer :: *;
import ArpProcessor :: *;
import EthernetTypes :: *;
import PortConversion :: *;
import PriorityFlowControl :: *;
import XilinxCmacRxTxWrapper :: *;

import SemiFifo :: *;
import AxiStreamTypes :: *;
import BusConversion :: *;

interface UdpIpArpEthRxTx;
    interface Put#(UdpConfig)  udpConfig;
    
    // Tx
    interface Put#(UdpIpMetaData) udpIpMetaDataInTx;
    interface Put#(DataStream)    dataStreamInTx;
    interface AxiStream512PipeOut axiStreamOutTx;
    
    // Rx
    interface Put#(AxiStream512)   axiStreamInRx;
    interface UdpIpMetaDataPipeOut udpIpMetaDataOutRx;
    interface DataStreamPipeOut    dataStreamOutRx;
endinterface

typedef enum{
    INIT, IP, ARP
} MuxState deriving(Bits, Eq);
typedef MuxState DemuxState;

(* synthesize *)
module mkUdpIpArpEthRxTx(UdpIpArpEthRxTx);
    Reg#(Maybe#(UdpConfig)) udpConfigReg <- mkReg(Invalid);
    let udpConfigVal = fromMaybe(?, udpConfigReg);

    // buffer of input ports
    FIFOF#(UdpIpMetaData) udpMetaDataTxBuf <- mkSizedFIFOF(valueOf(CACHE_CBUF_SIZE));
    FIFOF#(UdpIpMetaData) arpMetaDataTxBuf <- mkFIFOF;
    FIFOF#(DataStream)  dataStreamInTxBuf <- mkFIFOF;
    FIFOF#(AxiStream512)   axiStreamInRxBuf <- mkFIFOF;

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
    DataStreamPipeOut ipUdpStreamTx <- mkUdpIpStream(
        udpConfigVal,
        convertFifoToPipeOut(dataStreamInTxBuf),
        convertFifoToPipeOut(udpMetaDataTxBuf),
        genUdpIpHeader
    );

    rule doMux;
        if (muxState == INIT) begin
            let macMeta = arpProcessor.macMetaDataOut.first;
            arpProcessor.macMetaDataOut.deq;
            macMetaDataTxBuf.enq(macMeta);
            if (macMeta.ethType == fromInteger(valueOf(ETH_TYPE_ARP))) begin
                let arpStream = arpProcessor.arpStreamOut.first;
                arpProcessor.arpStreamOut.deq;
                macPayloadTxBuf.enq(arpStream);
                if (!arpStream.isLast) begin
                    muxState <= ARP;
                end
            end
            else if (macMeta.ethType == fromInteger(valueOf(ETH_TYPE_IP))) begin
                let ipUdpStream = ipUdpStreamTx.first;
                ipUdpStreamTx.deq;
                macPayloadTxBuf.enq(ipUdpStream);
                if (!ipUdpStream.isLast) begin
                    muxState <= IP;
                end
            end
        end
        else if (muxState == IP) begin
            let ipUdpStream = ipUdpStreamTx.first;
            ipUdpStreamTx.deq;
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
    AxiStream512PipeOut macAxiStreamOut <- mkDataStreamToAxiStream512(macStreamTx);

    // Rx Datapath
    DataStreamPipeOut macStreamRx <- mkAxiStream512ToDataStream(
        convertFifoToPipeOut(axiStreamInRxBuf)
    );

    MacMetaDataAndUdpIpStream macMetaAndUdpIpStream <- mkMacMetaDataAndUdpIpStream(
        macStreamRx, 
        udpConfigVal
    );

    rule doDemux;
        if (demuxState == INIT) begin
            let macMeta = macMetaAndUdpIpStream.macMetaDataOut.first;
            macMetaAndUdpIpStream.macMetaDataOut.deq;
            let udpIpStream = macMetaAndUdpIpStream.udpIpStreamOut.first;
            macMetaAndUdpIpStream.udpIpStreamOut.deq;

            if (macMeta.ethType == fromInteger(valueOf(ETH_TYPE_ARP))) begin
                arpStreamRxBuf.enq(udpIpStream);
                if (!udpIpStream.isLast) begin
                    demuxState <= ARP;
                end
            end
            else if (macMeta.ethType == fromInteger(valueOf(ETH_TYPE_IP))) begin
                ipUdpStreamRxBuf.enq(udpIpStream);
                if (!udpIpStream.isLast) begin
                    demuxState <= IP;
                end
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

    UdpIpMetaDataAndDataStream udpIpMetaDataAndDataStream <- mkUdpIpMetaDataAndDataStream(
        udpConfigVal,
        convertFifoToPipeOut(ipUdpStreamRxBuf),
        extractUdpIpMetaData
    );


    // Udp Config Interface
    interface Put udpConfig;
        method Action put(UdpConfig conf);
            udpConfigReg <= tagged Valid conf;
            arpProcessor.udpConfig.put(conf);
        endmethod
    endinterface

    // Tx interface
    interface Put udpIpMetaDataInTx;
        method Action put(UdpIpMetaData meta) if (isValid(udpConfigReg));
            // generate ip packet
            udpMetaDataTxBuf.enq(meta);
            // mac address resolution request
            arpMetaDataTxBuf.enq(meta);
        endmethod
    endinterface
    interface Put dataStreamInTx;
        method Action put(DataStream stream) if (isValid(udpConfigReg));
            dataStreamInTxBuf.enq(stream);
        endmethod
    endinterface
    interface PipeOut axiStreamOutTx = macAxiStreamOut;

    // Rx interface
    interface Put axiStreamInRx;
        method Action put(AxiStream512 stream) if (isValid(udpConfigReg));
            axiStreamInRxBuf.enq(stream);
        endmethod
    endinterface
    interface PipeOut udpIpMetaDataOutRx = udpIpMetaDataAndDataStream.udpIpMetaDataOut;
    interface PipeOut dataStreamOutRx  = udpIpMetaDataAndDataStream.dataStreamOut;

endmodule


interface RawUdpIpArpEthRxTx;
    interface RawUdpConfigBusSlave rawUdpConfig;
    // Tx
    interface RawUdpIpMetaDataBusSlave rawUdpIpMetaDataInTx;
    interface RawDataStreamBusSlave    rawDataStreamInTx;
    interface RawAxiStreamMaster#(AXIS_TKEEP_WIDTH, AXIS_TUSER_WIDTH) rawAxiStreamOutTx;
    // Rx
    interface RawUdpIpMetaDataBusMaster rawUdpIpMetaDataOutRx;
    interface RawDataStreamBusMaster    rawDataStreamOutRx;
    interface RawAxiStreamSlave#(AXIS_TKEEP_WIDTH, AXIS_TUSER_WIDTH) rawAxiStreamInRx;
endinterface


module mkRawUdpIpArpEthRxTx(RawUdpIpArpEthRxTx);
    UdpIpArpEthRxTx udpRxTx <- mkUdpIpArpEthRxTx;

    let rawConfig <- mkRawUdpConfigBusSlave(udpRxTx.udpConfig);
    let rawUdpIpMetaDataTx <- mkRawUdpIpMetaDataBusSlave(udpRxTx.udpIpMetaDataInTx);
    let rawDataStreamTx <- mkRawDataStreamBusSlave(udpRxTx.dataStreamInTx);
    let rawAxiStreamTx <- mkPipeOutToRawAxiStreamMaster(udpRxTx.axiStreamOutTx);

    let rawUdpIpMetaDataRx <- mkRawUdpIpMetaDataBusMaster(udpRxTx.udpIpMetaDataOutRx);
    let rawDataStreamRx <- mkRawDataStreamBusMaster(udpRxTx.dataStreamOutRx);
    let rawAxiStreamRx <- mkPutToRawAxiStreamSlave(udpRxTx.axiStreamInRx, CF);

    interface rawUdpConfig = rawConfig;

    interface rawUdpIpMetaDataInTx = rawUdpIpMetaDataTx;
    interface rawDataStreamInTx = rawDataStreamTx;
    interface rawAxiStreamOutTx = rawAxiStreamTx;

    interface rawUdpIpMetaDataOutRx = rawUdpIpMetaDataRx;
    interface rawDataStreamOutRx = rawDataStreamRx;
    interface rawAxiStreamInRx = rawAxiStreamRx;
endmodule

// UdpIpArpEthRxTx module with wrapper of Xilinx 100Gb CMAC IP
interface UdpIpArpEthCmacRxTx;
    // Interface with CMAC IP
    (* prefix = "" *)
    interface XilinxCmacRxTxWrapper cmacRxTxWrapper;
    
    // Configuration Interface
    interface Put#(UdpConfig)  udpConfig;
    
    // Tx
    interface Put#(UdpIpMetaData) udpIpMetaDataInTx;
    interface Put#(DataStream)    dataStreamInTx;

    // Rx
    interface UdpIpMetaDataPipeOut udpIpMetaDataOutRx;
    interface DataStreamPipeOut    dataStreamOutRx;
endinterface

module mkUdpIpArpEthCmacRxTx#(
    Bool isCmacTxWaitRxAligned,
    Integer syncBramBufDepth
)(
    Clock cmacRxTxClk,
    Reset cmacRxReset,
    Reset cmacTxReset,
    UdpIpArpEthCmacRxTx ifc
);
    let isEnableFlowControl = False;
    let currentClock <- exposeCurrentClock;
    let currentReset <- exposeCurrentReset;
    SyncFIFOIfc#(AxiStream512) txSyncBuf <- mkSyncBRAMFIFO(
        syncBramBufDepth,
        currentClock,
        currentReset,
        cmacRxTxClk,
        cmacTxReset
    );

    SyncFIFOIfc#(AxiStream512) rxSyncBuf <- mkSyncBRAMFIFO(
        syncBramBufDepth,
        cmacRxTxClk,
        cmacRxReset,
        currentClock,
        currentReset
    );

    PipeOut#(FlowControlReqVec) txFlowCtrlReqVec <- mkDummyPipeOut;
    PipeIn#(FlowControlReqVec) rxFlowCtrlReqVec <- mkDummyPipeIn;
    let cmacWrapper <- mkXilinxCmacRxTxWrapper(
        isEnableFlowControl,
        isCmacTxWaitRxAligned,
        convertSyncFifoToPipeOut(txSyncBuf),
        convertSyncFifoToPipeIn(rxSyncBuf),
        txFlowCtrlReqVec,
        rxFlowCtrlReqVec,
        cmacRxReset,
        cmacTxReset,
        clocked_by cmacRxTxClk
    );

    let udpIpArpEthRxTx <- mkUdpIpArpEthRxTx;
    mkConnection(convertSyncFifoToPipeIn(txSyncBuf), udpIpArpEthRxTx.axiStreamOutTx);
    mkConnection(toGet(convertSyncFifoToPipeOut(rxSyncBuf)), udpIpArpEthRxTx.axiStreamInRx);


    interface cmacRxTxWrapper = cmacWrapper;
    interface udpConfig = udpIpArpEthRxTx.udpConfig;
    interface udpIpMetaDataInTx = udpIpArpEthRxTx.udpIpMetaDataInTx;
    interface dataStreamInTx = udpIpArpEthRxTx.dataStreamInTx;
    interface udpIpMetaDataOutRx = udpIpArpEthRxTx.udpIpMetaDataOutRx;
    interface dataStreamOutRx = udpIpArpEthRxTx.dataStreamOutRx;
endmodule




