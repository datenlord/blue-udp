
import GetPut :: *;

import Ports :: *;
import UdpIpEthRx :: *;
import UdpIpEthTx :: *;
import StreamHandler :: *;
import PortConversion :: *;
import XilinxCmacController :: *;
import XilinxAxiStreamAsyncFifo :: *;

import SemiFifo :: *;

interface UdpIpEthRxTx;
    interface Put#(UdpConfig) udpConfig;
    
    // Tx Channel
    interface Put#(MacMetaData)   macMetaDataTxIn;
    interface Put#(UdpIpMetaData) udpIpMetaDataTxIn;
    interface Put#(DataStream)    dataStreamTxIn;
    interface AxiStreamLocalFifoOut axiStreamTxOut;
    
    // Rx Channel
    interface Put#(AxiStreamLocal)   axiStreamRxIn;
    interface MacMetaDataFifoOut   macMetaDataRxOut;
    interface UdpIpMetaDataFifoOut udpIpMetaDataRxOut;
    interface DataStreamFifoOut    dataStreamRxOut;
endinterface

module mkGenericUdpIpEthRxTx#(Bool isSupportRdma)(UdpIpEthRxTx);

    let udpIpEthRx <- mkGenericUdpIpEthRx(isSupportRdma);
    let udpIpEthTx <- mkGenericUdpIpEthTx(isSupportRdma);

    interface Put udpConfig;
        method Action put(UdpConfig udpConfig);
            udpIpEthRx.udpConfig.put(udpConfig);
            udpIpEthTx.udpConfig.put(udpConfig);
        endmethod
    endinterface

    interface udpIpMetaDataTxIn = udpIpEthTx.udpIpMetaDataIn;
    interface macMetaDataTxIn = udpIpEthTx.macMetaDataIn;
    interface dataStreamTxIn = udpIpEthTx.dataStreamIn;
    interface axiStreamTxOut = udpIpEthTx.axiStreamOut;

    interface axiStreamRxIn = udpIpEthRx.axiStreamIn;
    interface macMetaDataRxOut = udpIpEthRx.macMetaDataOut;
    interface udpIpMetaDataRxOut = udpIpEthRx.udpIpMetaDataOut;
    interface dataStreamRxOut = udpIpEthRx.dataStreamOut;
endmodule

// UdpIpEthRxTx with Xilinx 100Gb CMAC Controller
interface UdpIpEthCmacRxTx;
    // Interface with CMAC IP
    (* prefix = "" *)
    interface XilinxCmacController cmacController;
    
    // Configuration Interface
    interface Put#(UdpConfig)  udpConfig;

    // Tx Channel
    interface Put#(UdpIpMetaData) udpIpMetaDataTxIn;
    interface Put#(DataStream)    dataStreamTxIn;
    interface Put#(MacMetaData)   macMetaDataTxIn;
    
    // Rx Channel
    interface UdpIpMetaDataFifoOut udpIpMetaDataRxOut;
    interface DataStreamFifoOut    dataStreamRxOut;
    interface MacMetaDataFifoOut   macMetaDataRxOut;
endinterface

(* default_clock_osc = "udp_clk", default_reset = "udp_reset" *)
module mkUdpIpEthCmacRxTx#(
    Bool isSupportRdma,
    Bool isEnableRsFec,
    Bool isCmacTxWaitRxAligned,
    Integer syncBramBufDepth,
    Integer cdcSyncStages
)(
    Clock cmacRxTxClk,
    Reset cmacRxReset,
    Reset cmacTxReset,
    UdpIpEthCmacRxTx ifc
);
    let isEnableFlowControl = False;

    let udpClk <- exposeCurrentClock;
    let udpReset <- exposeCurrentReset;

    let udpIpEthRxTx <- mkGenericUdpIpEthRxTx(isSupportRdma);
    let axiStream512TxOut <- mkAxiStream512FifoOut(udpIpEthRxTx.axiStreamTxOut);

    let axiStreamRxIn <- mkPutToFifoIn(udpIpEthRxTx.axiStreamRxIn);
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

    interface udpConfig = udpIpEthRxTx.udpConfig;

    interface cmacController = xilinxCmacCtrl;

    interface macMetaDataTxIn = udpIpEthRxTx.macMetaDataTxIn;
    interface udpIpMetaDataTxIn = udpIpEthRxTx.udpIpMetaDataTxIn;
    interface dataStreamTxIn = udpIpEthRxTx.dataStreamTxIn;

    interface macMetaDataRxOut = udpIpEthRxTx.macMetaDataRxOut;
    interface udpIpMetaDataRxOut = udpIpEthRxTx.udpIpMetaDataRxOut;
    interface dataStreamRxOut = udpIpEthRxTx.dataStreamRxOut;
endmodule


interface RawUdpIpEthCmacRxTx;
    // Interface with CMAC IP
    (* prefix = "" *)
    interface XilinxCmacController cmacController;
    
    // Configuration Interface
    (* prefix = "s_udp_config" *)
    interface RawUdpConfigBusSlave  udpConfig;
    
    // Tx
    (* prefix = "s_udp_meta" *)
    interface RawUdpIpMetaDataBusSlave udpIpMetaDataTxIn;
    (* prefix = "s_data_stream" *)
    interface RawDataStreamBusSlave    dataStreamTxIn;
    (* prefix = "s_mac_meta" *)
    interface RawMacMetaDataBusSlave   macMetaDataTxIn;

    // Rx
    (* prefix = "m_udp_meta" *)
    interface RawUdpIpMetaDataBusMaster udpIpMetaDataRxOut;
    (* prefix = "m_data_stream" *)
    interface RawDataStreamBusMaster    dataStreamRxOut;
    (* prefix = "m_mac_meta" *)
    interface RawMacMetaDataBusMaster   macMetaDataRxOut;
endinterface

(* synthesize, default_clock_osc = "udp_clk", default_reset = "udp_reset" *)
module mkRawUdpIpEthCmacRxTx(
    (* osc   = "cmac_rxtx_clk" *) Clock cmacRxTxClk,
    (* reset = "cmac_rx_reset" *) Reset cmacRxReset,
    (* reset = "cmac_tx_reset" *) Reset cmacTxReset,
    RawUdpIpEthCmacRxTx ifc
);
    Bool isCmacTxWaitRxAligned = True;
    Bool isEnableRsFec = True;
    Integer syncBramBufDepth = 32;
    Integer cdcSyncStages = 4;

    let udpIpEthCmacRxTx <- mkUdpIpEthCmacRxTx(
        `IS_SUPPORT_RDMA,
        isEnableRsFec,
        isCmacTxWaitRxAligned,
        syncBramBufDepth,
        cdcSyncStages,
        cmacRxTxClk,
        cmacRxReset,
        cmacTxReset
    );

    let rawUdpConfig <- mkRawUdpConfigBusSlave(udpIpEthCmacRxTx.udpConfig);
    
    let rawUdpIpMetaDataTxIn <- mkRawUdpIpMetaDataBusSlave(udpIpEthCmacRxTx.udpIpMetaDataTxIn);
    let rawDataStreamTxIn <- mkRawDataStreamBusSlave(udpIpEthCmacRxTx.dataStreamTxIn);
    let rawMacMetaDataTxIn <- mkRawMacMetaDataBusSlave(udpIpEthCmacRxTx.macMetaDataTxIn);
    
    let rawUdpIpMetaDataRxOut <- mkRawUdpIpMetaDataBusMaster(udpIpEthCmacRxTx.udpIpMetaDataRxOut);
    let rawDataStreamRxOut <- mkRawDataStreamBusMaster(udpIpEthCmacRxTx.dataStreamRxOut);   
    let rawMacMetaDataRxOut <- mkRawMacMetaDataBusMaster(udpIpEthCmacRxTx.macMetaDataRxOut);


    interface cmacController = udpIpEthCmacRxTx.cmacController;

    interface udpConfig = rawUdpConfig;
    
    interface udpIpMetaDataTxIn = rawUdpIpMetaDataTxIn;
    interface dataStreamTxIn = rawDataStreamTxIn;
    interface macMetaDataTxIn = rawMacMetaDataTxIn;
    
    interface udpIpMetaDataRxOut = rawUdpIpMetaDataRxOut;
    interface dataStreamRxOut = rawDataStreamRxOut;
    interface macMetaDataRxOut = rawMacMetaDataRxOut;
endmodule
