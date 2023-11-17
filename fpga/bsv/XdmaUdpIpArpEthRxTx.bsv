import FIFOF :: *;
import Clocks :: *;
import GetPut :: *;
import BRAMFIFO :: *;
import Connectable :: *;

import Ports :: *;
import BusConversion :: *;
import StreamHandler :: *;
import UdpIpArpEthRxTx :: *;
import XilinxCmacController :: *;
import XilinxAxiStreamAsyncFifo :: *;

import SemiFifo :: *;
import AxiStreamTypes :: *;


typedef 32 ASYNC_FIFO_DEPTH;
typedef 4  ASYNC_CDC_STAGES;
typedef 48'h7486e21ace80 TEST_MAC_ADDR;
typedef 32'h7F000000 TEST_IP_ADDR;
typedef 32'h00000000 TEST_NET_MASK;
typedef 32'h00000000 TEST_GATE_WAY;
typedef 88 TEST_UDP_PORT;
typedef 2048 TEST_PAYLOAD_SIZE;


interface XdmaUdpIpArpEthRxTx;
    // Interface with CMAC IP
    (* prefix = "cmac_tx_axis" *)
    interface RawAxiStreamMaster#(AXIS256_TKEEP_WIDTH, AXIS_TUSER_WIDTH) cmacAxiStreamTxOut;
    (* prefix = "cmac_rx_axis" *)
    interface RawAxiStreamSlave#(AXIS256_TKEEP_WIDTH, AXIS_TUSER_WIDTH)  cmacAxiStreamRxIn;
    
    // Interface with XDMA
    (* prefix = "xdma_rx_axis" *)
    interface RawAxiStreamMaster#(AXIS512_TKEEP_WIDTH, AXIS_TUSER_WIDTH) xdmaAxiStreamRxOut;
    (* prefix = "xdma_tx_axis" *)
    interface RawAxiStreamSlave#(AXIS512_TKEEP_WIDTH, AXIS_TUSER_WIDTH)  xdmaAxiStreamTxIn;
endinterface

(* synthesize, default_clock_osc = "udp_clk", default_reset = "udp_reset" *)
module mkXdmaUdpIpArpEthRxTx(XdmaUdpIpArpEthRxTx);
    Reg#(Bool) isUdpConfig <- mkReg(False);
    FIFOF#(AxiStream512) rawXdmaAxiStreamInBuf <- mkFIFOF;

    let udpIpArpEthRxTx <- mkGenericUdpIpArpEthRxTx(`IS_SUPPORT_RDMA);

    let xdmaAxiStreamOut <- mkDataStreamToAxiStream512(udpIpArpEthRxTx.dataStreamRxOut);
    let rawXdmaAxiStreamOut <- mkPipeOutToRawAxiStreamMaster(xdmaAxiStreamOut);

    let rawXdmaAxiStreamIn <- mkPipeInToRawAxiStreamSlave(convertFifoToPipeIn(rawXdmaAxiStreamInBuf));
    let dataStreamTxIn <- mkAxiStream512ToDataStream(convertFifoToPipeOut(rawXdmaAxiStreamInBuf));

    let rawCmacAxiStreamOut <- mkPipeOutToRawAxiStreamMaster(udpIpArpEthRxTx.axiStreamTxOut);
    let rawCmacAxiStreamIn <- mkPutToRawAxiStreamSlave(udpIpArpEthRxTx.axiStreamRxIn, CF);

    rule udpConfig if (!isUdpConfig);
        udpIpArpEthRxTx.udpConfig.put(
            UdpConfig {
                macAddr: fromInteger(valueOf(TEST_MAC_ADDR)),
                ipAddr: fromInteger(valueOf(TEST_IP_ADDR)),
                netMask: fromInteger(valueOf(TEST_NET_MASK)),
                gateWay: fromInteger(valueOf(TEST_GATE_WAY))
            }
        );
        isUdpConfig <= True;
    endrule

    rule sendUdpIpMetaDataAndDataStream;
        let dataStream = dataStreamTxIn.first;
        dataStreamTxIn.deq;
        if (dataStream.isFirst) begin
            udpIpArpEthRxTx.udpIpMetaDataTxIn.put(
                UdpIpMetaData {
                    dataLen: fromInteger(valueOf(TEST_PAYLOAD_SIZE)),
                    ipAddr: fromInteger(valueOf(TEST_IP_ADDR)),
                    ipDscp: 0,
                    ipEcn:  0,
                    dstPort: fromInteger(valueOf(TEST_UDP_PORT)),
                    srcPort: fromInteger(valueOf(TEST_UDP_PORT))
                }
            );            
        end
        udpIpArpEthRxTx.dataStreamTxIn.put(dataStream);
    endrule

    rule recvUdpIpMetaData;
        let udpIpMetaData = udpIpArpEthRxTx.udpIpMetaDataRxOut.first;
        udpIpArpEthRxTx.udpIpMetaDataRxOut.deq;
    endrule
    
    interface cmacAxiStreamRxIn  = rawCmacAxiStreamIn;
    interface cmacAxiStreamTxOut = rawCmacAxiStreamOut;
    interface xdmaAxiStreamTxIn  = rawXdmaAxiStreamIn;
    interface xdmaAxiStreamRxOut = rawXdmaAxiStreamOut;
endmodule

interface UdpIpArpEthRxTxForXdma;
    interface AxiStream512PipeOut xdmaAxiStreamRxOut;
    interface AxiStream512PipeIn xdmaAxiStreamTxIn;
    interface Put#(AxiStream256)  cmacAxiStreamRxIn;
    interface AxiStream256PipeOut cmacAxiStreamTxOut;
endinterface

module mkUdpIpArpEthRxTxForXdma(UdpIpArpEthRxTxForXdma);
    Reg#(Bool) isUdpConfig <- mkReg(False);

    FIFOF#(AxiStream512) xdmaAxiStreamTxInBuf <- mkFIFOF;
    let udpIpArpEthRxTx <- mkGenericUdpIpArpEthRxTx(`IS_SUPPORT_RDMA);

    let xdmaAxiStreamOut <- mkDataStreamToAxiStream512(udpIpArpEthRxTx.dataStreamRxOut);
    let dataStreamTxIn <- mkAxiStream512ToDataStream(convertFifoToPipeOut(xdmaAxiStreamTxInBuf));

    rule udpConfig if (!isUdpConfig);
        udpIpArpEthRxTx.udpConfig.put(
            UdpConfig {
                macAddr: fromInteger(valueOf(TEST_MAC_ADDR)),
                ipAddr: fromInteger(valueOf(TEST_IP_ADDR)),
                netMask: fromInteger(valueOf(TEST_NET_MASK)),
                gateWay: fromInteger(valueOf(TEST_GATE_WAY))
            }
        );
        isUdpConfig <= True;
    endrule

    rule sendUdpIpMetaDataAndDataStream;
        let dataStream = dataStreamTxIn.first;
        dataStreamTxIn.deq;
        if (dataStream.isFirst) begin
            udpIpArpEthRxTx.udpIpMetaDataTxIn.put(
                UdpIpMetaData {
                    dataLen: fromInteger(valueOf(TEST_PAYLOAD_SIZE)),
                    ipAddr: fromInteger(valueOf(TEST_IP_ADDR)),
                    ipDscp: 0,
                    ipEcn:  0,
                    dstPort: fromInteger(valueOf(TEST_UDP_PORT)),
                    srcPort: fromInteger(valueOf(TEST_UDP_PORT))
                }
            );            
        end
        udpIpArpEthRxTx.dataStreamTxIn.put(dataStream);
    endrule

    rule recvUdpIpMetaData;
        let udpIpMetaData = udpIpArpEthRxTx.udpIpMetaDataRxOut.first;
        udpIpArpEthRxTx.udpIpMetaDataRxOut.deq;
    endrule

    interface xdmaAxiStreamTxIn  = convertFifoToPipeIn(xdmaAxiStreamTxInBuf);
    interface xdmaAxiStreamRxOut = xdmaAxiStreamOut;
    interface cmacAxiStreamRxIn  = udpIpArpEthRxTx.axiStreamRxIn;
    interface cmacAxiStreamTxOut = udpIpArpEthRxTx.axiStreamTxOut;
endmodule


interface XdmaUdpIpArpEthCmacRxTx;
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

// (* synthesize, no_default_clock, no_default_reset *)
(* synthesize, default_clock_osc = "udp_clk", default_reset = "udp_reset" *)
module mkXdmaUdpIpArpEthCmacRxTx(
    // (* osc   = "udp_clk"       *) Clock udpClk,
    (* osc   = "cmac_rxtx_clk" *) Clock cmacRxTxClk,
    (* reset = "cmac_rx_reset" *) Reset cmacRxReset,
    (* reset = "cmac_tx_reset" *) Reset cmacTxReset,
    XdmaUdpIpArpEthCmacRxTx ifc
);
    let isEnableFlowControl = False;
    let isCmacTxWaitRxAligned = True;
    let asyncFifoDepth = valueOf(ASYNC_FIFO_DEPTH);
    let asyncCdcStages = valueOf(ASYNC_CDC_STAGES);

    let udpClk <- exposeCurrentClock();
    let udpReset <- exposeCurrentReset();

    SyncFIFOIfc#(AxiStream256) txAxiStreamSyncBuf <- mkXilinxAxiStreamAsyncFifo(
        asyncFifoDepth,
        asyncCdcStages,
        udpClk,
        udpReset,
        cmacRxTxClk,
        cmacTxReset
    );

    SyncFIFOIfc#(AxiStream256) rxAxiStreamSyncBuf <- mkXilinxAxiStreamAsyncFifo(
        asyncFifoDepth,
        asyncCdcStages,
        cmacRxTxClk,
        cmacRxReset,
        udpClk,
        udpReset
    );

    PipeOut#(FlowControlReqVec) txFlowCtrlReqVec <- mkDummyPipeOut;
    PipeIn#(FlowControlReqVec) rxFlowCtrlReqVec <- mkDummyPipeIn;
    
    let xilinxCmacCtrl <- mkXilinxCmacController(
        isEnableFlowControl,
        isCmacTxWaitRxAligned,
        convertSyncFifoToPipeOut(txAxiStreamSyncBuf),
        convertSyncFifoToPipeIn (rxAxiStreamSyncBuf),
        txFlowCtrlReqVec,
        rxFlowCtrlReqVec,
        cmacRxReset,
        cmacTxReset,
        clocked_by cmacRxTxClk
    );

    let udpIpArpEthRxTxForXdma <- mkUdpIpArpEthRxTxForXdma(clocked_by udpClk, reset_by udpReset);
    mkConnection(convertSyncFifoToPipeIn(txAxiStreamSyncBuf), udpIpArpEthRxTxForXdma.cmacAxiStreamTxOut);
    mkConnection(toGet(convertSyncFifoToPipeOut(rxAxiStreamSyncBuf)), udpIpArpEthRxTxForXdma.cmacAxiStreamRxIn);
    
    let rawXdmaAxiStreamOut <- mkPipeOutToRawAxiStreamMaster(udpIpArpEthRxTxForXdma.xdmaAxiStreamRxOut, clocked_by udpClk, reset_by udpReset);
    let rawXdmaAxiStreamIn <- mkPipeInToRawAxiStreamSlave(udpIpArpEthRxTxForXdma.xdmaAxiStreamTxIn, clocked_by udpClk, reset_by udpReset);

    interface cmacController = xilinxCmacCtrl;
    interface xdmaAxiStreamTxIn  = rawXdmaAxiStreamIn;
    interface xdmaAxiStreamRxOut = rawXdmaAxiStreamOut;
    //interface udpResetOut = udpReset;
endmodule

