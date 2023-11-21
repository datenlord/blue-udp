import Clocks :: *;
import Connectable :: *;

import SemiFifo :: *;
import AxiStreamTypes :: *;

interface RawAxiStreamFifo#(numeric type keepWidth, numeric type userWidth);//#(numeric type tKeepWidth, numeric type tUserWidth);
    method Action          tReadyM();
    method Bool            tValidM();
    method Bit#(keepWidth) tKeepM();
    method Bool            tLastM();
    method Bit#(userWidth) tUserM();
    method Bit#(TMul#(keepWidth, 8)) tDataM();

    method Action tValidS (
	    Bit#(TMul#(keepWidth, 8)) tData,
	    Bit#(keepWidth)           tKeep,
	    Bool                      tLast,
        Bit#(userWidth)           tUser
    );
    method Bool tReadyS();
endinterface

import "BVI" xpm_fifo_axis =
module mkRawXilinxAxiStreamAsyncFifo#(
    Integer depthIn,
    Integer cdcSyncStages
)(
    Clock srcClkIn,
    Reset srcRstIn,
    Clock dstClkIn,
    RawAxiStreamFifo#(keepWidth, userWidth) ifc
);
    let logDepth = log2(depthIn) ;
    let pwrDepth = 2 ** logDepth ;
    Integer dataWidth = 8 * valueOf(keepWidth);

    if ((pwrDepth != depthIn) || (pwrDepth < 16))
        error("The depth of xpm_fifo_axis must be power of two and greater than 16");

    // define parameters
    parameter CASCADE_HEIGHT = 0;
    parameter CDC_SYNC_STAGES = cdcSyncStages;
    parameter CLOCKING_MODE = "independent_clock";
    parameter ECC_MODE = "no_ecc";
    parameter FIFO_DEPTH = depthIn;
    parameter FIFO_MEMORY_TYPE = "auto";
    parameter PACKET_FIFO = "false";
    parameter PROG_EMPTY_THRESH = 10;
    parameter PROG_FULL_THRESH = 10;
    parameter RD_DATA_COUNT_WIDTH = pwrDepth;
    parameter RELATED_CLOCKS = 0;
    parameter SIM_ASSERT_CHK = 0;
    parameter TDATA_WIDTH = dataWidth;
    parameter TDEST_WIDTH = 1;
    parameter TID_WIDTH = 1;
    parameter TUSER_WIDTH = valueOf(userWidth);
    parameter USE_ADV_FEATURES = "1000";
    parameter WR_DATA_COUNT_WIDTH = pwrDepth;


    // Clock and Reset Signals
    default_clock no_clock;
    no_reset;

    input_clock clkSrc (s_aclk, (*unused*)s_alck_GATE) = srcClkIn;
    input_clock clkDst (m_aclk, (*unused*)m_aclk_GATE) = dstClkIn;

    input_reset (s_aresetn) = srcRstIn;

    // Constant Input Signals
    //port sbiterr_axis = False;
    port injectdbiterr_axis = False;
    port injectsbiterr_axis = False;
    port s_axis_tdest = 1'b0;
    port s_axis_tid   = 1'b0;
    port s_axis_tstrb = 0;

    // enq
    method s_axis_tready tReadyS() clocked_by(clkSrc) reset_by(no_reset);
    method tValidS(s_axis_tdata, s_axis_tkeep, s_axis_tlast, s_axis_tuser) enable(s_axis_tvalid) ready(s_axis_tready) clocked_by(clkSrc) reset_by(no_reset);
    
    // deq
    method m_axis_tvalid tValidM()                     clocked_by(clkDst) reset_by(no_reset);
    method m_axis_tkeep  tKeepM() ready(m_axis_tvalid) clocked_by(clkDst) reset_by(no_reset);
    method m_axis_tdata  tDataM() ready(m_axis_tvalid) clocked_by(clkDst) reset_by(no_reset);
    method m_axis_tlast  tLastM() ready(m_axis_tvalid) clocked_by(clkDst) reset_by(no_reset);
    method m_axis_tuser  tUserM() ready(m_axis_tvalid) clocked_by(clkDst) reset_by(no_reset);
    method tReadyM() enable(m_axis_tready) ready(m_axis_tvalid) clocked_by(clkDst) reset_by(no_reset);
    
    schedule (tValidM, tDataM, tKeepM, tLastM, tUserM) SB tReadyM;
    schedule (tValidM, tDataM, tKeepM, tLastM, tUserM) CF (tValidM, tDataM, tKeepM, tLastM, tUserM);
    schedule tReadyM C tReadyM;
    
    schedule tReadyS SB tValidS;
    schedule tReadyS CF tReadyS;
    schedule tValidS C tValidS;

endmodule

import "BVI" xpm_cdc_sync_rst =
module mkRawXilinxSyncReset#(Integer stages, Integer init)(
    Reset rstIn, 
    Clock clkIn, 
    ResetGenIfc rstOut
);
    if ((stages < 2) || (stages >10)) 
        error("The number of sync stages must be between 2 and 10");
    parameter DEST_SYNC_FF = stages;
    parameter INIT = (init == 0) ? 0 : 1;
    parameter INIT_SYNC_FF = 0;
    parameter SIM_ASSERT_CHK = 0;

    default_clock no_clock;
    no_reset;

    input_clock dstClk (dest_clk, (*unused*) dest_clk_GATE) = clkIn;
    input_reset (src_rst) clocked_by(no_clock) = rstIn;
    output_reset gen_rst(dest_rst) clocked_by(dstClk);
endmodule

module mkXilinxSyncReset#(Integer stages)(Reset rstIn, Clock clkIn, Reset rstOut);
    let rstSync <- mkRawXilinxSyncReset(stages, 0, rstIn, clkIn);
    return rstSync.gen_rst;
endmodule

module mkXilinxAxiStreamAsyncFifo(
    Integer fifoDepth,
    Integer cdcSyncStages,
    Clock srcClkIn,
    Reset srcRstIn,
    Clock dstClkIn,
    Reset dstRstIn,
    SyncFIFOIfc#(AxiStream#(keepWidth, userWidth)) ifc
);
    Integer resetSyncStages = 3;
    let dRstSyncToSrc <- mkXilinxSyncReset(resetSyncStages, dstRstIn, srcClkIn);
    let fifoReset <- mkResetEither(srcRstIn, dRstSyncToSrc, clocked_by srcClkIn);
    RawAxiStreamFifo#(keepWidth, userWidth) xilinxFifo <- mkRawXilinxAxiStreamAsyncFifo(fifoDepth, cdcSyncStages, srcClkIn, fifoReset, dstClkIn);
    
    method Bool notFull = xilinxFifo.tReadyS;
    method Action enq(AxiStream#(keepWidth, userWidth) axiStream);
        xilinxFifo.tValidS(axiStream.tData, axiStream.tKeep, axiStream.tLast, axiStream.tUser);
    endmethod

    method Bool notEmpty = xilinxFifo.tValidM;
    method AxiStream#(keepWidth, userWidth) first;
        return AxiStream {
            tData: xilinxFifo.tDataM,
            tKeep: xilinxFifo.tKeepM,
            tLast: xilinxFifo.tLastM,
            tUser: xilinxFifo.tUserM
        };
    endmethod
    method Action deq();
        xilinxFifo.tReadyM;
    endmethod
endmodule

interface DuplexAxiStreamPipe#(numeric type keepWidth, numeric type usrWidth);
    interface PipeIn#(AxiStream#(keepWidth, usrWidth)) dstPipeIn;
    interface PipeOut#(AxiStream#(keepWidth, usrWidth)) dstPipeOut;
endinterface

(* no_default_clock, no_default_reset *)
module mkDuplexAxiStreamAsyncFifo#(
    Integer asyncFifoDepth,
    Integer asyncCdcStages,
    Clock srcClk,
    Reset srcReset,
    Clock dstClk,
    Reset dstPipeInReset,
    Reset dstPipeOutReset,
    PipeIn #(AxiStream#(keepWidth, usrWidth)) srcPipeIn,
    PipeOut#(AxiStream#(keepWidth, usrWidth)) srcPipeOut
)(DuplexAxiStreamPipe#(keepWidth, usrWidth));

    SyncFIFOIfc#(AxiStream#(keepWidth, usrWidth)) pipeInBuf <- mkXilinxAxiStreamAsyncFifo(
        asyncFifoDepth,
        asyncCdcStages,
        dstClk,
        dstPipeInReset,
        srcClk,
        srcReset
    );
    mkConnection(convertSyncFifoToPipeOut(pipeInBuf), srcPipeIn);

    SyncFIFOIfc#(AxiStream#(keepWidth, usrWidth)) pipeOutBuf <- mkXilinxAxiStreamAsyncFifo(
        asyncFifoDepth,
        asyncCdcStages,
        srcClk,
        srcReset,
        dstClk,
        dstPipeOutReset
    );
    mkConnection(convertSyncFifoToPipeIn(pipeOutBuf), srcPipeOut);
    
    interface dstPipeIn = convertSyncFifoToPipeIn(pipeInBuf);
    interface dstPipeOut = convertSyncFifoToPipeOut(pipeOutBuf);
endmodule