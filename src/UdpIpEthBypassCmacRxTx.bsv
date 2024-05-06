import GetPut :: *;

import Ports :: *;
import StreamHandler :: *;
import UdpIpEthBypassRx :: *;
import UdpIpEthBypassTx :: *;
import XilinxAxiStreamAsyncFifo :: *;
import XilinxCmacController :: *;

import SemiFifo :: *;

// UdpIpEthRxTx with bypass channel
interface UdpIpEthBypassRxTx;
    interface Put#(UdpConfig) udpConfig;
    
    // Tx Channel
    interface Put#(MacMetaDataWithBypassTag) macMetaDataTxIn;
    interface Put#(UdpIpMetaData) udpIpMetaDataTxIn;
    interface Put#(DataStream)    dataStreamTxIn;
    interface AxiStreamLocalFifoOut axiStreamTxOut;
    
    // Rx Channel
    interface Put#(AxiStreamLocal)   axiStreamRxIn;
    interface MacMetaDataFifoOut   macMetaDataRxOut;
    interface UdpIpMetaDataFifoOut udpIpMetaDataRxOut;
    interface DataStreamFifoOut    dataStreamRxOut;
    interface DataStreamFifoOut    rawPktStreamRxOut;
endinterface

module mkGenericUdpIpEthBypassRxTx#(Bool isSupportRdma)(UdpIpEthBypassRxTx);
    
    let udpIpEthBypassRx <- mkGenericUdpIpEthBypassRx(isSupportRdma);
    let udpIpEthBypassTx <- mkGenericUdpIpEthBypassTx(isSupportRdma);

    interface Put udpConfig;
        method Action put(UdpConfig udpConfig);
            udpIpEthBypassRx.udpConfig.put(udpConfig);
            udpIpEthBypassTx.udpConfig.put(udpConfig);
        endmethod
    endinterface

    interface macMetaDataTxIn = udpIpEthBypassTx.macMetaDataIn;
    interface udpIpMetaDataTxIn = udpIpEthBypassTx.udpIpMetaDataIn;
    interface dataStreamTxIn = udpIpEthBypassTx.dataStreamIn;
    interface axiStreamTxOut = udpIpEthBypassTx.axiStreamOut;

    interface axiStreamRxIn = udpIpEthBypassRx.axiStreamIn;
    interface macMetaDataRxOut = udpIpEthBypassRx.macMetaDataOut;
    interface udpIpMetaDataRxOut = udpIpEthBypassRx.udpIpMetaDataOut;
    interface dataStreamRxOut = udpIpEthBypassRx.dataStreamOut;
    interface rawPktStreamRxOut = udpIpEthBypassRx.rawPktStreamOut;
endmodule


// UdpIpEthRxTx with Xilinx 100Gb CMAC Controller
interface UdpIpEthBypassCmacRxTx;
    // Interface with CMAC IP
    (* prefix = "" *)
    interface XilinxCmacController cmacController;
    
    interface Put#(UdpConfig) udpConfig;
    
    // Tx Channel
    interface Put#(MacMetaDataWithBypassTag) macMetaDataTxIn;
    interface Put#(UdpIpMetaData) udpIpMetaDataTxIn;
    interface Put#(DataStream)    dataStreamTxIn;
            
    // Rx Channel
    interface MacMetaDataFifoOut   macMetaDataRxOut;
    interface UdpIpMetaDataFifoOut udpIpMetaDataRxOut;
    interface DataStreamFifoOut    dataStreamRxOut;
    interface DataStreamFifoOut    rawPktStreamRxOut;
endinterface

(* default_clock_osc = "udp_clk", default_reset = "udp_reset" *)
module mkUdpIpEthBypassCmacRxTx#(
    Bool isSupportRdma,
    Bool isEnableRsFec,
    Bool isCmacTxWaitRxAligned,
    Integer syncBramBufDepth,
    Integer cdcSyncStages
)(
    Clock cmacRxTxClk,
    Reset cmacRxReset,
    Reset cmacTxReset,
    UdpIpEthBypassCmacRxTx ifc
);
    let isEnableFlowControl = False;

    let udpClk <- exposeCurrentClock;
    let udpReset <- exposeCurrentReset;

    let udpIpEthBypassRxTx <- mkGenericUdpIpEthBypassRxTx(isSupportRdma);

    let axiStream512TxOut <- mkAxiStream512FifoOut(udpIpEthBypassRxTx.axiStreamTxOut);
    
    let axiStreamRxIn <- mkPutToFifoIn(udpIpEthBypassRxTx.axiStreamRxIn);
    let axiStream512RxIn <- mkAxiStream512FifoIn(axiStreamRxIn);

    let axiStream512Sync <- mkDuplexAxiStreamAsyncFifo(
        syncBramBufDepth,
        cdcSyncStages,
        udpClk,
        udpReset,
        cmacRxTxClk,
        cmacRxReset,
        cmacTxReset,
        axiStream512RxIn,
        axiStream512TxOut
    );

    FifoOut#(FlowControlReqVec) txFlowCtrlReqVec <- mkDummyFifoOut;
    FifoIn#(FlowControlReqVec) rxFlowCtrlReqVec <- mkDummyFifoIn;
    let xilinxCmacCtrl <- mkXilinxCmacController(
        isEnableRsFec,
        isEnableFlowControl,
        isCmacTxWaitRxAligned,
        axiStream512Sync.dstFifoOut,
        axiStream512Sync.dstFifoIn,
        txFlowCtrlReqVec,
        rxFlowCtrlReqVec,
        cmacRxReset,
        cmacTxReset,
        clocked_by cmacRxTxClk
    );

    interface udpConfig = udpIpEthBypassRxTx.udpConfig;

    interface cmacController = xilinxCmacCtrl;

    interface macMetaDataTxIn = udpIpEthBypassRxTx.macMetaDataTxIn;
    interface udpIpMetaDataTxIn = udpIpEthBypassRxTx.udpIpMetaDataTxIn;
    interface dataStreamTxIn = udpIpEthBypassRxTx.dataStreamTxIn;

    interface macMetaDataRxOut = udpIpEthBypassRxTx.macMetaDataRxOut;
    interface udpIpMetaDataRxOut = udpIpEthBypassRxTx.udpIpMetaDataRxOut;
    interface dataStreamRxOut = udpIpEthBypassRxTx.dataStreamRxOut;
    interface rawPktStreamRxOut = udpIpEthBypassRxTx.rawPktStreamRxOut;
endmodule