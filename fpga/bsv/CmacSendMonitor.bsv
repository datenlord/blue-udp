typedef 32 PKT_COUNT_WIDTH;
typedef 32 BEAT_COUNT_WIDTH;
typedef 32 CYCLE_COUNT_WIDTH;
typedef 32 PKT_SIZE_WIDTH;
typedef 600000000 IDLE_CYCLE_NUM;

interface CmacSendMonitor;
    (* always_ready, always_enabled *)
    method Bool isMonitorIdleOut;
    (* always_ready, always_enabled *)
    method Bit#(PKT_COUNT_WIDTH) pktCounterOut;
    (* always_ready, always_enabled *)
    method Bit#(PKT_SIZE_WIDTH) pktSizeCounterOut;
    (* always_ready, always_enabled *)
    method Bit#(BEAT_COUNT_WIDTH) totalBeatCounterOut;
endinterface

(* synthesize, default_clock_osc = "clk", default_reset = "reset" *)
module mkCmacSendMonitor#(
    Bool valid,
    Bool ready,
    Bool last
)(CmacSendMonitor);
    Reg#(Bit#(PKT_COUNT_WIDTH ))  pktCounter <- mkReg(0);
    Reg#(Bit#(PKT_SIZE_WIDTH  ))  pktSizeCounter <- mkReg(0);
    Reg#(Bit#(BEAT_COUNT_WIDTH))  totalBeatCounter <- mkReg(0);
    Reg#(Bit#(CYCLE_COUNT_WIDTH)) idleCycleCounter <- mkReg(0);
    Reg#(Bool) isMonitorIdle <- mkReg(False);

    rule countPkt;
        if (valid && ready) begin
            if (isMonitorIdle) begin
                totalBeatCounter <= 1;
                pktCounter <= last ? 1 : 0;
            end
            else begin
                totalBeatCounter <= totalBeatCounter + 1;
                if (last) pktCounter <= pktCounter + 1;
            end

            isMonitorIdle <= False;
            idleCycleCounter <= 0;

            if (last) begin
                pktSizeCounter <= 0;
            end
            else begin
                pktSizeCounter <= pktSizeCounter + 1;
            end
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

    method Bool isMonitorIdleOut = isMonitorIdle;
    method Bit#(PKT_COUNT_WIDTH) pktCounterOut = pktCounter;
    method Bit#(PKT_SIZE_WIDTH) pktSizeCounterOut = pktSizeCounter;
    method Bit#(BEAT_COUNT_WIDTH) totalBeatCounterOut = totalBeatCounter;
endmodule