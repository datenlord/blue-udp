import FIFOF :: *;
import Clocks :: *;
import GetPut :: *;
import BRAMFIFO :: *;
import Connectable :: *;

import Ports :: *;
import EthUtils :: *;
import BusConversion :: *;
import StreamHandler :: *;
import EthernetTypes :: *;
import UdpIpEthBypassCmacRxTx :: *;
import XilinxCmacController :: *;
import XilinxAxiStreamAsyncFifo :: *;

import SemiFifo :: *;
import AxiStreamTypes :: *;


typedef 64 ASYNC_FIFO_DEPTH;
typedef 4  ASYNC_CDC_STAGES;

//typedef 48'h7486e21ace88 TARGET_MAC_ADDR;
//typedef 48'h7486e21ace80 SOURCE_MAC_ADDR;
//typedef 48'h7486e21ace80 TARGET_MAC_ADDR;
//typedef 48'h7486e21ace88 SOURCE_MAC_ADDR;
typedef 48'h7486e21ace80 TARGET_MAC_ADDR;
typedef 48'h7486e21ace80 SOURCE_MAC_ADDR;

//typedef 32'hC0A80102 TARGET_IP_ADDR;
//typedef 32'hC0A80103 SOURCE_IP_ADDR;
//typedef 32'hC0A80103 TARGET_IP_ADDR;
//typedef 32'hC0A80102 SOURCE_IP_ADDR;
typedef 32'hC0A80102 TARGET_IP_ADDR;
typedef 32'hC0A80102 SOURCE_IP_ADDR;

typedef 32'h00000000 TEST_NET_MASK;
typedef 32'h00000000 TEST_GATE_WAY;
typedef 88 TEST_UDP_PORT;
typedef 2048 TEST_PAYLOAD_SIZE;


interface UdpIpEthBypassRxTxForXdma;
    interface AxiStream512FifoIn  xdmaAxiStreamTxIn;
    interface AxiStream512FifoOut xdmaAxiStreamRxOut;
    interface AxiStream512FifoIn  cmacAxiStreamRxIn;
    interface AxiStream512FifoOut cmacAxiStreamTxOut;
endinterface

module mkUdpIpEthBypassRxTxForXdma(UdpIpEthBypassRxTxForXdma);
    Reg#(Bool) isUdpConfig <- mkReg(False);

    FIFOF#(AxiStreamLocal) xdmaAxiStreamInBuf <- mkFIFOF;
    let dataStreamTxIn <- mkAxiStreamToDataStream(convertFifoToFifoOut(xdmaAxiStreamInBuf));
    let udpIpEthBypassRxTx <- mkGenericUdpIpEthBypassRxTx(`IS_SUPPORT_RDMA);

    rule udpConfig if (!isUdpConfig);
        udpIpEthBypassRxTx.udpConfig.put(
            UdpConfig {
                macAddr: fromInteger(valueOf(SOURCE_MAC_ADDR)),
                ipAddr: fromInteger (valueOf(SOURCE_IP_ADDR)),
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
            udpIpEthBypassRxTx.udpIpMetaDataTxIn.put(
                UdpIpMetaData {
                    dataLen: fromInteger(valueOf(TEST_PAYLOAD_SIZE)),
                    ipAddr: fromInteger(valueOf(TARGET_IP_ADDR)),
                    ipDscp: 0,
                    ipEcn:  0,
                    dstPort: fromInteger(valueOf(TEST_UDP_PORT)),
                    srcPort: fromInteger(valueOf(TEST_UDP_PORT))
                }
            );

            let macMeta = MacMetaData {
                macAddr: fromInteger(valueOf(TARGET_MAC_ADDR)),
                ethType: fromInteger(valueOf(ETH_TYPE_IP))
            };

            udpIpEthBypassRxTx.macMetaDataTxIn.put(
                MacMetaDataWithBypassTag {
                    macMetaData: macMeta,
                    isBypass: False
                }
            );
        end
        udpIpEthBypassRxTx.dataStreamTxIn.put(dataStream);
    endrule

    rule recvUdpIpMetaData;
        let udpIpMetaData = udpIpEthBypassRxTx.udpIpMetaDataRxOut.first;
        udpIpEthBypassRxTx.udpIpMetaDataRxOut.deq;
        udpIpEthBypassRxTx.macMetaDataRxOut.deq;
    endrule

    rule recvRawPkt;
        udpIpEthBypassRxTx.rawPktStreamRxOut.deq;
    endrule

    let xdmaAxiStreamLocalTxIn = convertFifoToFifoIn(xdmaAxiStreamInBuf);
    let xdmaAxiStreamLocalRxOut = convertDataStreamToAxiStream(udpIpEthBypassRxTx.dataStreamRxOut);
    let xdmaAxiStream512TxIn <- mkAxiStream512FifoIn(xdmaAxiStreamLocalTxIn);
    let xdmaAxiStream512RxOut <- mkAxiStream512FifoOut(xdmaAxiStreamLocalRxOut);

    let cmacAxiStreamLocalTxOut = udpIpEthBypassRxTx.axiStreamTxOut;
    let cmacAxiStreamLocalRxIn <- mkPutToFifoIn(udpIpEthBypassRxTx.axiStreamRxIn);
    let cmacAxiStream512RxIn <- mkAxiStream512FifoIn(cmacAxiStreamLocalRxIn);
    let cmacAxiStream512TxOut <- mkAxiStream512FifoOut(cmacAxiStreamLocalTxOut);
    interface xdmaAxiStreamTxIn  = xdmaAxiStream512TxIn;
    interface xdmaAxiStreamRxOut = xdmaAxiStream512RxOut;
    interface cmacAxiStreamRxIn  = cmacAxiStream512RxIn;
    interface cmacAxiStreamTxOut = cmacAxiStream512TxOut;
endmodule


interface XdmaUdpIpEthBypassCmacRxTx;
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

(* synthesize, no_default_clock, no_default_reset *)
module mkXdmaUdpIpEthBypassCmacRxTx(
    (* osc   = "udp_clk"       *) Clock udpClk,
    (* reset = "udp_reset"     *) Reset udpReset,
    (* osc   = "xdma_clk"      *) Clock xdmaClk,
    (* reset = "xdma_reset"    *) Reset xdmaReset,
    (* osc   = "cmac_rxtx_clk" *) Clock cmacRxTxClk,
    (* reset = "cmac_rx_reset" *) Reset cmacRxReset,
    (* reset = "cmac_tx_reset" *) Reset cmacTxReset,
    XdmaUdpIpEthBypassCmacRxTx ifc
);
    let isEnableRsFec = True;
    let isEnableFlowControl = False;
    let isCmacTxWaitRxAligned = True;
    let asyncFifoDepth = valueOf(ASYNC_FIFO_DEPTH);
    let asyncCdcStages = valueOf(ASYNC_CDC_STAGES);

    let udpIpEthRxTxBypForXdma <- mkUdpIpEthBypassRxTxForXdma(clocked_by udpClk, reset_by udpReset);
    
    // XDMA Clock Region
    let xdmaAxiStreamSync <- mkDuplexAxiStreamAsyncFifo(
        asyncFifoDepth,
        asyncCdcStages,
        udpClk,
        udpReset,
        xdmaClk,
        xdmaReset,
        xdmaReset,
        udpIpEthRxTxBypForXdma.xdmaAxiStreamTxIn,
        udpIpEthRxTxBypForXdma.xdmaAxiStreamRxOut
    );

    let rawXdmaAxiStreamRxOut <- mkFifoOutToRawAxiStreamMaster(xdmaAxiStreamSync.dstFifoOut, clocked_by xdmaClk, reset_by xdmaReset);
    let rawXdmaAxiStreamTxIn <- mkFifoInToRawAxiStreamSlave(xdmaAxiStreamSync.dstFifoIn, clocked_by xdmaClk, reset_by xdmaReset);

    // CMAC Clock Region
    let cmacAxiStreamSync <- mkDuplexAxiStreamAsyncFifo(
        asyncFifoDepth,
        asyncCdcStages,
        udpClk,
        udpReset,
        cmacRxTxClk,
        cmacRxReset,
        cmacTxReset,
        udpIpEthRxTxBypForXdma.cmacAxiStreamRxIn,
        udpIpEthRxTxBypForXdma.cmacAxiStreamTxOut
    );

    FifoOut#(FlowControlReqVec) txFlowCtrlReqVec <- mkDummyFifoOut;
    FifoIn#(FlowControlReqVec) rxFlowCtrlReqVec <- mkDummyFifoIn;
    
    let xilinxCmacCtrl <- mkXilinxCmacController(
        isEnableRsFec,
        isEnableFlowControl,
        isCmacTxWaitRxAligned,
        cmacAxiStreamSync.dstFifoOut,
        cmacAxiStreamSync.dstFifoIn,
        txFlowCtrlReqVec,
        rxFlowCtrlReqVec,
        cmacRxReset,
        cmacTxReset,
        clocked_by cmacRxTxClk
    );

    interface cmacController = xilinxCmacCtrl;
    interface xdmaAxiStreamTxIn  = rawXdmaAxiStreamTxIn;
    interface xdmaAxiStreamRxOut = rawXdmaAxiStreamRxOut;
endmodule
