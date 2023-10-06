import Cntrs :: *;
import FIFOF :: *;
import GetPut :: *;
import Vector :: *;
import BRAMFIFO :: *;
import Connectable :: *;

import Ports :: *;
import Utils :: *;
import EthernetTypes :: *;

import SemiFifo :: *;
import AxiStreamTypes :: *;

typedef 9 CMAC_TX_INIT_COUNT_WIDTH;
typedef 8 CMAC_TX_INIT_DONE_FLAG_INDEX;

typedef 6 CMAC_TX_PAUSE_REQ_COUNT_WIDTH;

//
typedef 2500 MAX_PKT_BYTE_NUM;
typedef TDiv#(MAX_PKT_BYTE_NUM, AXIS_TKEEP_WIDTH) MAX_PKT_FRAME_NUM;
typedef TLog#(MAX_PKT_FRAME_NUM) FRAME_INDEX_WIDTH;
typedef MAX_PKT_FRAME_NUM CMAC_INTER_BUF_DEPTH;
typedef TLog#(CMAC_INTER_BUF_DEPTH) PKT_INDEX_WIDTH;

typedef 9 CMAC_PAUSE_ENABLE_WIDTH;
typedef 9 CMAC_PAUSE_REQ_WIDTH;
typedef 9 CMAC_PAUSE_ACK_WIDTH;


(* always_ready, always_enabled *)
interface XilinxCmacTxWrapper;

    // AxiStream Interface
    (* prefix = "tx_axis" *)
    interface RawAxiStreamMaster#(AXIS_TKEEP_WIDTH, AXIS_TUSER_WIDTH) txRawAxiStreamOut;

    // CMAC Control Output
    (* result = "tx_ctl_enable" *) 
    method Bool ctlTxEnable;
    (* result = "tx_ctl_test_pattern" *)
    method Bool ctlTxTestPattern;
    (* result = "tx_ctl_send_idle" *)
    method Bool ctlTxSendIdle;
    (* result = "tx_ctl_send_lfi" *)
    method Bool ctlTxSendLocalFaultIndication;
    (* result = "tx_ctl_send_rfi" *)
    method Bool ctlTxSendRemoteFaultIndication;
    (* result = "tx_ctl_reset" *)
    method Bool ctlTxReset;

    // PFC Control Output
    (* result = "tx_ctl_pause_enable" *)
    method Bit#(CMAC_PAUSE_ENABLE_WIDTH) ctlTxPauseEnable;
    (* result = "tx_ctl_pause_req" *)
    method Bit#(CMAC_PAUSE_REQ_WIDTH) ctlTxPauseReq;
    (* result = "tx_ctl_pause_quanta0" *)
    method PfcPauseQuanta ctlTxPauseQuanta0;
    (* result = "tx_ctl_pause_quanta1" *)
    method PfcPauseQuanta ctlTxPauseQuanta1;
    (* result = "tx_ctl_pause_quanta2" *)
    method PfcPauseQuanta ctlTxPauseQuanta2;
    (* result = "tx_ctl_pause_quanta3" *)
    method PfcPauseQuanta ctlTxPauseQuanta3;
    (* result = "tx_ctl_pause_quanta4" *)
    method PfcPauseQuanta ctlTxPauseQuanta4;
    (* result = "tx_ctl_pause_quanta5" *)
    method PfcPauseQuanta ctlTxPauseQuanta5;
    (* result = "tx_ctl_pause_quanta6" *)
    method PfcPauseQuanta ctlTxPauseQuanta6;
    (* result = "tx_ctl_pause_quanta7" *)
    method PfcPauseQuanta ctlTxPauseQuanta7;
    (* result = "tx_ctl_pause_quanta8" *)
    method PfcPauseQuanta ctlTxPauseQuanta8;

    // CMAC Status Input
    (* prefix = "" *) method Action cmacTxStatus(
        (* port = "tx_stat_ovfout" *) Bool txOverFlow,
        (* port = "tx_stat_unfout" *) Bool txUnderFlow,
        (* port = "tx_stat_rx_aligned" *) Bool rxAligned
    );

endinterface

typedef enum {
    TX_STATE_IDLE,
    TX_STATE_GT_LOCKED,
    TX_STATE_WAIT_RX_ALIGNED,
    TX_STATE_PKT_TRANSFER_INIT,
    TX_STATE_AXIS_ENABLE,
    TX_STATE_HALT
} CmacTxWrapperState deriving(Bits, Eq, FShow);

module mkXilinxCmacTxWrapper#(
    Bool isEnableFlowControl,
    Bool isWaitRxAligned,
    AxiStream512PipeOut txAxiStreamIn,
    PipeOut#(FlowControlReqVec) txFlowCtrlReqVec
)(XilinxCmacTxWrapper);
    Reg#(Bool) ctlTxEnableReg <- mkReg(False);
    Reg#(Bool) ctlTxTestPatternReg <- mkReg(False);
    Reg#(Bool) ctlTxSendIdleReg <- mkReg(False);
    Reg#(Bool) ctlTxSendLocalFaultIndicationReg <- mkReg(False);
    Reg#(Bool) ctlTxSendRemoteFaultIndicationReg <- mkReg(False);

    Reg#(Bit#(VIRTUAL_CHANNEL_NUM)) ctlTxPauseEnableReg <- mkReg(0);
    Reg#(Bit#(VIRTUAL_CHANNEL_NUM)) ctlTxPauseReqReg <- mkReg(0);
    Vector#(VIRTUAL_CHANNEL_NUM, Reg#(PfcPauseQuanta)) ctlTxPauseQuantaRegVec <- replicateM(mkReg(0));

    Reg#(Bool) txOverFlowReg <- mkReg(False);
    Reg#(Bool) txUnderFlowReg <- mkReg(False);
    Reg#(Bool) rxAlignedReg <- mkReg(False);

    FIFOF#(AxiStream512) txAxiStreamOutBuf <- mkFIFOF;
    FIFOF#(AxiStream512) txAxiStreamInterBuf <- mkSizedBRAMFIFOF(valueOf(CMAC_INTER_BUF_DEPTH));
    FIFOF#(Bool) packetReadyInfoBuf <- mkSizedFIFOF(valueOf(CMAC_INTER_BUF_DEPTH));

    Reg#(CmacTxWrapperState) txStateReg <- mkReg(TX_STATE_IDLE);
    Reg#(Bit#(CMAC_TX_INIT_COUNT_WIDTH)) initCounter <- mkReg(0);
    Reg#(Bool) isTxPauseReqBusy <- mkReg(False);
    Reg#(Bit#(CMAC_TX_PAUSE_REQ_COUNT_WIDTH)) txPauseReqCounter <- mkReg(0);


    rule stateIdle if (txStateReg == TX_STATE_IDLE);
        ctlTxEnableReg <= False;
        ctlTxTestPatternReg <= False;
        ctlTxSendIdleReg <= False;
        ctlTxSendLocalFaultIndicationReg <= False;
        ctlTxSendRemoteFaultIndicationReg <= False;

        txStateReg <= TX_STATE_GT_LOCKED;
    endrule

    rule stateGtLocked if (txStateReg == TX_STATE_GT_LOCKED);
        ctlTxEnableReg <= False;
        ctlTxSendIdleReg <= False;
        ctlTxSendLocalFaultIndicationReg <= False;
        ctlTxSendRemoteFaultIndicationReg <= True;
        txStateReg <= TX_STATE_WAIT_RX_ALIGNED;
        $display("CmacTxWrapper: Wait CMAC Rx Algined Ready");
    endrule

    rule stateWaitRxAligned if (txStateReg == TX_STATE_WAIT_RX_ALIGNED);
        if (rxAlignedReg) begin
            txStateReg <= TX_STATE_PKT_TRANSFER_INIT;
            $display("CmacTxWrapper: Init CMAC Tx Datapath");
        end
    endrule

    rule statePktTransferInit if (txStateReg == TX_STATE_PKT_TRANSFER_INIT);
        ctlTxEnableReg <= True;
        if (isEnableFlowControl) begin
            ctlTxPauseEnableReg <= setAllBits;
        end
        else begin
            ctlTxPauseEnableReg <= 0;
        end
        ctlTxSendIdleReg <= False;
        ctlTxSendLocalFaultIndicationReg <= False;
        ctlTxSendRemoteFaultIndicationReg <= False;

        Bool initDone = unpack(initCounter[valueOf(CMAC_TX_INIT_DONE_FLAG_INDEX)]);
        if (!initDone) begin
            initCounter <= initCounter + 1;
        end

        if (!rxAlignedReg) begin
            txStateReg <= TX_STATE_IDLE;
        end
        else if (initDone && !txOverFlowReg && !txUnderFlowReg) begin
            $display("CmacTxWrapper: Start Transmitting Ethernet Packet");
            txStateReg <= TX_STATE_AXIS_ENABLE;
            initCounter <= 0;
        end
    endrule

    rule stateAxisEnable if (txStateReg == TX_STATE_AXIS_ENABLE);
        let axiStream = txAxiStreamIn.first;
        txAxiStreamIn.deq;
        txAxiStreamInterBuf.enq(axiStream);
        if (axiStream.tLast) begin
            packetReadyInfoBuf.enq(axiStream.tLast);
        end
        
        $display("CmacTxWrapper: CMAC Tx transmit ", fshow(axiStream));
        if (!rxAlignedReg) begin
            txStateReg <= TX_STATE_IDLE;
            $display("CmacTxWrapper: CMAC Tx IDLE");
        end
        else if (txOverFlowReg || txUnderFlowReg) begin
            $display("CmacTxWrapper: CMAC TX Path Halted !!");
            txStateReg <= TX_STATE_HALT;
        end
    endrule

    rule stateHalt if (txStateReg == TX_STATE_HALT);
        if (!rxAlignedReg) begin
            txStateReg <= TX_STATE_IDLE;

        end
        else if ((!txOverFlowReg) && (!txUnderFlowReg)) begin
            txStateReg <= TX_STATE_AXIS_ENABLE;
            $display("CmacTxWrapper: Restart Transmitting Ethernet Packet");
        end

    endrule

    rule genCtlTxPauseReq if (txStateReg == TX_STATE_AXIS_ENABLE);
        if (isTxPauseReqBusy) begin
            txPauseReqCounter <= txPauseReqCounter + 1;
            if (unpack(msb(txPauseReqCounter))) begin
                isTxPauseReqBusy <= False;
                ctlTxPauseReqReg <= 0;
            end
        end
        else begin
            let flowControlReqVec = txFlowCtrlReqVec.first;
            txFlowCtrlReqVec.deq;
            Vector#(VIRTUAL_CHANNEL_NUM, Bool) txPauseReqVec = replicate(False);
            for (Integer i = 0; i < valueOf(VIRTUAL_CHANNEL_NUM); i = i + 1) begin
                if (flowControlReqVec[i] matches tagged Valid .ctrlReq) begin
                    txPauseReqVec[i] = True;
                    if (ctrlReq == FLOW_CTRL_PASS) begin
                        ctlTxPauseQuantaRegVec[i] <= 0;
                    end
                    else begin
                        ctlTxPauseQuantaRegVec[i] <= setAllBits;
                    end
                end
            end
            ctlTxPauseReqReg <= pack(txPauseReqVec);
            isTxPauseReqBusy <= True;
        end
    endrule

    rule genFullPacketAxiStreamOut;
        let packetReady = packetReadyInfoBuf.first;
        let axiStream = txAxiStreamInterBuf.first;
        txAxiStreamInterBuf.deq;
        txAxiStreamOutBuf.enq(axiStream);
        if (axiStream.tLast == packetReady) begin
            packetReadyInfoBuf.deq;
        end
    endrule
    
    let rawAxiStreamBus <- mkPipeOutToRawAxiStreamMaster(convertFifoToPipeOut(txAxiStreamOutBuf));
    interface txRawAxiStreamOut = rawAxiStreamBus;

    method Bool ctlTxReset = False;
    method Bool ctlTxEnable = ctlTxEnableReg;
    method Bool ctlTxTestPattern = ctlTxTestPatternReg;
    method Bool ctlTxSendIdle = ctlTxSendIdleReg;
    method Bool ctlTxSendLocalFaultIndication = ctlTxSendLocalFaultIndicationReg;
    method Bool ctlTxSendRemoteFaultIndication = ctlTxSendRemoteFaultIndicationReg;

    // PFC Control Output
    method Bit#(CMAC_PAUSE_ENABLE_WIDTH) ctlTxPauseEnable = zeroExtend(ctlTxPauseEnableReg);
    method Bit#(CMAC_PAUSE_REQ_WIDTH) ctlTxPauseReq = zeroExtend(ctlTxPauseReqReg);
    method PfcPauseQuanta ctlTxPauseQuanta0 = ctlTxPauseQuantaRegVec[0];
    method PfcPauseQuanta ctlTxPauseQuanta1 = ctlTxPauseQuantaRegVec[1];
    method PfcPauseQuanta ctlTxPauseQuanta2 = ctlTxPauseQuantaRegVec[2];
    method PfcPauseQuanta ctlTxPauseQuanta3 = ctlTxPauseQuantaRegVec[3];
    method PfcPauseQuanta ctlTxPauseQuanta4 = ctlTxPauseQuantaRegVec[4];
    method PfcPauseQuanta ctlTxPauseQuanta5 = ctlTxPauseQuantaRegVec[5];
    method PfcPauseQuanta ctlTxPauseQuanta6 = ctlTxPauseQuantaRegVec[6];
    method PfcPauseQuanta ctlTxPauseQuanta7 = ctlTxPauseQuantaRegVec[7];
    method PfcPauseQuanta ctlTxPauseQuanta8 = 0;

    method Action cmacTxStatus(Bool txOverFlow, Bool txUnderFlow, Bool rxAligned);
        txOverFlowReg <= txOverFlow;
        txUnderFlowReg <= txUnderFlow;
        rxAlignedReg <= !isWaitRxAligned || rxAligned;
    endmethod
endmodule

(* always_ready, always_enabled *)
interface XilinxCmacRxWrapper;
    // Raw AxiStream Interface
    (* prefix = "rx_axis" *)
    interface RawAxiStreamSlave#(AXIS_TKEEP_WIDTH, AXIS_TUSER_WIDTH) rxRawAxiStreamIn;

    // CMAC Control Output
    (* result = "rx_ctl_enable" *)
    method Bool ctlRxEnable;
    (* result = "rx_ctl_force_resync" *)
    method Bool ctlRxForceResync;
    (* result = "rx_ctl_test_pattern" *)
    method Bool ctlRxTestPattern;
    (* result = "rx_ctl_reset" *)
    method Bool ctlRxReset;

    // Pause Control Output
    (* result =  "rx_ctl_pause_enable" *)
    method Bit#(CMAC_PAUSE_ENABLE_WIDTH) ctlRxPauseEnable;
    (* result =  "rx_ctl_pause_ack" *)
    method Bit#(CMAC_PAUSE_ACK_WIDTH) ctlRxPauseAck;

    (* result = "rx_ctl_enable_gcp" *)
    method Bool ctlRxCheckEnableGcp;
    (* result = "rx_ctl_check_mcast_gcp" *)
    method Bool ctlRxCheckMcastGcp;
    (* result = "rx_ctl_check_ucast_gcp" *)
    method Bool ctlRxCheckUcastGcp;
    (* result = "rx_ctl_check_sa_gcp" *)
    method Bool ctlRxCheckSaGcp;
    (* result = "rx_ctl_check_etype_gcp" *)
    method Bool ctlRxCheckEtypeGcp;
    (* result = "rx_ctl_check_opcode_gcp" *)
    method Bool ctlRxCheckOpcodeGcp;
    
    (* result = "rx_ctl_enable_pcp" *)
    method Bool ctlRxCheckEnablePcp;
    (* result = "rx_ctl_check_mcast_pcp" *)
    method Bool ctlRxCheckMcastPcp;
    (* result = "rx_ctl_check_ucast_pcp" *)
    method Bool ctlRxCheckUcastPcp;
    (* result = "rx_ctl_check_sa_pcp" *)
    method Bool ctlRxCheckSaPcp;
    (* result = "rx_ctl_check_etype_pcp" *)
    method Bool ctlRxCheckEtypePcp;
    (* result = "rx_ctl_check_opcode_pcp" *)
    method Bool ctlRxCheckOpcodePcp;

    (* result = "rx_ctl_enable_gpp" *)
    method Bool ctlRxCheckEnableGpp;
    (* result = "rx_ctl_check_mcast_gpp" *)
    method Bool ctlRxCheckMcastGpp;
    (* result = "rx_ctl_check_ucast_gpp" *)
    method Bool ctlRxCheckUcastGpp;
    (* result = "rx_ctl_check_sa_gpp" *)
    method Bool ctlRxCheckSaGpp;
    (* result = "rx_ctl_check_etype_gpp" *)
    method Bool ctlRxCheckEtypeGpp;
    (* result = "rx_ctl_check_opcode_gpp" *)
    method Bool ctlRxCheckOpcodeGpp;

    (* result = "rx_ctl_enable_ppp" *)
    method Bool ctlRxCheckEnablePpp;
    (* result = "rx_ctl_check_mcast_ppp" *)
    method Bool ctlRxCheckMcastPpp;
    (* result = "rx_ctl_check_ucast_ppp" *)
    method Bool ctlRxCheckUcastPpp;
    (* result = "rx_ctl_check_sa_ppp" *)
    method Bool ctlRxCheckSaPpp;
    (* result = "rx_ctl_check_etype_ppp" *)
    method Bool ctlRxCheckEtypePpp;
    (* result = "rx_ctl_check_opcode_ppp" *)
    method Bool ctlRxCheckOpcodePpp;
    
    // CMAC Status Input
    (* prefix = "" *) method Action cmacRxStatus(
        (* port = "rx_stat_aligned" *) Bool rxAligned,
        (* port = "rx_stat_pause_req" *) Bit#(CMAC_PAUSE_REQ_WIDTH) rxPauseReq
    );
endinterface

typedef enum {
    RX_STATE_IDLE,
    RX_STATE_GT_LOCKED,
    RX_STATE_WAIT_RX_ALIGNED,
    RX_STATE_AXIS_ENABLE
} CmacRxWrapperState deriving(Bits, Eq, FShow);

typedef struct {
    Bit#(PKT_INDEX_WIDTH) pktIdx;
    Bit#(FRAME_INDEX_WIDTH) frameIdx;
    AxiStream512 axiStream;
} AxiStream512WithTag deriving(Bits, FShow);

typedef struct {
    Bit#(PKT_INDEX_WIDTH) pktIdx;
    Bit#(FRAME_INDEX_WIDTH) frameNum;
} FaultPktInfo deriving(Bits, Eq, FShow);

module mkXilinxCmacRxWrapper#(
    Bool isEnableFlowControl,
    AxiStream512PipeIn rxAxiStreamOut,
    PipeIn#(FlowControlReqVec) rxFlowCtrlReqVec
)(XilinxCmacRxWrapper);
    Reg#(Bool) ctlRxEnableReg <- mkReg(False);
    Reg#(Bool) ctlRxForceResyncReg <- mkReg(False);
    Reg#(Bool) ctlRxTestPatternReg <- mkReg(False);
    Reg#(Bit#(VIRTUAL_CHANNEL_NUM)) ctlRxPauseEnableReg <- mkReg(0);
    Reg#(Bit#(VIRTUAL_CHANNEL_NUM)) ctlRxPauseAckReg <- mkReg(0);

    Reg#(Bool) rxAlignedReg <- mkReg(False);
    Reg#(Bit#(VIRTUAL_CHANNEL_NUM)) rxPauseReqReg <- mkRegU;
    
    Wire#(Maybe#(AxiStream512)) rxAxiStreamInW <- mkBypassWire;

    Reg#(Bool) isThrowFaultFrame <- mkReg(False);
    Reg#(Bit#(PKT_INDEX_WIDTH)) bufInputPktCount <- mkReg(0);
    Reg#(Bit#(FRAME_INDEX_WIDTH)) bufInputFrameCount <- mkReg(0);
    FIFOF#(FaultPktInfo) faultPktInfoBuf <- mkSizedFIFOF(valueOf(CMAC_INTER_BUF_DEPTH));
    FIFOF#(AxiStream512WithTag) rxAxiStreamInterBuf <- mkSizedBRAMFIFOF(valueOf(CMAC_INTER_BUF_DEPTH));


    Reg#(CmacRxWrapperState) rxStateReg <- mkReg(RX_STATE_IDLE);

    rule stateIdle if (rxStateReg == RX_STATE_IDLE);
        ctlRxEnableReg <= False;
        ctlRxForceResyncReg <= False;
        ctlRxTestPatternReg <= False;
        
        rxStateReg <= RX_STATE_GT_LOCKED;
    endrule

    rule stateGtLocked if (rxStateReg == RX_STATE_GT_LOCKED);
        ctlRxEnableReg <= True;
        ctlRxForceResyncReg <= False;
        ctlRxTestPatternReg <= False;
        if (isEnableFlowControl) begin
            ctlRxPauseEnableReg <= setAllBits;
        end
        else begin
            ctlRxPauseEnableReg <= 0;
        end
        rxStateReg <= RX_STATE_WAIT_RX_ALIGNED;
        $display("CmacRxWrapper: Wait CMAC Rx Aligned");
    endrule

    rule stateWaitRxAligned if (rxStateReg == RX_STATE_WAIT_RX_ALIGNED);
        if (rxAlignedReg) begin
            rxStateReg <= RX_STATE_AXIS_ENABLE;
            $display("CmacRxWrapper: Start Receiving Ethernet Packet");
        end
    endrule

    rule stateAxisEnable if (rxStateReg == RX_STATE_AXIS_ENABLE);
        if (!rxAlignedReg) begin
            rxStateReg <= RX_STATE_IDLE;
        end
    endrule

    // Drop whole packet when intermediate buffer is full
    rule enqRxAxiStreamInterBuf if (rxStateReg == RX_STATE_AXIS_ENABLE && isValid(rxAxiStreamInW));
        let rxAxiStream = fromMaybe(?, rxAxiStreamInW);
        if (rxAxiStream.tLast) begin
            bufInputPktCount <= bufInputPktCount + 1;
            bufInputFrameCount <= 0;
        end
        else begin
            bufInputFrameCount <= bufInputFrameCount + 1;
        end

        if (isThrowFaultFrame) begin
            isThrowFaultFrame <= !rxAxiStream.tLast;
        end
        else begin
            if (rxAxiStreamInterBuf.notFull) begin
                rxAxiStreamInterBuf.enq(
                    AxiStream512WithTag {
                        pktIdx: bufInputPktCount,
                        frameIdx: bufInputFrameCount,
                        axiStream: rxAxiStream
                    }
                );
            end
            else begin
                if (bufInputFrameCount != 0 ) begin
                    faultPktInfoBuf.enq(
                        FaultPktInfo {
                            pktIdx: bufInputPktCount,
                            frameNum: bufInputFrameCount
                        }
                    );
                end
                isThrowFaultFrame <= True;
            end            
        end
    endrule

    rule deqRxAxiStreamInterBuf;
        let rxAxiStreamWithTag = rxAxiStreamInterBuf.first;
        rxAxiStreamInterBuf.deq;

        let pktIdx = rxAxiStreamWithTag.pktIdx;
        let frameIdx = rxAxiStreamWithTag.frameIdx;
        let axiStream = rxAxiStreamWithTag.axiStream;

        if (faultPktInfoBuf.notEmpty) begin
            let faultPktInfo = faultPktInfoBuf.first;
            if (pktIdx == faultPktInfo.pktIdx) begin
                if (frameIdx == (faultPktInfo.frameNum - 1)) begin
                    faultPktInfoBuf.deq;
                end
            end
            else begin
                rxAxiStreamOut.enq(axiStream);
            end
        end
        else begin
            rxAxiStreamOut.enq(axiStream);
        end
    endrule

    rule genFlowControlReq;
        FlowControlReqVec flowCtrlReqVec = replicate(tagged Invalid);
        Bit#(VIRTUAL_CHANNEL_NUM) nextCtlRxPauseAck = ctlRxPauseAckReg;
        for (Integer i = 0; i < valueOf(VIRTUAL_CHANNEL_NUM); i = i + 1) begin
            if (ctlRxPauseAckReg[i] != rxPauseReqReg[i]) begin
                nextCtlRxPauseAck[i] = rxPauseReqReg[i];
                if (rxPauseReqReg[i] == 0) begin
                    flowCtrlReqVec[i] = tagged Valid FLOW_CTRL_PASS;
                end
                else begin
                    flowCtrlReqVec[i] = tagged Valid FLOW_CTRL_STOP;
                end
            end
        end
        ctlRxPauseAckReg <= nextCtlRxPauseAck;
        rxFlowCtrlReqVec.enq(flowCtrlReqVec);
    endrule

    method Bool ctlRxEnable = ctlRxEnableReg;
    method Bool ctlRxForceResync = ctlRxForceResyncReg;
    method Bool ctlRxTestPattern = ctlRxTestPatternReg;
    method Bool ctlRxReset = False;
    
    method Bit#(CMAC_PAUSE_ENABLE_WIDTH) ctlRxPauseEnable = zeroExtend(ctlRxPauseEnableReg);
    method Bit#(CMAC_PAUSE_ACK_WIDTH) ctlRxPauseAck = zeroExtend(ctlRxPauseAckReg);

    method Bool ctlRxCheckEnableGcp = False;
    method Bool ctlRxCheckMcastGcp = False;
    method Bool ctlRxCheckUcastGcp = False;
    method Bool ctlRxCheckSaGcp = False;
    method Bool ctlRxCheckEtypeGcp = False;
    method Bool ctlRxCheckOpcodeGcp = False;
    
    method Bool ctlRxCheckEnablePcp = True;
    method Bool ctlRxCheckMcastPcp = True;
    method Bool ctlRxCheckUcastPcp = False;
    method Bool ctlRxCheckSaPcp = False;
    method Bool ctlRxCheckEtypePcp = False;
    method Bool ctlRxCheckOpcodePcp = True;
    
    method Bool ctlRxCheckEnableGpp = False;
    method Bool ctlRxCheckMcastGpp = False;
    method Bool ctlRxCheckUcastGpp = False;
    method Bool ctlRxCheckSaGpp = False;
    method Bool ctlRxCheckEtypeGpp = False;
    method Bool ctlRxCheckOpcodeGpp = False;
    
    method Bool ctlRxCheckEnablePpp = True;
    method Bool ctlRxCheckMcastPpp = True;
    method Bool ctlRxCheckUcastPpp = False;
    method Bool ctlRxCheckSaPpp = False;
    method Bool ctlRxCheckEtypePpp = False;
    method Bool ctlRxCheckOpcodePpp = True;

    method Action cmacRxStatus(
        Bool rxAligned,
        Bit#(CMAC_PAUSE_REQ_WIDTH) rxPauseReq
    );
        rxAlignedReg <= rxAligned;
        rxPauseReqReg <= truncate(rxPauseReq);
    endmethod

    interface RawAxiStreamSlave rxRawAxiStreamIn;
        method Bool tReady = True;
        method Action tValid(
            Bool valid, 
            Bit#(AXIS_TDATA_WIDTH) tData, 
            Bit#(AXIS_TKEEP_WIDTH) tKeep, 
            Bool tLast, 
            Bit#(AXIS_TUSER_WIDTH) tUser
        );
            if (valid) begin
                rxAxiStreamInW <= tagged Valid AxiStream512 {
                    tData: tData,
                    tKeep: tKeep,
                    tLast: tLast,
                    tUser: tUser
                };
            end
            else begin
                rxAxiStreamInW <= tagged Invalid;
            end
        endmethod
    endinterface

endmodule


interface XilinxCmacRxTxWrapper;
    (* prefix = "" *)
    interface XilinxCmacTxWrapper cmacTxWrapper;
    (* prefix = "" *)
    interface XilinxCmacRxWrapper cmacRxWrapper;
endinterface


(* no_default_reset *)
module mkXilinxCmacRxTxWrapper#(
    Bool isEnableFlowControl,
    Bool isTxWaitRxAligned,
    AxiStream512PipeOut txAxiStream,
    AxiStream512PipeIn  rxAxiStream,
    PipeOut#(FlowControlReqVec) txFlowCtrlReqVec,
    PipeIn#(FlowControlReqVec) rxFlowCtrlReqVec
)(
    Reset cmacRxReset, 
    Reset cmacTxReset, 
    XilinxCmacRxTxWrapper ifc
);
    let txWrapper <- mkXilinxCmacTxWrapper(isEnableFlowControl, isTxWaitRxAligned, txAxiStream, txFlowCtrlReqVec, reset_by cmacTxReset);
    let rxWrapper <- mkXilinxCmacRxWrapper(isEnableFlowControl, rxAxiStream, rxFlowCtrlReqVec, reset_by cmacRxReset);

    interface cmacTxWrapper = txWrapper;
    interface cmacRxWrapper = rxWrapper;
endmodule

