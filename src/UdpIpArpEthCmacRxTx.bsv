import GetPut :: *;
import Clocks :: *;
import BRAMFIFO :: *;
import Connectable :: *;

import Ports :: *;
import EthUtils :: *;
import StreamHandler :: *;
import UdpIpArpEthRxTx :: *;
import PortConversion :: *;
import XilinxCmacController :: *;
import XilinxAxiStreamAsyncFifo :: *;

import SemiFifo :: *;

// UdpIpArpEthRxTx module with Xilinx 100Gb CMAC Controller
interface UdpIpArpEthCmacRxTx;
    // Interface with CMAC IP
    (* prefix = "" *)
    interface XilinxCmacController cmacController;
    
    // Configuration Interface
    interface Put#(UdpConfig)  udpConfig;
    
    // Tx
    interface Put#(UdpIpMetaData) udpIpMetaDataTxIn;
    interface Put#(DataStream)    dataStreamTxIn;

    // Rx
    interface UdpIpMetaDataPipeOut udpIpMetaDataRxOut;
    interface DataStreamPipeOut    dataStreamRxOut;
endinterface

(* default_clock_osc = "udp_clk", default_reset = "udp_reset" *)
module mkUdpIpArpEthCmacRxTx#(
    Bool isSupportRdma,
    Bool isCmacTxWaitRxAligned,
    Integer syncBramBufDepth,
    Integer cdcSyncStages
)(
    Clock cmacRxTxClk,
    Reset cmacRxReset,
    Reset cmacTxReset,
    UdpIpArpEthCmacRxTx ifc
);
    let isEnableFlowControl = False;

    let udpClk <- exposeCurrentClock;
    let udpReset <- exposeCurrentReset;

    let udpIpArpEthRxTx <- mkGenericUdpIpArpEthRxTx(isSupportRdma);
    let axiStream512TxOut <- mkDoubleAxiStreamPipeOut(udpIpArpEthRxTx.axiStreamTxOut);
    let axiStreamRxIn <- mkPutToPipeIn(udpIpArpEthRxTx.axiStreamRxIn);
    let axiStream512RxIn <- mkDoubleAxiStreamPipeIn(axiStreamRxIn);

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

    PipeOut#(FlowControlReqVec) txFlowCtrlReqVec <- mkDummyPipeOut;
    PipeIn#(FlowControlReqVec) rxFlowCtrlReqVec <- mkDummyPipeIn;
    let xilinxCmacCtrl <- mkXilinxCmacController(
        isEnableFlowControl,
        isCmacTxWaitRxAligned,
        axiStream512Sync.dstPipeOut,
        axiStream512Sync.dstPipeIn,
        txFlowCtrlReqVec,
        rxFlowCtrlReqVec,
        cmacRxReset,
        cmacTxReset,
        clocked_by cmacRxTxClk
    );

    interface cmacController = xilinxCmacCtrl;
    interface udpConfig = udpIpArpEthRxTx.udpConfig;
    interface udpIpMetaDataTxIn = udpIpArpEthRxTx.udpIpMetaDataTxIn;
    interface dataStreamTxIn = udpIpArpEthRxTx.dataStreamTxIn;
    interface udpIpMetaDataRxOut = udpIpArpEthRxTx.udpIpMetaDataRxOut;
    interface dataStreamRxOut = udpIpArpEthRxTx.dataStreamRxOut;
endmodule

interface RawUdpIpArpEthCmacRxTx;
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

    // Rx
    (* prefix = "m_udp_meta" *)
    interface RawUdpIpMetaDataBusMaster udpIpMetaDataRxOut;
    (* prefix = "m_data_stream" *)
    interface RawDataStreamBusMaster    dataStreamRxOut;
endinterface

(* synthesize, default_clock_osc = "udp_clk", default_reset = "udp_reset" *)
module mkRawUdpIpArpEthCmacRxTx(
    (* osc   = "cmac_rxtx_clk" *) Clock cmacRxTxClk,
    (* reset = "cmac_rx_reset" *) Reset cmacRxReset,
    (* reset = "cmac_tx_reset" *) Reset cmacTxReset,
    RawUdpIpArpEthCmacRxTx ifc
);
    Bool isCmacTxWaitRxAligned = True;
    Integer syncBramBufDepth = 32;
    Integer cdcSyncStages = 4;

    let udpIpArpEthCmacRxTx <- mkUdpIpArpEthCmacRxTx(
        `IS_SUPPORT_RDMA,
        isCmacTxWaitRxAligned,
        syncBramBufDepth,
        cdcSyncStages,
        cmacRxTxClk,
        cmacRxReset,
        cmacTxReset
    );

    let rawUdpConfig <- mkRawUdpConfigBusSlave(udpIpArpEthCmacRxTx.udpConfig);
    let rawUdpIpMetaDataTxIn <- mkRawUdpIpMetaDataBusSlave(udpIpArpEthCmacRxTx.udpIpMetaDataTxIn);
    let rawDataStreamTxIn <- mkRawDataStreamBusSlave(udpIpArpEthCmacRxTx.dataStreamTxIn);
    let rawUdpIpMetaDataRxOut <- mkRawUdpIpMetaDataBusMaster(udpIpArpEthCmacRxTx.udpIpMetaDataRxOut);
    let rawDataStreamRxOut <- mkRawDataStreamBusMaster(udpIpArpEthCmacRxTx.dataStreamRxOut);   

    interface udpConfig = rawUdpConfig;
    interface udpIpMetaDataTxIn = rawUdpIpMetaDataTxIn;
    interface dataStreamTxIn = rawDataStreamTxIn;
    interface udpIpMetaDataRxOut = rawUdpIpMetaDataRxOut;
    interface dataStreamRxOut = rawDataStreamRxOut;
    interface cmacController = udpIpArpEthCmacRxTx.cmacController;
endmodule