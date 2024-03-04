import FIFOF :: *;

import Ports :: *;
import EthUtils :: *;

import SemiFifo :: *;
import AxiStreamTypes :: *;

typedef 32 PERF_CYCLE_COUNT_WIDTH;
typedef 32 PERF_BEAT_COUNT_WIDTH;
typedef 32 PKT_NUM_COUNT_WIDTH;
typedef 32 PKT_SIZE_COUNT_WIDTH;

interface PerfMonitorRegister;
    // Dynamic Configuration Register
    method Bit#(PKT_SIZE_COUNT_WIDTH)   pktSizeOut;
    method Bit#(PERF_CYCLE_COUNT_WIDTH) pktIntervalOut;
    // Performance Counter
    method Bit#(PERF_CYCLE_COUNT_WIDTH) perfCycleCounterTxOut;
    method Bit#(PERF_CYCLE_COUNT_WIDTH) perfCycleCounterRxOut;
    method Bit#(PERF_BEAT_COUNT_WIDTH) perfBeatCounterTxOut;
    method Bit#(PERF_BEAT_COUNT_WIDTH) perfBeatCounterRxOut;
    method Bit#(PERF_BEAT_COUNT_WIDTH) totalBeatCounterTxOut;
    method Bit#(PERF_BEAT_COUNT_WIDTH) totalBeatCounterRxOut;
    method Bool perfCycleCountFullTxOut;
    method Bool perfCycleCountFullRxOut;
    method Bool sendPktEnableOut;
    method Bool recvPktEnableOut;
    method Bool isRecvFirstPktOut;
    method Bit#(PKT_NUM_COUNT_WIDTH) sendPktNumCounterOut;
    method Bit#(PKT_NUM_COUNT_WIDTH) recvPktNumCounterOut;
    method Bit#(PKT_NUM_COUNT_WIDTH) errPktNumCounterOut;
endinterface

interface UdpCmacPerfMonitor;
    (* prefix = "xdma_tx_axis" *)
    interface RawAxiStreamSlave#(AXIS512_TKEEP_WIDTH, AXIS_TUSER_WIDTH) xdmaAxiStreamIn;
    (* prefix = "xdma_rx_axis" *)
    interface RawAxiStreamMaster#(AXIS512_TKEEP_WIDTH, AXIS_TUSER_WIDTH) xdmaAxiStreamOut;
    
    (* prefix = "udp_rx_axis" *)
    interface RawAxiStreamSlave#(AXIS512_TKEEP_WIDTH, AXIS_TUSER_WIDTH) udpAxiStreamRxIn;
    (* prefix = "udp_tx_axis" *)
    interface RawAxiStreamMaster#(AXIS512_TKEEP_WIDTH, AXIS_TUSER_WIDTH) udpAxiStreamTxOut;
    
    (* prefix = "", always_enabled, always_ready *)
    interface PerfMonitorRegister perfMonReg;

endinterface

(* synthesize *)
module mkUdpCmacPerfMonitor(UdpCmacPerfMonitor);

    FIFOF#(AxiStream512) xdmaAxiStreamInBuf <- mkFIFOF;
    FIFOF#(AxiStream512) xdmaAxiStreamOutBuf <- mkFIFOF;
    FIFOF#(AxiStream512) udpAxiStreamRxInBuf <- mkFIFOF;
    FIFOF#(AxiStream512) udpAxiStreamTxOutBuf <- mkFIFOF;
    
    Reg#(Bool) isPktIntervalReg <- mkReg(False);
    Reg#(Bit#(PERF_CYCLE_COUNT_WIDTH)) pktIntervalReg <- mkReg(0);
    Reg#(Bit#(PERF_CYCLE_COUNT_WIDTH)) pktIntervalCounter <- mkReg(0);

    Reg#(Bool) perfCycleCountFullTx[2] <- mkCReg(2, False);
    Reg#(Bool) perfCycleCountFullRx <- mkReg(False);
    
    Reg#(Bit#(PERF_CYCLE_COUNT_WIDTH)) maxPerfCycleNumReg <- mkReg(0);

    Reg#(Bit#(PERF_CYCLE_COUNT_WIDTH)) perfCycleCounterTx <- mkReg(0);
    Reg#(Bit#(PERF_BEAT_COUNT_WIDTH))  perfBeatCounterTx <- mkReg(0);
    Reg#(Bit#(PERF_BEAT_COUNT_WIDTH))  totalBeatCounterTx <- mkReg(0);

    Reg#(Bit#(PERF_CYCLE_COUNT_WIDTH)) perfCycleCounterRx <- mkReg(0);
    Reg#(Bit#(PERF_BEAT_COUNT_WIDTH))  perfBeatCounterRx[2] <- mkCReg(2, 0);
    Reg#(Bit#(PERF_BEAT_COUNT_WIDTH))  totalBeatCounterRx[2] <- mkCReg(2, 0);

    Reg#(Bit#(PKT_SIZE_COUNT_WIDTH)) pktSizeReg <- mkReg(0);
    Reg#(Bit#(PKT_SIZE_COUNT_WIDTH)) sendPktBeatCounter <- mkReg(0);
    Reg#(Bit#(PKT_SIZE_COUNT_WIDTH)) recvPktBeatCounter <- mkReg(0);

    Reg#(Bit#(PKT_NUM_COUNT_WIDTH)) sendPktNumCounter <- mkReg(0);
    Reg#(Bit#(PKT_NUM_COUNT_WIDTH)) recvPktNumCounter[2] <- mkCReg(2, 0);
    Reg#(Bit#(PKT_NUM_COUNT_WIDTH)) errPktNumCounter[2] <- mkCReg(2, 0);

    Reg#(Bool) sendPktEnableReg <- mkReg(False);
    Reg#(Bool) recvPktEnableReg <- mkReg(False);
    Reg#(Bool) isRecvFirstPktReg[2] <- mkCReg(2, False);
    Reg#(Bool) isPktHasErrorReg <- mkReg(False);

    let monitorBusy = sendPktEnableReg || recvPktEnableReg;

    rule configMonitor if (!monitorBusy);
        let axiFrame = xdmaAxiStreamInBuf.first;
        let perfMonConfig = axiFrame.tData;
        xdmaAxiStreamInBuf.deq;
        Bit#(PKT_SIZE_COUNT_WIDTH) pktSize = truncate(perfMonConfig);
        let pktInterval = perfMonConfig >> valueOf(PKT_SIZE_COUNT_WIDTH);
        let maxPerfCycleNum = pktInterval >> valueOf(PERF_CYCLE_COUNT_WIDTH);
        pktSizeReg <= pktSize;
        pktIntervalReg <= truncate(pktInterval);
        maxPerfCycleNumReg <= truncate(maxPerfCycleNum);
        if (pktSize != 0) begin
            sendPktEnableReg <= True;
            recvPktEnableReg <= True;
            perfCycleCountFullTx[1] <= False;
            perfCycleCountFullRx <= False;
            perfCycleCounterTx <= 0;
            perfCycleCounterRx <= 0;
            perfBeatCounterTx <= 0;
            perfBeatCounterRx[1] <= 0;
            totalBeatCounterTx <= 0;
            totalBeatCounterRx[1] <= 0;
            sendPktNumCounter <= 0;
            recvPktNumCounter[1] <= 0;
            errPktNumCounter[1] <= 0;
            isRecvFirstPktReg[1] <= False;
        end
    endrule

    rule sendPacket if (sendPktEnableReg && !isPktIntervalReg);

        let axiFrame = AxiStream512 {
            tData: {sendPktBeatCounter, 0, sendPktBeatCounter},
            tKeep: setAllBits,
            tLast: False,
            tUser: 0
        };

        if (sendPktBeatCounter == pktSizeReg - 1) begin
            axiFrame.tLast = True;
            sendPktBeatCounter <= 0;
            if (perfCycleCountFullTx[1]) begin
                sendPktEnableReg <= False;
            end
            else if (pktIntervalReg != 0) begin
                isPktIntervalReg <= True;
            end
            sendPktNumCounter <= sendPktNumCounter + 1;
        end
        else begin
            sendPktBeatCounter <= sendPktBeatCounter + 1;
        end
        
        udpAxiStreamTxOutBuf.enq(axiFrame);
        totalBeatCounterTx <= totalBeatCounterTx + 1;
        if (!perfCycleCountFullTx[1]) begin
            perfBeatCounterTx <= perfBeatCounterTx + 1;
        end
    endrule

    rule countPktInterval if (sendPktEnableReg && isPktIntervalReg);
        if (pktIntervalCounter == pktIntervalReg - 1) begin
            pktIntervalCounter <= 0;
            isPktIntervalReg <= False;
        end
        else begin
            pktIntervalCounter <= pktIntervalCounter + 1;
        end
    endrule

    rule countPerfCycleTx if (sendPktEnableReg);
        if (!perfCycleCountFullTx[0]) begin
            perfCycleCounterTx <= perfCycleCounterTx + 1;
            if (perfCycleCounterTx == maxPerfCycleNumReg) begin
                perfCycleCountFullTx[0] <= True;
            end            
        end
    endrule

    rule recvPacket;
        let axiFrame = udpAxiStreamRxInBuf.first;
        udpAxiStreamRxInBuf.deq;
        totalBeatCounterRx[0] <= totalBeatCounterRx[0] + 1;
        if (!perfCycleCountFullRx) begin
            perfBeatCounterRx[0] <= perfBeatCounterRx[0] + 1;
        end

        let isRecvBeatError = False;
        let headMismatch = truncateLSB(axiFrame.tData) != recvPktBeatCounter;
        let tailMismatch = truncate(axiFrame.tData) != recvPktBeatCounter;
        if (headMismatch || tailMismatch) begin
            isRecvBeatError = True;
        end

        if (axiFrame.tLast) begin
            recvPktNumCounter[0] <= recvPktNumCounter[0] + 1;
            if (isPktHasErrorReg || isRecvBeatError) begin
                errPktNumCounter[0] <= errPktNumCounter[0] + 1;
            end
            isPktHasErrorReg <= False;
        end
        else begin
            if (!isPktHasErrorReg) isPktHasErrorReg <= isRecvBeatError;
        end
        
        if (recvPktBeatCounter == pktSizeReg - 1) begin
            recvPktBeatCounter <= 0;
        end
        else begin
            recvPktBeatCounter <= recvPktBeatCounter + 1;
        end
        isRecvFirstPktReg[0] <= True;
    endrule

    rule countPerfCycleRx if (recvPktEnableReg);
        if (isRecvFirstPktReg[1] && !perfCycleCountFullRx) begin
            perfCycleCounterRx <= perfCycleCounterRx + 1;
            if (perfCycleCounterRx == maxPerfCycleNumReg) begin
                perfCycleCountFullRx <= True;
                recvPktEnableReg <= False;
            end
        end
    endrule

    let rawXdmaAxiStreamIn <- mkFifoInToRawAxiStreamSlave(convertFifoToFifoIn(xdmaAxiStreamInBuf));
    let rawXdmaAxiStreamOut <- mkFifoOutToRawAxiStreamMaster(convertFifoToFifoOut(xdmaAxiStreamOutBuf));
    
    let rawUdpAxiStreamRxIn <- mkFifoInToRawAxiStreamSlave(convertFifoToFifoIn(udpAxiStreamRxInBuf));
    let rawUdpAxiStreamTxOut <- mkFifoOutToRawAxiStreamMaster(convertFifoToFifoOut(udpAxiStreamTxOutBuf));

    interface xdmaAxiStreamIn  = rawXdmaAxiStreamIn;
    interface xdmaAxiStreamOut = rawXdmaAxiStreamOut;
    interface udpAxiStreamRxIn  = rawUdpAxiStreamRxIn;
    interface udpAxiStreamTxOut = rawUdpAxiStreamTxOut;

    interface PerfMonitorRegister perfMonReg;
        method pktSizeOut = pktSizeReg;
        method pktIntervalOut = pktIntervalReg;
        method perfCycleCounterTxOut = perfCycleCounterTx;
        method perfBeatCounterTxOut = perfBeatCounterTx;
        method perfCycleCounterRxOut = perfCycleCounterRx;
        method perfBeatCounterRxOut = perfBeatCounterRx[0];
        method totalBeatCounterTxOut = totalBeatCounterTx;
        method totalBeatCounterRxOut = totalBeatCounterRx[0];
        method perfCycleCountFullTxOut = perfCycleCountFullTx[0];
        method perfCycleCountFullRxOut = perfCycleCountFullRx;
        method sendPktEnableOut = sendPktEnableReg;
        method recvPktEnableOut = recvPktEnableReg;
        method isRecvFirstPktOut = isRecvFirstPktReg[0];
        method sendPktNumCounterOut = sendPktNumCounter;
        method recvPktNumCounterOut = recvPktNumCounter[0];
        method errPktNumCounterOut = errPktNumCounter[0];
    endinterface
endmodule