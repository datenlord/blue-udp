import FIFOF :: *;
import GetPut :: *;
import Vector :: *;
import Clocks :: *;
import Connectable :: *;
import BRAMFIFO :: *;

import Ports :: *;
import PortConversion :: *;
import EthernetTypes :: *;
import UdpIpArpEthRxTx :: *;
import XilinxCmacRxTxWrapper :: *;
import PriorityFlowControl :: *;

import SemiFifo :: *;
import BusConversion :: *;
import AxiStreamTypes :: *;

typedef 8 BUF_PKT_NUM;
typedef 64 MAX_PKT_FRAME_NUM;
typedef 3 PFC_THRESHOLD;

interface PfcUdpIpArpEthRxTx#(
    numeric type bufPacketNum, 
    numeric type maxPacketFrameNum,
    numeric type pfcThreshold
);
    // Udp Config
    interface Put#(UdpConfig) udpConfig;

    // Tx Channels
    interface AxiStream512PipeOut axiStreamOutTx;
    interface Vector#(VIRTUAL_CHANNEL_NUM, Put#(DataStream))    dataStreamInTxVec;
    interface Vector#(VIRTUAL_CHANNEL_NUM, Put#(UdpIpMetaData)) udpIpMetaDataInTxVec; 

    // Rx Channels
    interface Put#(AxiStream512)   axiStreamInRx;
    interface Vector#(VIRTUAL_CHANNEL_NUM, DataStreamPipeOut)    dataStreamOutRxVec;
    interface Vector#(VIRTUAL_CHANNEL_NUM, UdpIpMetaDataPipeOut) udpIpMetaDataOutRxVec;
        
    // PFC Request
    interface Put#(FlowControlReqVec) flowControlReqVecIn;
    interface PipeOut#(FlowControlReqVec) flowControlReqVecOut;

endinterface

module mkGenericPfcUdpIpArpEthRxTx#(Bool isSupportRdma)(PfcUdpIpArpEthRxTx#(bufPacketNum, maxPacketFrameNum, pfcThreshold))
    provisos(Add#(pfcThreshold, a__, bufPacketNum));

    FIFOF#(FlowControlReqVec) flowControlReqVecInBuf <- mkFIFOF;
    Vector#(VIRTUAL_CHANNEL_NUM, FIFOF#(UdpIpMetaData)) udpIpMetaDataInTxBufVec <- replicateM(mkFIFOF);
    Vector#(VIRTUAL_CHANNEL_NUM, FIFOF#(DataStream)) dataStreamInTxBufVec <- replicateM(mkFIFOF);

    let udpIpArpEthRxTx <- mkGenericUdpIpArpEthRxTx(isSupportRdma);

    let pfcTx <- mkPriorityFlowControlTx(
        convertFifoToPipeOut(flowControlReqVecInBuf),
        map(convertFifoToPipeOut, dataStreamInTxBufVec),
        map(convertFifoToPipeOut, udpIpMetaDataInTxBufVec)
    );
    mkConnection(pfcTx.udpIpMetaDataOut, udpIpArpEthRxTx.udpIpMetaDataInTx);
    mkConnection(pfcTx.dataStreamOut, udpIpArpEthRxTx.dataStreamInTx);

    PriorityFlowControlRx#(bufPacketNum, maxPacketFrameNum, pfcThreshold) pfcRx <- mkPriorityFlowControlRx(
        udpIpArpEthRxTx.dataStreamOutRx,
        udpIpArpEthRxTx.udpIpMetaDataOutRx
    );

    interface udpConfig = udpIpArpEthRxTx.udpConfig;

    interface axiStreamOutTx = udpIpArpEthRxTx.axiStreamOutTx;
    interface dataStreamInTxVec = map(toPut, dataStreamInTxBufVec);
    interface udpIpMetaDataInTxVec = map(toPut, udpIpMetaDataInTxBufVec);

    interface axiStreamInRx = udpIpArpEthRxTx.axiStreamInRx;
    interface dataStreamOutRxVec = pfcRx.dataStreamOutVec;
    interface udpIpMetaDataOutRxVec = pfcRx.udpIpMetaDataOutVec;

    interface flowControlReqVecIn = toPut(flowControlReqVecInBuf);
    interface flowControlReqVecOut = pfcRx.flowControlReqVecOut;
endmodule


interface RawPfcUdpIpArpEthRxTx;
    (* prefix = "s_udp_config" *)
    interface RawUdpConfigBusSlave rawUdpConfig;
    
    // Tx
    interface Vector#(VIRTUAL_CHANNEL_NUM, RawUdpIpMetaDataBusSlave) rawUdpIpMetaSlaveVec;
    interface Vector#(VIRTUAL_CHANNEL_NUM, RawDataStreamBusSlave) rawDataStreamSlaveVec;
    (* prefix = "m_axi_stream" *)
    interface RawAxiStreamMaster#(AXIS_TKEEP_WIDTH, AXIS_TUSER_WIDTH) rawAxiStreamOutTx;
    
    // Rx
    interface Vector#(VIRTUAL_CHANNEL_NUM, RawUdpIpMetaDataBusMaster) rawUdpIpMetaMasterVec;
    interface Vector#(VIRTUAL_CHANNEL_NUM, RawDataStreamBusMaster) rawDataStreamMasterVec;
    (* prefix = "s_axi_stream" *)
    interface RawAxiStreamSlave#(AXIS_TKEEP_WIDTH, AXIS_TUSER_WIDTH) rawAxiStreamInRx;
endinterface

module mkRawPfcUdpIpArpEthRxTx(RawPfcUdpIpArpEthRxTx);

    Vector#(VIRTUAL_CHANNEL_NUM, RawUdpIpMetaDataBusSlave) rawUdpIpMetaDataInTxVec;
    Vector#(VIRTUAL_CHANNEL_NUM, RawDataStreamBusSlave) rawDataStreamInTxVec;
    Vector#(VIRTUAL_CHANNEL_NUM, RawUdpIpMetaDataBusMaster) rawUdpIpMetaDataOutRxVec;
    Vector#(VIRTUAL_CHANNEL_NUM, RawDataStreamBusMaster) rawDataStreamOutRxVec;

    PfcUdpIpArpEthRxTx#(BUF_PKT_NUM, MAX_PKT_FRAME_NUM, PFC_THRESHOLD) pfcUdpIpArpEthRxTx <- mkGenericPfcUdpIpArpEthRxTx(`IS_SUPPORT_RDMA);
    let rawConfig <- mkRawUdpConfigBusSlave(pfcUdpIpArpEthRxTx.udpConfig);
    let rawAxiStreamTx <- mkPipeOutToRawAxiStreamMaster(pfcUdpIpArpEthRxTx.axiStreamOutTx);
    let rawAxiStreamRx <- mkPutToRawAxiStreamSlave(pfcUdpIpArpEthRxTx.axiStreamInRx, CF);

    for (Integer i = 0; i < valueOf(VIRTUAL_CHANNEL_NUM); i = i + 1) begin
        let rawUdpIpMetaInTx <- mkRawUdpIpMetaDataBusSlave(pfcUdpIpArpEthRxTx.udpIpMetaDataInTxVec[i]);
        let rawDataStreamInTx <- mkRawDataStreamBusSlave(pfcUdpIpArpEthRxTx.dataStreamInTxVec[i]);
        let rawUdpIpMetaOutRx <- mkRawUdpIpMetaDataBusMaster(pfcUdpIpArpEthRxTx.udpIpMetaDataOutRxVec[i]);
        let rawDataStreamOutRx <- mkRawDataStreamBusMaster(pfcUdpIpArpEthRxTx.dataStreamOutRxVec[i]);

        rawUdpIpMetaDataInTxVec[i] = rawUdpIpMetaInTx;
        rawDataStreamInTxVec[i] = rawDataStreamInTx;
        rawUdpIpMetaDataOutRxVec[i] = rawUdpIpMetaOutRx;
        rawDataStreamOutRxVec[i] = rawDataStreamOutRx;
    end

    interface rawUdpConfig = rawConfig;
    interface rawAxiStreamOutTx = rawAxiStreamTx;
    interface rawUdpIpMetaSlaveVec = rawUdpIpMetaDataInTxVec;
    interface rawDataStreamSlaveVec = rawDataStreamInTxVec;
    interface rawAxiStreamInRx = rawAxiStreamRx;
    interface rawUdpIpMetaMasterVec = rawUdpIpMetaDataOutRxVec;
    interface rawDataStreamMasterVec = rawDataStreamOutRxVec;
endmodule

interface PfcUdpIpArpEthCmacRxTx#(
    numeric type bufPacketNum, 
    numeric type maxPacketFrameNum,
    numeric type pfcThreshold
);
    // Interface with CMAC IP
    (* prefix = "" *)
    interface XilinxCmacRxTxWrapper cmacRxTxWrapper;
    
    // Configuration Interface
    interface Put#(UdpConfig)  udpConfig;
        
    // Tx Channels
    interface Vector#(VIRTUAL_CHANNEL_NUM, Put#(DataStream))    dataStreamInTxVec;
    interface Vector#(VIRTUAL_CHANNEL_NUM, Put#(UdpIpMetaData)) udpIpMetaDataInTxVec; 
    
    // Rx Channels
    interface Vector#(VIRTUAL_CHANNEL_NUM, Get#(DataStream))    dataStreamOutRxVec;
    interface Vector#(VIRTUAL_CHANNEL_NUM, Get#(UdpIpMetaData)) udpIpMetaDataOutRxVec;
endinterface

module mkPfcUdpIpArpEthCmacRxTx#(
    Bool isSupportRdma,
    Bool isCmacTxWaitRxAligned,
    Integer syncBramBufDepth
)(
    Clock cmacRxTxClk,
    Reset cmacRxReset,
    Reset cmacTxReset,
    PfcUdpIpArpEthCmacRxTx#(bufPacketNum, maxPacketFrameNum, pfcThreshold) ifc
) provisos(Add#(pfcThreshold, a__, bufPacketNum));
    
    let isEnableFlowControl = True;
    let currentClock <- exposeCurrentClock;
    let currentReset <- exposeCurrentReset;
    
    SyncFIFOIfc#(AxiStream512) txAxiStreamSyncBuf <- mkSyncBRAMFIFO(
        syncBramBufDepth,
        currentClock,
        currentReset,
        cmacRxTxClk,
        cmacTxReset
    );

    SyncFIFOIfc#(AxiStream512) rxAxiStreamSyncBuf <- mkSyncBRAMFIFO(
        syncBramBufDepth,
        cmacRxTxClk,
        cmacRxReset,
        currentClock,
        currentReset
    );

    SyncFIFOIfc#(FlowControlReqVec) txFlowCtrlReqVecSyncBuf <- mkSyncBRAMFIFO(
        syncBramBufDepth,
        currentClock,
        currentReset,
        cmacRxTxClk,
        cmacTxReset
    );

    SyncFIFOIfc#(FlowControlReqVec) rxFlowCtrlReqVecSyncBuf <- mkSyncBRAMFIFO(
        syncBramBufDepth,
        cmacRxTxClk,
        cmacRxReset,
        currentClock,
        currentReset
    );

    let cmacWrapper <- mkXilinxCmacRxTxWrapper(
        isEnableFlowControl,
        isCmacTxWaitRxAligned,
        convertSyncFifoToPipeOut(txAxiStreamSyncBuf),
        convertSyncFifoToPipeIn(rxAxiStreamSyncBuf),
        convertSyncFifoToPipeOut(txFlowCtrlReqVecSyncBuf),
        convertSyncFifoToPipeIn(rxFlowCtrlReqVecSyncBuf),
        cmacRxReset,
        cmacTxReset,
        clocked_by cmacRxTxClk
    );

    PfcUdpIpArpEthRxTx#(bufPacketNum, maxPacketFrameNum, pfcThreshold) pfcUdpIpArpEthRxTx <- mkGenericPfcUdpIpArpEthRxTx(isSupportRdma);
    mkConnection(convertSyncFifoToPipeIn(txAxiStreamSyncBuf), pfcUdpIpArpEthRxTx.axiStreamOutTx);
    mkConnection(toGet(convertSyncFifoToPipeOut(rxAxiStreamSyncBuf)), pfcUdpIpArpEthRxTx.axiStreamInRx);
    mkConnection(convertSyncFifoToPipeIn(txFlowCtrlReqVecSyncBuf), pfcUdpIpArpEthRxTx.flowControlReqVecOut);
    mkConnection(toGet(convertSyncFifoToPipeOut(rxFlowCtrlReqVecSyncBuf)), pfcUdpIpArpEthRxTx.flowControlReqVecIn);


    interface cmacRxTxWrapper = cmacWrapper;
    interface udpConfig = pfcUdpIpArpEthRxTx.udpConfig;
    interface udpIpMetaDataInTxVec = pfcUdpIpArpEthRxTx.udpIpMetaDataInTxVec;
    interface dataStreamInTxVec = pfcUdpIpArpEthRxTx.dataStreamInTxVec;
    interface udpIpMetaDataOutRxVec = map(toGet, pfcUdpIpArpEthRxTx.udpIpMetaDataOutRxVec);
    interface dataStreamOutRxVec = map(toGet, pfcUdpIpArpEthRxTx.dataStreamOutRxVec);
endmodule
