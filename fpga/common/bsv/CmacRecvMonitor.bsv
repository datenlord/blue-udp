
typedef 32 PKT_COUNT_WIDTH;
typedef 32 BEAT_COUNT_WIDTH;
typedef 32 CYCLE_COUNT_WIDTH;
typedef  3 RX_FCS_WIDTH;
typedef 32 MON_COUNT_WIDTH;
typedef 3000000000 IDLE_CYCLE_NUM;

interface CmacRecvMonitor;
    (* always_ready, always_enabled *)
    method Bool isMonitorIdleOut;
    (* always_ready, always_enabled *)
    method Bit#(PKT_COUNT_WIDTH) pktCounterOut;
    (* always_ready, always_enabled *)
    method Bit#(BEAT_COUNT_WIDTH) lostBeatCounterOut;
    (* always_ready, always_enabled *)
    method Bit#(BEAT_COUNT_WIDTH) totalBeatCounterOut;
    (* always_ready, always_enabled *)
    method Bit#(MON_COUNT_WIDTH) badFCSCounterOut;
    (* always_ready, always_enabled *)
    method Bit#(MON_COUNT_WIDTH) maxPktSizeOut;
endinterface

(* synthesize, default_clock_osc = "clk", default_reset = "reset" *)
module mkCmacRecvMonitor#(
    Bool valid,
    Bool ready,
    Bool last,
    Bool user,
    Bit#(RX_FCS_WIDTH) badFCS,
    Bit#(RX_FCS_WIDTH) stompedFCS
)(CmacRecvMonitor);
    Reg#(Bit#(PKT_COUNT_WIDTH )) pktCounter <- mkReg(0);
    Reg#(Bit#(BEAT_COUNT_WIDTH)) lostBeatCounter <- mkReg(0);
    Reg#(Bit#(BEAT_COUNT_WIDTH)) totalBeatCounter <- mkReg(0);
    Reg#(Bit#(CYCLE_COUNT_WIDTH)) idleCycleCounter <- mkReg(0);
    Reg#(Bit#(MON_COUNT_WIDTH)) badFCSCounter <- mkReg(0);
    Reg#(Bit#(MON_COUNT_WIDTH)) pktSizeCounter <- mkReg(0);
    Reg#(Bit#(MON_COUNT_WIDTH)) maxPktSizeReg <- mkReg(0);
    Reg#(Bool) isMonitorIdle <- mkReg(False);

    rule countPkt;
        if (valid) begin
            if (isMonitorIdle) begin
                pktCounter <= last ? 1 : 0;
                lostBeatCounter <= ready ? 0 : 1;
                totalBeatCounter <= 1;
                maxPktSizeReg <= last ? 1 : 0;
                pktSizeCounter <= last ? 0 : 1;
            end
            else begin
                totalBeatCounter <= totalBeatCounter + 1;
                if (!ready) lostBeatCounter <= lostBeatCounter + 1;
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
        if (user) begin
            badFCSCounter <= badFCSCounter + 1;
        end
    endrule

    method Bool isMonitorIdleOut = isMonitorIdle;
    method Bit#(PKT_COUNT_WIDTH ) pktCounterOut = pktCounter;
    method Bit#(BEAT_COUNT_WIDTH) lostBeatCounterOut = lostBeatCounter;
    method Bit#(BEAT_COUNT_WIDTH) totalBeatCounterOut = totalBeatCounter;
    method Bit#(MON_COUNT_WIDTH ) badFCSCounterOut = badFCSCounter;
    method Bit#(MON_COUNT_WIDTH ) maxPktSizeOut = maxPktSizeReg;
endmodule
