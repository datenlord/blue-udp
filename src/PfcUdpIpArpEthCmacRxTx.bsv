import GetPut :: *;
import Vector :: *;
import Clocks :: *;
import BRAMFIFO :: *;
import Connectable :: *;

import Ports :: *;
import StreamHandler :: *;
import EthernetTypes :: *;
import PfcUdpIpArpEthRxTx :: *;
//import PriorityFlowControl :: *;
import XilinxCmacController :: *;

import SemiFifo :: *;

typedef 16 BUF_PACKET_NUM;
typedef 32 MAX_PACKET_FRAME_NUM;
typedef 8  PFC_THRESHOLD;
typedef 8  SYNC_BRAM_BUF_DEPTH;

interface PfcUdpIpArpEthCmacRxTx#(
    numeric type bufPacketNum, 
    numeric type maxPacketFrameNum,
    numeric type pfcThreshold
);
    // Interface with CMAC IP
    (* prefix = "" *)
    interface XilinxCmacController cmacController;
    
    // Configuration Interface
    interface Put#(UdpConfig)  udpConfig;
        
    // Tx Channels
    interface Vector#(VIRTUAL_CHANNEL_NUM, Put#(DataStream))    dataStreamTxInVec;
    interface Vector#(VIRTUAL_CHANNEL_NUM, Put#(UdpIpMetaData)) udpIpMetaDataTxInVec; 
    
    // Rx Channels
    interface Vector#(VIRTUAL_CHANNEL_NUM, Get#(DataStream))    dataStreamRxOutVec;
    interface Vector#(VIRTUAL_CHANNEL_NUM, Get#(UdpIpMetaData)) udpIpMetaDataRxOutVec;
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
    
    let isEnableRsFec = False;
    let isEnableFlowControl = True;
    let udpClock <- exposeCurrentClock;
    let udpReset <- exposeCurrentReset;
    
    SyncFIFOIfc#(AxiStream512) txAxiStreamSyncBuf <- mkSyncBRAMFIFO(
        syncBramBufDepth,
        udpClock,
        udpReset,
        cmacRxTxClk,
        cmacTxReset
    );

    SyncFIFOIfc#(AxiStream512) rxAxiStreamSyncBuf <- mkSyncBRAMFIFO(
        syncBramBufDepth,
        cmacRxTxClk,
        cmacRxReset,
        udpClock,
        udpReset
    );

    SyncFIFOIfc#(FlowControlReqVec) txFlowCtrlReqVecSyncBuf <- mkSyncBRAMFIFO(
        syncBramBufDepth,
        udpClock,
        udpReset,
        cmacRxTxClk,
        cmacTxReset
    );

    SyncFIFOIfc#(FlowControlReqVec) rxFlowCtrlReqVecSyncBuf <- mkSyncBRAMFIFO(
        syncBramBufDepth,
        cmacRxTxClk,
        cmacRxReset,
        udpClock,
        udpReset
    );

    let xilinxCmacController <- mkXilinxCmacController(
        isEnableRsFec,
        isEnableFlowControl,
        isCmacTxWaitRxAligned,
        convertSyncFifoToFifoOut(txAxiStreamSyncBuf),
        convertSyncFifoToFifoIn(rxAxiStreamSyncBuf),
        convertSyncFifoToFifoOut(txFlowCtrlReqVecSyncBuf),
        convertSyncFifoToFifoIn(rxFlowCtrlReqVecSyncBuf),
        cmacRxReset,
        cmacTxReset,
        clocked_by cmacRxTxClk
    );

    PfcUdpIpArpEthRxTx#(bufPacketNum, maxPacketFrameNum, pfcThreshold) pfcUdpIpArpEthRxTx <- mkGenericPfcUdpIpArpEthRxTx(isSupportRdma);
    
    let axiStream512TxOut <- mkDoubleAxiStreamFifoOut(pfcUdpIpArpEthRxTx.axiStreamTxOut);
    let axiStream256RxIn <- mkPutToFifoIn(pfcUdpIpArpEthRxTx.axiStreamRxIn);
    let axiStream512RxIn <- mkDoubleAxiStreamFifoIn(axiStream256RxIn);
    
    mkConnection(convertSyncFifoToFifoIn(txAxiStreamSyncBuf), axiStream512TxOut);
    mkConnection(convertSyncFifoToFifoOut(rxAxiStreamSyncBuf), axiStream512RxIn);
    mkConnection(convertSyncFifoToFifoIn(txFlowCtrlReqVecSyncBuf), pfcUdpIpArpEthRxTx.flowControlReqVecOut);
    mkConnection(toGet(convertSyncFifoToFifoOut(rxFlowCtrlReqVecSyncBuf)), pfcUdpIpArpEthRxTx.flowControlReqVecIn);


    interface cmacController = xilinxCmacController;
    interface udpConfig = pfcUdpIpArpEthRxTx.udpConfig;
    interface udpIpMetaDataTxInVec = pfcUdpIpArpEthRxTx.udpIpMetaDataTxInVec;
    interface dataStreamTxInVec = pfcUdpIpArpEthRxTx.dataStreamTxInVec;
    interface udpIpMetaDataRxOutVec = map(toGet, pfcUdpIpArpEthRxTx.udpIpMetaDataRxOutVec);
    interface dataStreamRxOutVec = map(toGet, pfcUdpIpArpEthRxTx.dataStreamRxOutVec);
endmodule


typedef PfcUdpIpArpEthCmacRxTx#(BUF_PACKET_NUM, MAX_PACKET_FRAME_NUM, PFC_THRESHOLD) RawPfcUdpIpArpEthCmacRxTx;

(* synthesize, no_default_clock, no_default_reset *)
module mkRawPfcUdpIpArpEthCmacRxTx(
    (* osc = "udp_clk"  *)        Clock udpClk,
    (* reset = "udp_reset" *)     Reset udpReset,
    (* osc = "cmac_rxtx_clk" *)   Clock cmacRxTxClk,
    (* reset = "cmac_rx_reset" *) Reset cmacRxReset,
    (* reset = "cmac_tx_reset" *) Reset cmacTxReset,
    RawPfcUdpIpArpEthCmacRxTx ifc
);
    Bool isTxWaitRxAligned = True;
    Integer syncBramBufDepth = valueOf(SYNC_BRAM_BUF_DEPTH);
    RawPfcUdpIpArpEthCmacRxTx pfcUdpIpArpEthCmacRxTx <- mkPfcUdpIpArpEthCmacRxTx(
        `IS_SUPPORT_RDMA,
        isTxWaitRxAligned,
        syncBramBufDepth,
        cmacRxTxClk,
        cmacRxReset,
        cmacTxReset,
        clocked_by udpClk,
        reset_by udpReset
    );
    return pfcUdpIpArpEthCmacRxTx;
endmodule
