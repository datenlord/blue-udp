import FIFOF :: *;
import GetPut :: *;
import Vector :: *;
import BRAMFIFO :: *;
import Connectable :: *;

import Ports :: *;
import EthUtils :: *;
import EthernetTypes :: *;
import StreamHandler :: *;

import SemiFifo :: *;
import BusConversion :: *;
import AxiStreamTypes :: *;

typedef 4 CMAC_CTRL_STATE_OUTPUT_WIDTH;
typedef 9 CMAC_TX_INIT_COUNT_WIDTH;
typedef 8 CMAC_TX_INIT_DONE_FLAG_INDEX;

typedef 6 CMAC_TX_PAUSE_REQ_COUNT_WIDTH;

//
//typedef 2500 MAX_PKT_BYTE_NUM;
typedef 4300 MAX_PKT_BYTE_NUM;
typedef TDiv#(MAX_PKT_BYTE_NUM, AXIS512_TKEEP_WIDTH) MAX_PKT_FRAME_NUM;
typedef TLog#(MAX_PKT_FRAME_NUM) FRAME_INDEX_WIDTH;
typedef MAX_PKT_FRAME_NUM CMAC_INTER_BUF_DEPTH;
typedef TLog#(CMAC_INTER_BUF_DEPTH) PKT_INDEX_WIDTH;

typedef 9 CMAC_PAUSE_ENABLE_WIDTH;
typedef 9 CMAC_PAUSE_REQ_WIDTH;
typedef 9 CMAC_PAUSE_ACK_WIDTH;

(* always_ready, always_enabled *)
interface XilinxCmacTxController;
    // CMAC AXI-Stream Bus
    (* prefix = "cmac_tx_axis" *)
    interface RawAxiStreamMaster#(AXIS512_TKEEP_WIDTH, AXIS_TUSER_WIDTH) rawCmacAxiStreamOut;

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
    
    // RS-FEC Control Output
    (* result = "tx_ctl_rsfec_enable" *)
    method Bool ctlTxRsFecEnable;

    // CMAC Controller Status Output
    (* result = "cmac_ctrl_tx_state" *)
    method Bit#(CMAC_CTRL_STATE_OUTPUT_WIDTH) ctrlTxState;

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
} CmacTxControllerState deriving(Bits, Eq, FShow);

module mkXilinxCmacTxController#(
    Bool isEnableRsFec,
    Bool isEnableFlowControl,
    Bool isWaitRxAligned,
    AxiStream512FifoOut userAxiStreamIn,
    FifoOut#(FlowControlReqVec) userFlowCtrlReqVecIn
)(XilinxCmacTxController);

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

    Reg#(Bool) ctlTxRsFecEnableReg <- mkReg(False);

    FIFOF#(AxiStream512) cmacAxiStreamOutBuf <- mkFIFOF;
    FIFOF#(AxiStream512) interAxiStreamBuf <- mkSizedBRAMFIFOF(valueOf(CMAC_INTER_BUF_DEPTH));
    FIFOF#(Bool) packetReadyInfoBuf <- mkSizedFIFOF(valueOf(CMAC_INTER_BUF_DEPTH));
    // interAxiStreamBuf and packetReadyInfoBuf is used to guarantee that:
    // AxiStream bus interacting with CMAC transfers one ethernet packet continuously without any empty cycles;
    // If there are any bubbles during the transfer of one packet, CMAC will fails;

    Reg#(CmacTxControllerState) txStateReg <- mkReg(TX_STATE_IDLE);
    Reg#(Bit#(CMAC_TX_INIT_COUNT_WIDTH)) initCounter <- mkReg(0);
    Reg#(Bool) isTxPauseReqBusy <- mkReg(False);
    Reg#(Bit#(CMAC_TX_PAUSE_REQ_COUNT_WIDTH)) txPauseReqCounter <- mkReg(0);

    rule stateIdle if (txStateReg == TX_STATE_IDLE);
        ctlTxEnableReg <= False;
        ctlTxTestPatternReg <= False;
        ctlTxSendIdleReg <= False;
        ctlTxSendLocalFaultIndicationReg <= False;
        ctlTxSendRemoteFaultIndicationReg <= False;
        ctlTxRsFecEnableReg <= False;

        txStateReg <= TX_STATE_GT_LOCKED;
    endrule

    rule stateGtLocked if (txStateReg == TX_STATE_GT_LOCKED);
        ctlTxEnableReg <= False;
        ctlTxSendIdleReg <= False;
        ctlTxSendLocalFaultIndicationReg <= False;
        ctlTxSendRemoteFaultIndicationReg <= True;
        ctlTxRsFecEnableReg <= isEnableRsFec;
        txStateReg <= TX_STATE_WAIT_RX_ALIGNED;
        $display("CmacTxController: Wait CMAC Rx Algined Ready");
    endrule

    rule stateWaitRxAligned if (txStateReg == TX_STATE_WAIT_RX_ALIGNED);
        if (rxAlignedReg) begin
            txStateReg <= TX_STATE_PKT_TRANSFER_INIT;
            $display("CmacTxController: Init CMAC Tx Datapath");
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
            $display("CmacTxController: Start Transmitting Ethernet Packet");
            txStateReg <= TX_STATE_AXIS_ENABLE;
            initCounter <= 0;
        end
    endrule

    rule stateAxisEnable if (txStateReg == TX_STATE_AXIS_ENABLE);
        let axiStream = userAxiStreamIn.first;
        userAxiStreamIn.deq;
        interAxiStreamBuf.enq(axiStream);
        if (axiStream.tLast) begin
            packetReadyInfoBuf.enq(axiStream.tLast);
        end
        
        $display("CmacTxController: CMAC Tx transmit ", fshow(axiStream));
        if (!rxAlignedReg) begin
            txStateReg <= TX_STATE_IDLE;
            $display("CmacTxController: CMAC Tx IDLE");
        end
        else if (txOverFlowReg || txUnderFlowReg) begin
            $display("CmacTxController: CMAC TX Path Halted !!");
            txStateReg <= TX_STATE_HALT;
        end
    endrule

    rule stateHalt if (txStateReg == TX_STATE_HALT);
        if (!rxAlignedReg) begin
            txStateReg <= TX_STATE_IDLE;

        end
        else if ((!txOverFlowReg) && (!txUnderFlowReg)) begin
            txStateReg <= TX_STATE_AXIS_ENABLE;
            $display("CmacTxController: Restart Transmitting Ethernet Packet");
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
            let flowControlReqVec = userFlowCtrlReqVecIn.first;
            userFlowCtrlReqVecIn.deq;
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
        let axiStream = interAxiStreamBuf.first;
        interAxiStreamBuf.deq;

        cmacAxiStreamOutBuf.enq(axiStream);
        if (axiStream.tLast == packetReady) begin
            packetReadyInfoBuf.deq;
        end
    endrule
    
    let rawCmacAxiStream <- mkFifoOutToRawAxiStreamMaster(convertFifoToFifoOut(cmacAxiStreamOutBuf));
    interface rawCmacAxiStreamOut = rawCmacAxiStream;

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

    method Bool ctlTxRsFecEnable = ctlTxRsFecEnableReg;

    method Bit#(CMAC_CTRL_STATE_OUTPUT_WIDTH) ctrlTxState = zeroExtend(pack(txStateReg));
    
    method Action cmacTxStatus(Bool txOverFlow, Bool txUnderFlow, Bool rxAligned);
        txOverFlowReg <= txOverFlow;
        txUnderFlowReg <= txUnderFlow;
        rxAlignedReg <= !isWaitRxAligned || rxAligned;
    endmethod
endmodule

(* always_ready, always_enabled *)
interface XilinxCmacRxController;
    // CMAC AXI-Stream Bus
    (* prefix = "cmac_rx_axis" *)
    interface RawAxiStreamSlave#(AXIS512_TKEEP_WIDTH, AXIS_TUSER_WIDTH) rxRawAxiStreamIn;

    // CMAC Control Output
    (* result = "rx_ctl_enable" *)
    method Bool ctlRxEnable;
    (* result = "rx_ctl_force_resync" *)
    method Bool ctlRxForceResync;
    (* result = "rx_ctl_test_pattern" *)
    method Bool ctlRxTestPattern;
    (* result = "rx_ctl_reset" *)
    method Bool ctlRxReset;

    // CMAC Pause Control Output
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

    // CMAC RS-FEC Control Output
    (* result = "ctl_rsfec_ieee_error_indication_mode" *)
    method Bool ctlRsFecIeeeErrorIndicationMode;
    (* result = "rx_ctl_rsfec_enable" *)
    method Bool ctlRxRsFecEnable;
    (* result = "rx_ctl_rsfec_enable_correction" *)
    method Bool ctlRxRsFecEnableCorrection;
    (* result = "rx_ctl_rsfec_enable_indication" *)
    method Bool ctlRxRsFecEnableIndication;
    
    // Controller Status Output
    (* result = "cmac_ctrl_rx_state" *)
    method Bit#(CMAC_CTRL_STATE_OUTPUT_WIDTH) ctrlRxState;
    (* result = "cmac_rx_aligned_indication" *)
    method Bool cmacRxAlignedIndication;

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
} CmacRxControllerState deriving(Bits, Eq, FShow);

typedef struct {
    Bit#(FRAME_INDEX_WIDTH) frameIdx;
    AxiStream512 axiStream;
} AxiStream512WithTag deriving(Bits, FShow);

typedef struct {
    Bit#(PKT_INDEX_WIDTH) pktIdx;
    Bit#(FRAME_INDEX_WIDTH) frameNum;
} FaultPktInfo deriving(Bits, Eq, FShow);

typedef struct {
    Bool isGoodPkt;
    Bit#(FRAME_INDEX_WIDTH) frameIdx;
} PktIntegrityInfo deriving(Bits, Eq, FShow);

module mkXilinxCmacRxController#(
    Bool isEnableRsFec,
    Bool isEnableFlowControl,
    AxiStream512FifoIn userAxiStreamOut,
    FifoIn#(FlowControlReqVec) userFlowCtrlReqVecOut
)(XilinxCmacRxController);
    Reg#(Bool) ctlRxEnableReg <- mkReg(False);
    Reg#(Bool) ctlRxForceResyncReg <- mkReg(False);
    Reg#(Bool) ctlRxTestPatternReg <- mkReg(False);
    Reg#(Bit#(VIRTUAL_CHANNEL_NUM)) ctlRxPauseEnableReg <- mkReg(0);
    Reg#(Bit#(VIRTUAL_CHANNEL_NUM)) ctlRxPauseAckReg <- mkReg(0);

    Reg#(Bool) ctlRsFecIeeeErrorIndicationModeReg <- mkReg(False);
    Reg#(Bool) ctlRxRsFecEnableReg <- mkReg(False);
    Reg#(Bool) ctlRxRsFecEnableCorrectionReg <- mkReg(False);
    Reg#(Bool) ctlRxRsFecEnableIndicationReg <- mkReg(False);

    Reg#(Bool) rxAlignedReg <- mkReg(False);
    Reg#(Bit#(VIRTUAL_CHANNEL_NUM)) rxPauseReqReg <- mkRegU;
    
    Wire#(Maybe#(AxiStream512)) rxAxiStreamInW <- mkBypassWire;

    Reg#(Bool) isThrowFaultFrame <- mkReg(False);
    Reg#(Bit#(FRAME_INDEX_WIDTH)) frameIdxCounter <- mkReg(0);
    
    FIFOF#(PktIntegrityInfo) pktIntegrityInfoBuf <- mkSizedFIFOF(valueOf(CMAC_INTER_BUF_DEPTH));
    FIFOF#(AxiStream512WithTag) rxAxiStreamInterBuf <- mkSizedBRAMFIFOF(valueOf(CMAC_INTER_BUF_DEPTH));
    FIFOF#(AxiStream512) rxAxiStreamOutBuf <- mkFIFOF;
    
    Reg#(CmacRxControllerState) rxStateReg <- mkReg(RX_STATE_IDLE);

    rule stateIdle if (rxStateReg == RX_STATE_IDLE);
        ctlRxEnableReg <= False;
        ctlRxForceResyncReg <= False;
        ctlRxTestPatternReg <= False;

        ctlRsFecIeeeErrorIndicationModeReg <= False;
        ctlRxRsFecEnableReg <= False;
        ctlRxRsFecEnableCorrectionReg <= False;
        ctlRxRsFecEnableIndicationReg <= False;
        
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

        ctlRsFecIeeeErrorIndicationModeReg <= isEnableRsFec;
        ctlRxRsFecEnableReg <= isEnableRsFec;
        ctlRxRsFecEnableCorrectionReg <= isEnableRsFec;
        ctlRxRsFecEnableIndicationReg <= isEnableRsFec;

        rxStateReg <= RX_STATE_WAIT_RX_ALIGNED;
        $display("CmacRxController: Wait CMAC Rx Aligned");
    endrule

    rule stateWaitRxAligned if (rxStateReg == RX_STATE_WAIT_RX_ALIGNED);
        if (rxAlignedReg) begin
            rxStateReg <= RX_STATE_AXIS_ENABLE;
            $display("CmacRxController: Start Receiving Ethernet Packet");
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
            frameIdxCounter <= 0;
        end
        else begin
            frameIdxCounter <= frameIdxCounter + 1;
        end

        if (isThrowFaultFrame) begin
            isThrowFaultFrame <= !rxAxiStream.tLast;
        end
        else begin
            // check if frame is corrupted or inter buffer is full
            if (rxAxiStreamInterBuf.notFull && rxAxiStream.tUser==0) begin
                rxAxiStreamInterBuf.enq(
                    AxiStream512WithTag {
                        frameIdx: frameIdxCounter,
                        axiStream: rxAxiStream
                    }
                );
                if (rxAxiStream.tLast) begin
                    pktIntegrityInfoBuf.enq(
                        PktIntegrityInfo {
                            isGoodPkt: True,
                            frameIdx: frameIdxCounter
                        }
                    );
                end
            end
            else begin
                if (frameIdxCounter != 0) begin
                    pktIntegrityInfoBuf.enq(
                        PktIntegrityInfo {
                            isGoodPkt: False,
                            frameIdx: frameIdxCounter - 1
                        }
                    );
                end
                isThrowFaultFrame <= !rxAxiStream.tLast;

            end            
        end
    endrule

    rule deqRxAxiStreamInterBuf if (pktIntegrityInfoBuf.notEmpty);
        let rxAxiStreamWithTag = rxAxiStreamInterBuf.first;
        rxAxiStreamInterBuf.deq;
        let pktIntegrityInfo = pktIntegrityInfoBuf.first;

        let frameIdx = rxAxiStreamWithTag.frameIdx;
        let axiStream = rxAxiStreamWithTag.axiStream;

        if (pktIntegrityInfo.isGoodPkt) begin
            rxAxiStreamOutBuf.enq(axiStream);
        end
        
        if (pktIntegrityInfo.frameIdx == frameIdx) begin
            pktIntegrityInfoBuf.deq;
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
        userFlowCtrlReqVecOut.enq(flowCtrlReqVec);
    endrule

    mkConnection(userAxiStreamOut, convertFifoToFifoOut(rxAxiStreamOutBuf));
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

    method Bool ctlRsFecIeeeErrorIndicationMode = ctlRsFecIeeeErrorIndicationModeReg;
    method Bool ctlRxRsFecEnable = ctlRxRsFecEnableReg;
    method Bool ctlRxRsFecEnableCorrection = ctlRxRsFecEnableCorrectionReg;
    method Bool ctlRxRsFecEnableIndication = ctlRxRsFecEnableIndicationReg;

    method Bit#(CMAC_CTRL_STATE_OUTPUT_WIDTH) ctrlRxState = zeroExtend(pack(rxStateReg));
    method Bool cmacRxAlignedIndication = (rxStateReg == RX_STATE_AXIS_ENABLE);

    method Action cmacRxStatus(
        Bool rxAligned,
        Bit#(CMAC_PAUSE_REQ_WIDTH) rxPauseReq
    );
        rxAlignedReg <= rxAligned;
        rxPauseReqReg <= truncate(rxPauseReq);
    endmethod

    interface RawAxiStreamSlave rxRawAxiStreamIn;
        method Bool tReady = rxAxiStreamInterBuf.notFull;
        method Action tValid(
            Bool valid,
            Bit#(AXIS512_TDATA_WIDTH) tData, 
            Bit#(AXIS512_TKEEP_WIDTH) tKeep, 
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


interface XilinxCmacController;
    (* prefix = "" *)
    interface XilinxCmacTxController cmacTxController;
    (* prefix = "" *)
    interface XilinxCmacRxController cmacRxController;
endinterface

module mkXilinxCmacController#(
    Bool isEnableRsFec,
    Bool isEnableFlowControl,
    Bool isTxWaitRxAligned,
    AxiStream512FifoOut userAxiStreamIn,
    AxiStream512FifoIn  userAxiStreamOut,
    FifoOut#(FlowControlReqVec) userFlowCtrlReqVecIn,
    FifoIn#(FlowControlReqVec) userFlowCtrlReqVecOut
)(
    (* reset = "cmac_rx_reset" *) Reset cmacRxReset,
    (* reset = "cmac_tx_reset" *) Reset cmacTxReset,
    XilinxCmacController ifc
);

    let txController <- mkXilinxCmacTxController(
        isEnableRsFec,
        isEnableFlowControl, 
        isTxWaitRxAligned,
        userAxiStreamIn,
        userFlowCtrlReqVecIn,
        reset_by cmacTxReset
    );

    let rxController <- mkXilinxCmacRxController(
        isEnableRsFec,
        isEnableFlowControl,
        userAxiStreamOut,
        userFlowCtrlReqVecOut,
        reset_by cmacRxReset
    );

    interface cmacRxController = rxController;
    interface cmacTxController = txController;
endmodule

interface RawXilinxCmacController;
    // Interface with User Logic
    (* prefix = "user_tx_axis" *)
    interface RawAxiStreamSlave#(AXIS512_TKEEP_WIDTH, AXIS_TUSER_WIDTH) rawUserAxiStreamTxIn;
    (* prefix = "user_tx_flowctrl" *)
    interface RawBusSlave#(FlowControlReqVec) rawUserFlowCtrlReqVecTxIn;
    
    (* prefix = "user_rx_axis" *)
    interface RawAxiStreamMaster#(AXIS512_TKEEP_WIDTH, AXIS_TUSER_WIDTH) rawUserAxiStreamRxOut;
    (* prefix = "user_rx_flowctrl" *)
    interface RawBusMaster#(FlowControlReqVec) rawUserFlowCtrlReqVecRxOut;
    
    // Interface with CMAC
    (* prefix = "" *)
    interface XilinxCmacController xilinxCmacRxTx;
endinterface

(* synthesize, no_default_reset, default_clock_osc = "cmac_clk" *)
module mkRawXilinxCmacController(
    (* reset = "cmac_rx_reset" *) Reset cmacRxReset,
    (* reset = "cmac_tx_reset" *) Reset cmacTxReset,
    RawXilinxCmacController ifc
);
    Bool isEnableRsFec = False;
    Bool isEnableFlowControl = False;
    Bool isTxWaitRxAligned = True;

    FIFOF#(AxiStream512) userAxiStreamTxInBuf <- mkFIFOF(reset_by cmacTxReset);
    FIFOF#(AxiStream512) userAxiStreamRxOutBuf <- mkFIFOF(reset_by cmacRxReset);
    FIFOF#(FlowControlReqVec) userFlowCtrlReqVecTxInBuf <- mkFIFOF(reset_by cmacTxReset);
    FIFOF#(FlowControlReqVec) userFlowCtrlReqVecRxOutBuf <- mkFIFOF(reset_by cmacRxReset);

    let cmacController <- mkXilinxCmacController(
        isEnableRsFec,
        isEnableFlowControl,
        isTxWaitRxAligned,
        convertFifoToFifoOut(userAxiStreamTxInBuf ),
        convertFifoToFifoIn (userAxiStreamRxOutBuf),
        convertFifoToFifoOut(userFlowCtrlReqVecTxInBuf),
        convertFifoToFifoIn (userFlowCtrlReqVecRxOutBuf),
        cmacRxReset,
        cmacTxReset
    );

    let userAxiStreamTxIn <- mkFifoInToRawAxiStreamSlave(
        convertFifoToFifoIn(userAxiStreamTxInBuf),
        reset_by cmacTxReset
    );
    let userAxiStreamRxOut <- mkFifoOutToRawAxiStreamMaster(
        convertFifoToFifoOut(userAxiStreamRxOutBuf),
        reset_by cmacRxReset
    );
    let userFlowCtrlReqVecTxIn <- mkFifoInToRawBusSlave(
        convertFifoToFifoIn(userFlowCtrlReqVecTxInBuf),
        reset_by cmacTxReset
    );
    let userFlowCtrlReqVecRxOut <- mkFifoOutToRawBusMaster(
        convertFifoToFifoOut(userFlowCtrlReqVecRxOutBuf),
        reset_by cmacRxReset
    );
    
    interface xilinxCmacRxTx = cmacController;
    interface rawUserAxiStreamTxIn = userAxiStreamTxIn;
    interface rawUserAxiStreamRxOut = userAxiStreamRxOut;
    interface rawUserFlowCtrlReqVecTxIn = userFlowCtrlReqVecTxIn;
    interface rawUserFlowCtrlReqVecRxOut = userFlowCtrlReqVecRxOut;

endmodule

