import FIFOF :: *;

import Ports :: *;
import EthUtils :: *;

import SemiFifo :: *;
import Axi4LiteTypes :: *;
import AxiStreamTypes :: *;

typedef 32 AXIL_ADDR_WIDTH;
typedef  4 AXIL_STRB_WIDTH;

typedef 32 PERF_CYCLE_COUNT_WIDTH;
typedef 32 PERF_BEAT_COUNT_WIDTH;
typedef 32 PKT_NUM_COUNT_WIDTH;
typedef 32 PKT_BEAT_COUNT_WIDTH;
typedef 250000000 XDMA_AXIS_FREQ;

typedef Bit#(64) XdmaDescBypAddr;
typedef Bit#(28) XdmaDescBypLength;
typedef struct {
    Bool eop;
    Bit#(2) _rsv;
    Bool completed;
    Bool stop;
} XdmaDescBypCtl deriving(Bits, FShow);

typedef struct {
    XdmaDescBypAddr srcAddr;
    XdmaDescBypAddr dstAddr;
    XdmaDescBypLength len;
    XdmaDescBypCtl ctl;
} XdmaDescriptorBypass deriving(Bits, FShow);


(* always_enabled, always_ready *)
interface XdmaPerfMonitorRegister;
    method Bool monitorModeOut;
    method Bool isLoopbackOut;
    method Bit#(PKT_BEAT_COUNT_WIDTH) pktBeatNumOut;
    method Bit#(PKT_NUM_COUNT_WIDTH) pktNumOut;
    method XdmaDescBypAddr xdmaDescBypAddrOut;
    
    // Descriptor Bypass
    method Bool sendDescEnableOut;
    method Bit#(PKT_NUM_COUNT_WIDTH) totalDescCounterOut;
    // Tx Status Registers
    method Bool sendPktEnableOut;
    method Bool isSendFirstFrameOut;
    method Bit#(PERF_CYCLE_COUNT_WIDTH) perfCycleCounterTxOut;
    method Bit#(PERF_BEAT_COUNT_WIDTH) totalBeatCounterTxOut;
    method Bit#(PERF_BEAT_COUNT_WIDTH) errBeatCounterTxOut;
    method Bit#(PKT_NUM_COUNT_WIDTH) totalPktCounterTxOut;

    // Rx Status Registers
    method Bool recvPktEnableOut;
    method Bool isRecvFirstFrameOut;
    method Bit#(PERF_CYCLE_COUNT_WIDTH) perfCycleCounterRxOut;
    method Bit#(PERF_BEAT_COUNT_WIDTH) totalBeatCounterRxOut;
    method Bit#(PERF_BEAT_COUNT_WIDTH) errBeatCounterRxOut;
    method Bit#(PKT_NUM_COUNT_WIDTH) totalPktCounterRxOut;
endinterface

(* always_ready, always_enabled *)
interface RawXdmaDescriptorBypass;
    (* prefix = "" *)         method Action ready((* port = "ready" *) Bool rdy);
    (* result = "load" *)     method Bool load;
    (* result = "src_addr" *) method XdmaDescBypAddr srcAddr;
    (* result = "dst_addr" *) method XdmaDescBypAddr dstAddr;
    (* result = "len" *)      method XdmaDescBypLength len;
    (* result = "ctl" *)      method XdmaDescBypCtl ctl;
endinterface

module mkPipeOutToRawXdmaDescriptorBypass#(
    PipeOut#(XdmaDescriptorBypass) dmaReqPipe
)(RawXdmaDescriptorBypass);
    RWire#(XdmaDescBypAddr) srcAddrW <- mkRWire;
    RWire#(XdmaDescBypAddr) dstAddrW <- mkRWire;
    RWire#(XdmaDescBypLength) lenW <- mkRWire;
    RWire#(XdmaDescBypCtl) ctlW <- mkRWire;
    Wire#(Bool) readyW <- mkBypassWire;

    rule passReq;
        let dmaReq = dmaReqPipe.first;
        srcAddrW.wset(dmaReq.srcAddr);
        dstAddrW.wset(dmaReq.dstAddr);
        lenW.wset(dmaReq.len);
        ctlW.wset(dmaReq.ctl);
    endrule

    rule passReady if (readyW);
        dmaReqPipe.deq;
    endrule

    method Bool load = dmaReqPipe.notEmpty && readyW;
    method XdmaDescBypAddr srcAddr = fromMaybe(?, srcAddrW.wget);
    method XdmaDescBypAddr dstAddr = fromMaybe(?, dstAddrW.wget);
    method XdmaDescBypLength len = fromMaybe(?, lenW.wget);
    method XdmaDescBypCtl ctl = fromMaybe(?, ctlW.wget);
    method Action ready(Bool rdy);
        readyW <= rdy;
    endmethod
endmodule

interface XdmaPerfMonitor;
    (* prefix = "xdma_axil" *)
    interface RawAxi4LiteSlave#(AXIL_ADDR_WIDTH, AXIL_STRB_WIDTH) xdmaAxiLiteSlave;
    
    (* prefix = "xdma_tx_axis" *)
    interface RawAxiStreamSlave#(AXIS512_TKEEP_WIDTH, AXIS_TUSER_WIDTH) xdmaAxiStreamIn;
    (* prefix = "xdma_rx_axis" *)
    interface RawAxiStreamMaster#(AXIS512_TKEEP_WIDTH, AXIS_TUSER_WIDTH) xdmaAxiStreamOut;
    
    (* prefix = "xdma_h2c_desc_byp" *)
    interface RawXdmaDescriptorBypass xdmaH2cDescByp;
    (* prefix = "xdma_c2h_desc_byp" *)
    interface RawXdmaDescriptorBypass xdmaC2hDescByp;

    (* prefix = "udp_rx_axis" *)
    interface RawAxiStreamSlave#(AXIS512_TKEEP_WIDTH, AXIS_TUSER_WIDTH) udpAxiStreamRxIn;
    (* prefix = "udp_tx_axis" *)
    interface RawAxiStreamMaster#(AXIS512_TKEEP_WIDTH, AXIS_TUSER_WIDTH) udpAxiStreamTxOut;
    
    (* prefix = "" *)
    interface XdmaPerfMonitorRegister perfMonReg;
endinterface

(* synthesize, default_clock_osc = "clk", default_reset = "reset" *)
module mkXdmaPerfMonitor(XdmaPerfMonitor);

    FIFOF#(Axi4LiteWrAddr#(AXIL_ADDR_WIDTH)) axilWrAddrBuf <- mkFIFOF;
    FIFOF#(Axi4LiteWrData#(AXIL_STRB_WIDTH)) axilWrDataBuf <- mkFIFOF;
    FIFOF#(Axi4LiteWrResp) axilWrRespBuf <- mkFIFOF;
    FIFOF#(Tuple2#(Axi4LiteWrAddr#(AXIL_ADDR_WIDTH), Axi4LiteWrData#(AXIL_STRB_WIDTH))) axilWrReqBuf <- mkFIFOF;
    
    FIFOF#(Axi4LiteRdAddr#(AXIL_ADDR_WIDTH)) axilRdAddrBuf <- mkFIFOF;
    FIFOF#(Axi4LiteRdData#(AXIL_STRB_WIDTH)) axilRdDataBuf <- mkFIFOF;

    FIFOF#(XdmaDescriptorBypass) xdmaH2cDescBypBuf <- mkFIFOF;
    FIFOF#(XdmaDescriptorBypass) xdmaC2hDescBypBuf <- mkFIFOF;

    FIFOF#(AxiStream512) xdmaAxiStreamInBuf <- mkFIFOF;
    FIFOF#(AxiStream512) xdmaAxiStreamOutBuf <- mkFIFOF;
    FIFOF#(AxiStream512) udpAxiStreamRxInBuf <- mkFIFOF;
    FIFOF#(AxiStream512) udpAxiStreamTxOutBuf <- mkFIFOF;
    
    // Address Allocation
    // 0x0000_0000: xdmaDescBypAddr
    // 0x0000_0008: pktBeatNumReg
    // 0x0000_000C: pktNumReg
    // 0x0000_0010: modeSelectReg
    // 0x0000_0014: perfCycleCounterTx
    // 0x0000_0018: perfCycleCounterRx
    Reg#(XdmaDescBypAddr) xdmaDescBypAddrReg <- mkReg(0);
    Reg#(Bit#(PKT_BEAT_COUNT_WIDTH)) pktBeatNumReg <- mkReg(0);
    Reg#(Bit#(PKT_NUM_COUNT_WIDTH))  pktNumReg <- mkReg(0);
    Reg#(Bool) modeSelectReg <- mkReg(False); // False: H2C, True: C2H;
    Reg#(Bool) isLoopbackReg <- mkReg(False);


    // Descriptor Bypass Channel
    Reg#(Bool) sendDescEnableReg <- mkReg(False);
    Reg#(Bit#(PKT_NUM_COUNT_WIDTH)) totalDescCounter <- mkReg(0);

    // Tx Status Registers
    Reg#(Bool) sendPktEnableReg <- mkReg(False);
    Reg#(Bool) isSendFirstFrame <- mkReg(False);
    Reg#(Bit#(PERF_CYCLE_COUNT_WIDTH)) perfCycleCounterTx <- mkReg(0);
    Reg#(Bit#(PERF_BEAT_COUNT_WIDTH))  totalBeatCounterTx <- mkReg(0);
    Reg#(Bit#(PKT_NUM_COUNT_WIDTH))    totalPktCounterTx <- mkReg(0);
    Reg#(Bit#(PKT_BEAT_COUNT_WIDTH))   beatIdxCounterTx <- mkReg(0);
    Reg#(Bit#(PERF_BEAT_COUNT_WIDTH))  errBeatCounterTx <- mkReg(0);

    // Rx Status Registers
    Reg#(Bool) recvPktEnableReg <- mkReg(False);
    Reg#(Bool) isRecvFirstFrame <- mkReg(False);
    Reg#(Bit#(PERF_CYCLE_COUNT_WIDTH)) perfCycleCounterRx <- mkReg(0);
    Reg#(Bit#(PERF_BEAT_COUNT_WIDTH))  totalBeatCounterRx <- mkReg(0);
    Reg#(Bit#(PKT_NUM_COUNT_WIDTH))    totalPktCounterRx <- mkReg(0);
    Reg#(Bit#(PKT_BEAT_COUNT_WIDTH))   beatIdxCounterRx <- mkReg(0);
    Reg#(Bit#(PERF_BEAT_COUNT_WIDTH))  errBeatCounterRx <- mkReg(0);

    rule axiLiteRdChannel;
        let axilRdAddr = axilRdAddrBuf.first;
        axilRdAddrBuf.deq;
        Axi4LiteRdData#(AXIL_STRB_WIDTH) axilRdData = Axi4LiteRdData {
            rResp: 0,
            rData: 0
        };
        if (axilRdAddr.arAddr == 20) begin
            axilRdData.rData = perfCycleCounterTx;
        end
        if (axilRdAddr.arAddr == 24) begin
            axilRdData.rData = perfCycleCounterRx;
        end
        axilRdDataBuf.enq(axilRdData);
    endrule

    rule axiLiteWrChannel;
        let axilWrAddr = axilWrAddrBuf.first;
        axilWrAddrBuf.deq;
        let axilWrData = axilWrDataBuf.first;
        axilWrDataBuf.deq;
        axilWrRespBuf.enq(0);
        axilWrReqBuf.enq(tuple2(axilWrAddr, axilWrData));
    endrule

    rule monConfig if(!sendPktEnableReg && !recvPktEnableReg && !sendDescEnableReg);
        let axilWrReq = axilWrReqBuf.first;
        axilWrReqBuf.deq;
        let axilWrAddr = tpl_1(axilWrReq);
        let axilWrData = tpl_2(axilWrReq);

        let maskedWrData = bitMask(axilWrData.wData, axilWrData.wStrb);
        if (axilWrAddr.awAddr == 0) begin
            xdmaDescBypAddrReg <= zeroExtend(maskedWrData);
        end
        if (axilWrAddr.awAddr == 4) begin
            xdmaDescBypAddrReg <= (zeroExtend(maskedWrData) << 32)| zeroExtend(xdmaDescBypAddrReg[31:0]);
        end
        if (axilWrAddr.awAddr == 8) begin
            pktBeatNumReg <= axilWrData.wData;
        end
        if (axilWrAddr.awAddr == 12) begin
            pktNumReg <= axilWrData.wData;
        end
        if (axilWrAddr.awAddr == 16) begin
            Bool modeSelect = unpack(axilWrData.wData[0]);
            Bool isLoopback = unpack(axilWrData.wData[1]);
            modeSelectReg <= modeSelect;
            isLoopbackReg <= isLoopback;

            sendDescEnableReg <= True;
            totalDescCounter <= 0;

            if (!modeSelect || (modeSelect && isLoopback)) begin
                sendPktEnableReg <= True;
            end
            isSendFirstFrame <= False;
            perfCycleCounterTx <= 0;
            totalBeatCounterTx <= 0;
            totalPktCounterTx <= 0;
            beatIdxCounterTx <= 0;
            errBeatCounterTx <= 0;

            if (modeSelect ||(!modeSelect && isLoopback)) begin
                recvPktEnableReg <= True;
            end
            isRecvFirstFrame <= False;
            perfCycleCounterRx <= 0;
            totalBeatCounterRx <= 0;
            totalPktCounterRx <= 0;
            beatIdxCounterRx <= 0;
            errBeatCounterRx <= 0;
        end
    endrule

    rule sendDescriptor if (sendDescEnableReg);
        let descCtl = XdmaDescBypCtl {
            eop: True,
            _rsv: 0,
            completed: False,
            stop: False
        };
        XdmaDescBypLength descLen = truncate(pktBeatNumReg << 6);
        if (modeSelectReg) begin
            xdmaC2hDescBypBuf.enq(
                XdmaDescriptorBypass {
                    srcAddr: 0,
                    dstAddr: xdmaDescBypAddrReg,
                    len: descLen,
                    ctl: descCtl
                }
            );
        end
        else begin
            xdmaH2cDescBypBuf.enq(
                XdmaDescriptorBypass {
                    srcAddr: xdmaDescBypAddrReg,
                    dstAddr: 0,
                    len: descLen,
                    ctl: descCtl
                }
            );
        end
        totalDescCounter <= totalDescCounter + 1;
        if (totalDescCounter == pktNumReg - 1) begin
            sendDescEnableReg <= False;
        end
    endrule

    rule sendPacket if (sendPktEnableReg);
        let axiFrame = AxiStream512 {
            tData: {0, beatIdxCounterTx},
            tKeep: setAllBits,
            tLast: beatIdxCounterTx == pktBeatNumReg - 1,
            tUser: 0
        };

        if (!modeSelectReg) begin // H2C
            axiFrame = xdmaAxiStreamInBuf.first;
            xdmaAxiStreamInBuf.deq;
            if (truncate(axiFrame.tData) != beatIdxCounterTx) begin
                errBeatCounterTx <= errBeatCounterTx + 1;
            end
        end

        if (!isSendFirstFrame) begin
            isSendFirstFrame <= True;
        end
        
        totalBeatCounterTx <= totalBeatCounterTx + 1;
        if (axiFrame.tLast) begin
            beatIdxCounterTx <= 0;
            totalPktCounterTx <= totalPktCounterTx + 1;
            if (totalPktCounterTx == pktNumReg - 1) begin
                sendPktEnableReg <= False;
            end
        end
        else begin
            beatIdxCounterTx <= beatIdxCounterTx + 1;
        end
        
        udpAxiStreamTxOutBuf.enq(axiFrame);
    endrule

    rule countPerfCycleTx if (sendPktEnableReg && isSendFirstFrame);
        perfCycleCounterTx <= perfCycleCounterTx + 1;
    endrule

    rule recvPacket if (recvPktEnableReg);
        let axiFrame = udpAxiStreamRxInBuf.first;
        udpAxiStreamRxInBuf.deq;

        if (modeSelectReg) begin // C2H
            xdmaAxiStreamOutBuf.enq(axiFrame);
        end

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

    let rawXdmaAxiLiteSlave <- mkPipeToRawAxi4LiteSlave(
        convertFifoToPipeIn (axilWrAddrBuf),
        convertFifoToPipeIn (axilWrDataBuf),
        convertFifoToPipeOut(axilWrRespBuf),
        convertFifoToPipeIn (axilRdAddrBuf),
        convertFifoToPipeOut(axilRdDataBuf)
    );

    let rawXdmaAxiStreamIn <- mkPipeInToRawAxiStreamSlave(convertFifoToPipeIn(xdmaAxiStreamInBuf));
    let rawXdmaAxiStreamOut <- mkPipeOutToRawAxiStreamMaster(convertFifoToPipeOut(xdmaAxiStreamOutBuf));
    
    let rawXdmaH2cDescBpy <- mkPipeOutToRawXdmaDescriptorBypass(convertFifoToPipeOut(xdmaH2cDescBypBuf));
    let rawXdmaC2hDescByp <- mkPipeOutToRawXdmaDescriptorBypass(convertFifoToPipeOut(xdmaC2hDescBypBuf));

    let rawUdpAxiStreamRxIn <- mkPipeInToRawAxiStreamSlave(convertFifoToPipeIn(udpAxiStreamRxInBuf));
    let rawUdpAxiStreamTxOut <- mkPipeOutToRawAxiStreamMaster(convertFifoToPipeOut(udpAxiStreamTxOutBuf));

    
    interface xdmaAxiLiteSlave = rawXdmaAxiLiteSlave;
    
    interface xdmaAxiStreamIn  = rawXdmaAxiStreamIn;
    interface xdmaAxiStreamOut = rawXdmaAxiStreamOut;

    interface xdmaH2cDescByp = rawXdmaH2cDescBpy;
    interface xdmaC2hDescByp = rawXdmaC2hDescByp;
    
    interface udpAxiStreamRxIn  = rawUdpAxiStreamRxIn;
    interface udpAxiStreamTxOut = rawUdpAxiStreamTxOut;
    
    interface XdmaPerfMonitorRegister perfMonReg;
        method monitorModeOut = modeSelectReg;
        method isLoopbackOut = isLoopbackReg;
        method pktBeatNumOut = pktBeatNumReg;
        method pktNumOut = pktNumReg;
        method xdmaDescBypAddrOut = xdmaDescBypAddrReg;
        // Descriptor Bypass
        method sendDescEnableOut = sendDescEnableReg;
        method totalDescCounterOut = totalDescCounter;
        // Tx Status Registers
        method sendPktEnableOut = sendPktEnableReg;
        method isSendFirstFrameOut = isSendFirstFrame;
        method perfCycleCounterTxOut = perfCycleCounterTx;
        method totalBeatCounterTxOut = totalBeatCounterTx;
        method errBeatCounterTxOut = errBeatCounterTx;
        method totalPktCounterTxOut = totalPktCounterTx;
        
        // Rx Status Registers
        method recvPktEnableOut = recvPktEnableReg;
        method isRecvFirstFrameOut = isRecvFirstFrame;
        method perfCycleCounterRxOut = perfCycleCounterRx;
        method totalBeatCounterRxOut = totalBeatCounterRx;
        method errBeatCounterRxOut = errBeatCounterRx;
        method totalPktCounterRxOut = totalPktCounterRx;
    endinterface
endmodule