typedef 32 PKT_COUNT_WIDTH;
typedef 32 BEAT_COUNT_WIDTH;
typedef 32 CYCLE_COUNT_WIDTH;
typedef 16 MON_COUNT_WIDTH;
typedef 600000000 IDLE_CYCLE_NUM;

interface CmacSendMonitor;
    (* always_ready, always_enabled *)
    method Bool isMonitorIdleOut;
    (* always_ready, always_enabled *)
    method Bit#(PKT_COUNT_WIDTH) pktCounterOut;
    (* always_ready, always_enabled *)
    method Bit#(MON_COUNT_WIDTH) maxPktSizeOut;
    (* always_ready, always_enabled *)
    method Bit#(BEAT_COUNT_WIDTH) totalBeatCounterOut;
    (* always_ready, always_enabled *)
    method Bit#(MON_COUNT_WIDTH) overflowCounterOut;
    (* always_ready, always_enabled *)
    method Bit#(MON_COUNT_WIDTH) underflowCounterOut;
endinterface

(* synthesize, default_clock_osc = "clk", default_reset = "reset" *)
module mkCmacSendMonitor#(
    Bool valid,
    Bool ready,
    Bool last,
    Bool txOverflow,
    Bool txUnderflow
)(CmacSendMonitor);
    Reg#(Bit#(PKT_COUNT_WIDTH ))  pktCounter <- mkReg(0);
    Reg#(Bit#(MON_COUNT_WIDTH ))  pktSizeCounter <- mkReg(0);
    Reg#(Bit#(MON_COUNT_WIDTH ))  maxPktSizeReg <- mkReg(0);
    Reg#(Bit#(BEAT_COUNT_WIDTH))  totalBeatCounter <- mkReg(0);
    Reg#(Bit#(MON_COUNT_WIDTH))   overflowCounter <- mkReg(0);
    Reg#(Bit#(MON_COUNT_WIDTH))   underflowCounter <- mkReg(0);
    Reg#(Bit#(CYCLE_COUNT_WIDTH)) idleCycleCounter <- mkReg(0);
    Reg#(Bool) isMonitorIdle <- mkReg(False);

    rule countPkt;
        if (valid && ready) begin
            if (isMonitorIdle) begin
                totalBeatCounter <= 1;
                pktCounter <= last ? 1 : 0;
                pktSizeCounter <= 1;
                maxPktSizeReg <= 0;
            end
            else begin
                totalBeatCounter <= totalBeatCounter + 1;
                if (last) begin
                    pktCounter <= pktCounter + 1;
                    pktSizeCounter <= 0;
                    if ((pktSizeCounter + 1) > maxPktSizeReg) begin
                        maxPktSizeReg <= pktSizeCounter + 1;
                    end
                end
                else begin
                    pktSizeCounter <= pktSizeCounter + 1;
                end
            end
            isMonitorIdle <= False;
            idleCycleCounter <= 0;
        end
        else begin
            if (idleCycleCounter < fromInteger(valueOf(IDLE_CYCLE_NUM))) begin
                idleCycleCounter <= idleCycleCounter + 1;
            end
            else begin
                isMonitorIdle <= True;
            end
        end
    endrule

    rule countStatus;
        if (txOverflow) begin
            overflowCounter <= overflowCounter + 1;
        end
        if (txUnderflow) begin
            underflowCounter <= underflowCounter + 1;
        end
    endrule

    method Bool isMonitorIdleOut = isMonitorIdle;
    method Bit#(PKT_COUNT_WIDTH) pktCounterOut = pktCounter;
    method Bit#(MON_COUNT_WIDTH) maxPktSizeOut = maxPktSizeReg;
    method Bit#(BEAT_COUNT_WIDTH) totalBeatCounterOut = totalBeatCounter;
    method Bit#(MON_COUNT_WIDTH) overflowCounterOut = overflowCounter;
    method Bit#(MON_COUNT_WIDTH) underflowCounterOut = underflowCounter;
endmodule