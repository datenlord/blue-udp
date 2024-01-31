import FIFOF :: *;

import Ports :: *;
import EthUtils :: *;

import SemiFifo :: *;
import AxiStreamTypes :: *;

typedef 32 PERF_CYCLE_COUNT_WIDTH;
typedef 32 PERF_BEAT_COUNT_WIDTH;
typedef 32 PKT_NUM_COUNT_WIDTH;
typedef 32 PKT_SIZE_COUNT_WIDTH;
typedef 250000000 XDMA_AXIS_FREQ;

interface PerfMonitorRegister;
    method Bit#(PKT_SIZE_COUNT_WIDTH) pktSizeOut;
    method Bit#(PKT_NUM_COUNT_WIDTH) pktNumOut;  
    // Tx Status Registers
    method Bool sendPktEnableOut;
    method Bool isSendFirstFrameOut;
    method Bit#(PERF_CYCLE_COUNT_WIDTH) perfCycleCounterTxOut;
    method Bit#(PERF_BEAT_COUNT_WIDTH) totalBeatCounterTxOut;
    method Bit#(PKT_NUM_COUNT_WIDTH) totalPktCounterTxOut;

    // Rx Status Registers
    method Bool recvPktEnableOut;
    method Bool isRecvFirstFrameOut;
    method Bit#(PERF_CYCLE_COUNT_WIDTH) perfCycleCounterRxOut;
    method Bit#(PERF_BEAT_COUNT_WIDTH) totalBeatCounterRxOut;
    method Bit#(PKT_NUM_COUNT_WIDTH) totalPktCounterRxOut;
    method Bit#(PKT_NUM_COUNT_WIDTH) errBeatCounterRxOut;
endinterface

interface XdmaUdpPerfMonitorTx;
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
module mkXdmaUdpPerfMonitorTx(XdmaUdpPerfMonitorTx);

    FIFOF#(AxiStream512) xdmaAxiStreamInBuf <- mkFIFOF;
    FIFOF#(AxiStream512) xdmaAxiStreamOutBuf <- mkFIFOF;
    FIFOF#(AxiStream512) udpAxiStreamRxInBuf <- mkFIFOF;
    FIFOF#(AxiStream512) udpAxiStreamTxOutBuf <- mkFIFOF;
    
    Reg#(Bit#(PKT_SIZE_COUNT_WIDTH)) pktSizeReg <- mkReg(0);
    Reg#(Bit#(PKT_NUM_COUNT_WIDTH))  pktNumReg <- mkReg(0);

    // Tx Status Registers
    Reg#(Bool) sendPktEnableReg <- mkReg(False);
    Reg#(Bool) isSendFirstFrame <- mkReg(False);
    Reg#(Bit#(PERF_CYCLE_COUNT_WIDTH)) perfCycleCounterTx <- mkReg(0);
    Reg#(Bit#(PERF_BEAT_COUNT_WIDTH))  totalBeatCounterTx <- mkReg(0);
    Reg#(Bit#(PKT_NUM_COUNT_WIDTH))    totalPktCounterTx <- mkReg(0);

    // Rx Status Registers
    Reg#(Bool) recvPktEnableReg <- mkReg(False);
    Reg#(Bool) isRecvFirstFrame <- mkReg(False);
    Reg#(Bit#(PERF_CYCLE_COUNT_WIDTH)) perfCycleCounterRx <- mkReg(0);
    Reg#(Bit#(PERF_BEAT_COUNT_WIDTH))  totalBeatCounterRx <- mkReg(0);
    Reg#(Bit#(PKT_NUM_COUNT_WIDTH))    totalPktCounterRx <- mkReg(0);
    Reg#(Bit#(PERF_BEAT_COUNT_WIDTH))  beatIdxCounterRx <- mkReg(0);
    Reg#(Bit#(PKT_NUM_COUNT_WIDTH))    errBeatCounterRx <- mkReg(0);

    rule monConfig if(!sendPktEnableReg && !recvPktEnableReg);
        let axiFrame = xdmaAxiStreamInBuf.first;
        xdmaAxiStreamInBuf.deq;
        let configData = axiFrame.tData;
        let pktSize = truncate(axiFrame.tData);
        let pktNum = truncate(axiFrame.tData >> valueOf(PKT_SIZE_COUNT_WIDTH));
        pktSizeReg <= pktSize;
        pktNumReg <= pktNum;

        sendPktEnableReg <= True;
        isSendFirstFrame <= False;
        perfCycleCounterTx <= 0;
        totalBeatCounterTx <= 0;
        totalPktCounterTx <= 0;

        recvPktEnableReg <= True;
        isRecvFirstFrame <= False;
        perfCycleCounterRx <= 0;
        totalBeatCounterRx <= 0;
        totalPktCounterRx <= 0;
        beatIdxCounterRx <= 0;
        errBeatCounterRx <= 0;
    endrule

    rule sendPacket if (sendPktEnableReg);
        let axiFrame = xdmaAxiStreamInBuf.first;
        xdmaAxiStreamInBuf.deq;
        if (!isSendFirstFrame) begin
            isSendFirstFrame <= True;
        end
        
        totalBeatCounterTx <= totalBeatCounterTx + 1;
        if (axiFrame.tLast) begin
            totalPktCounterTx <= totalPktCounterTx + 1;
            if (totalPktCounterTx == pktNumReg - 1) begin
                sendPktEnableReg <= False;
            end
        end
        udpAxiStreamTxOutBuf.enq(axiFrame);
    endrule

    rule countPerfCycleTx if (sendPktEnableReg && isSendFirstFrame);
        perfCycleCounterTx <= perfCycleCounterTx + 1;
    endrule

    rule recvPacket if (recvPktEnableReg);
        let axiFrame = udpAxiStreamRxInBuf.first;
        udpAxiStreamRxInBuf.deq;

        if (!isRecvFirstFrame) begin
            isRecvFirstFrame <= True;
        end

        totalBeatCounterRx <= totalBeatCounterRx + 1;
        if (axiFrame.tLast) begin
            beatIdxCounterRx <= 0;
            totalPktCounterRx <= totalPktCounterRx + 1;
            if (totalPktCounterRx == pktNumReg - 1) begin
                recvPktEnableReg <= False;
            end
        end
        else begin
            beatIdxCounterRx <= beatIdxCounterRx + 1;
        end

        if (truncate(axiFrame.tData) != beatIdxCounterRx) begin
            errBeatCounterRx <= errBeatCounterRx + 1;
        end
    endrule

    rule countPerfCycleRx if(isRecvFirstFrame && recvPktEnableReg);
        perfCycleCounterRx <= perfCycleCounterRx + 1;
    endrule

    let rawXdmaAxiStreamIn <- mkPipeInToRawAxiStreamSlave(convertFifoToPipeIn(xdmaAxiStreamInBuf));
    let rawXdmaAxiStreamOut <- mkPipeOutToRawAxiStreamMaster(convertFifoToPipeOut(xdmaAxiStreamOutBuf));
    
    let rawUdpAxiStreamRxIn <- mkPipeInToRawAxiStreamSlave(convertFifoToPipeIn(udpAxiStreamRxInBuf));
    let rawUdpAxiStreamTxOut <- mkPipeOutToRawAxiStreamMaster(convertFifoToPipeOut(udpAxiStreamTxOutBuf));

    interface xdmaAxiStreamIn  = rawXdmaAxiStreamIn;
    interface xdmaAxiStreamOut = rawXdmaAxiStreamOut;
    interface udpAxiStreamRxIn  = rawUdpAxiStreamRxIn;
    interface udpAxiStreamTxOut = rawUdpAxiStreamTxOut;
    interface PerfMonitorRegister perfMonReg;
        method pktSizeOut = pktSizeReg;
        method pktNumOut = pktNumReg;
        // Tx Status Registers
        method sendPktEnableOut = sendPktEnableReg;
        method isSendFirstFrameOut = isSendFirstFrame;
        method perfCycleCounterTxOut = perfCycleCounterTx;
        method totalBeatCounterTxOut = totalBeatCounterTx;
        method totalPktCounterTxOut = totalPktCounterTx;
        // Rx Status Registers
        method recvPktEnableOut = recvPktEnableReg;
        method isRecvFirstFrameOut = isRecvFirstFrame;
        method perfCycleCounterRxOut = perfCycleCounterRx;
        method totalBeatCounterRxOut = totalBeatCounterRx;
        method totalPktCounterRxOut = totalPktCounterRx;
        method errBeatCounterRxOut = errBeatCounterRx;
    endinterface
endmodule