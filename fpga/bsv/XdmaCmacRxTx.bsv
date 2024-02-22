import FIFOF :: *;

import Ports :: *;
import XilinxCmacController :: *;
import XilinxAxiStreamAsyncFifo :: *;

import SemiFifo :: *;
import AxiStreamTypes :: *;

typedef 64 ASYNC_FIFO_DEPTH;
typedef 4  ASYNC_CDC_STAGES;

interface XdmaCmacRxTx;
    // Interface with CMAC IP
    (* prefix = "" *)
    interface XilinxCmacController cmacController;
    
    // AXI-Stream Bus interacting with xdma
    (* prefix = "xdma_rx_axis" *)
    interface RawAxiStreamMaster#(AXIS512_TKEEP_WIDTH, AXIS_TUSER_WIDTH) xdmaAxiStreamRxOut;
    (* prefix = "xdma_tx_axis" *)
    interface RawAxiStreamSlave#(AXIS512_TKEEP_WIDTH, AXIS_TUSER_WIDTH) xdmaAxiStreamTxIn;

    //interface Reset udpResetOut;
endinterface

(* synthesize, no_default_clock, no_default_reset *)
module mkXdmaCmacRxTx(
    (* osc   = "xdma_clk"      *) Clock xdmaClk,
    (* reset = "xdma_reset"    *) Reset xdmaReset,
    (* osc   = "cmac_rxtx_clk" *) Clock cmacRxTxClk,
    (* reset = "cmac_rx_reset" *) Reset cmacRxReset,
    (* reset = "cmac_tx_reset" *) Reset cmacTxReset,
    XdmaCmacRxTx ifc
);
    let isEnableRsFec = True;
    let isEnableFlowControl = False;
    let isCmacTxWaitRxAligned = True;
    let asyncFifoDepth = valueOf(ASYNC_FIFO_DEPTH);
    let asyncCdcStages = valueOf(ASYNC_CDC_STAGES);
    

    FIFOF#(AxiStream512) xdmaAxiStreamTxInBuf <- mkFIFOF(clocked_by xdmaClk, reset_by xdmaReset);
    FIFOF#(AxiStream512) xdmaAxiStreamRxOutBuf <- mkFIFOF(clocked_by xdmaClk, reset_by xdmaReset);

    let rawXdmaAxiStreamRxOut <- mkPipeOutToRawAxiStreamMaster(convertFifoToPipeOut(xdmaAxiStreamRxOutBuf), clocked_by xdmaClk, reset_by xdmaReset);
    let rawXdmaAxiStreamTxIn <- mkPipeInToRawAxiStreamSlave(convertFifoToPipeIn(xdmaAxiStreamTxInBuf), clocked_by xdmaClk, reset_by xdmaReset);

    // CMAC Clock Region
    let cmacAxiStreamSync <- mkDuplexAxiStreamAsyncFifo(
        asyncFifoDepth,
        asyncCdcStages,
        xdmaClk,
        xdmaReset,
        cmacRxTxClk,
        cmacRxReset,
        cmacTxReset,
        convertFifoToPipeIn(xdmaAxiStreamRxOutBuf),
        convertFifoToPipeOut(xdmaAxiStreamTxInBuf)
    );

    PipeOut#(FlowControlReqVec) txFlowCtrlReqVec <- mkDummyPipeOut;
    PipeIn#(FlowControlReqVec) rxFlowCtrlReqVec <- mkDummyPipeIn;
    
    let xilinxCmacCtrl <- mkXilinxCmacController(
        isEnableRsFec,
        isEnableFlowControl,
        isCmacTxWaitRxAligned,
        cmacAxiStreamSync.dstPipeOut,
        cmacAxiStreamSync.dstPipeIn,
        txFlowCtrlReqVec,
        rxFlowCtrlReqVec,
        cmacRxReset,
        cmacTxReset,
        clocked_by cmacRxTxClk
    );

    interface cmacController = xilinxCmacCtrl;
    interface xdmaAxiStreamTxIn  = rawXdmaAxiStreamTxIn;
    interface xdmaAxiStreamRxOut = rawXdmaAxiStreamRxOut;
endmodule