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
import UdpIpArpEthRxTx :: *;
import XilinxCmacController :: *;
import XilinxAxiStreamAsyncFifo :: *;

import SemiFifo :: *;
import AxiStreamTypes :: *;


typedef 64 ASYNC_FIFO_DEPTH;
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
    interface AxiStream512PipeIn  xdmaAxiStreamTxIn;
    interface AxiStream512PipeOut xdmaAxiStreamRxOut;
    interface AxiStream512PipeIn  cmacAxiStreamRxIn;
    interface AxiStream512PipeOut cmacAxiStreamTxOut;
endinterface

module mkUdpIpArpEthRxTxForXdma(UdpIpArpEthRxTxForXdma);
    Reg#(Bool) isUdpConfig <- mkReg(False);

    FIFOF#(AxiStream256) xdmaAxiStreamInBuf <- mkFIFOF;
    let dataStreamTxIn <- mkAxiStream256ToDataStream(convertFifoToPipeOut(xdmaAxiStreamInBuf));
    let udpIpArpEthRxTx <- mkGenericUdpIpArpEthRxTx(`IS_SUPPORT_RDMA);

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

    let xdmaAxiStream256TxIn = convertFifoToPipeIn(xdmaAxiStreamInBuf);
    let xdmaAxiStream256RxOut = convertDataStreamToAxiStream256(udpIpArpEthRxTx.dataStreamRxOut);
    let xdmaAxiStream512TxIn <- mkDoubleAxiStreamPipeIn(xdmaAxiStream256TxIn);
    let xdmaAxiStream512RxOut <- mkDoubleAxiStreamPipeOut(xdmaAxiStream256RxOut);

    let cmacAxiStream256RxIn <- mkPutToPipeIn(udpIpArpEthRxTx.axiStreamRxIn);
    let cmacAxiStream512RxIn <- mkDoubleAxiStreamPipeIn(cmacAxiStream256RxIn);
    let cmacAxiStream512TxOut <- mkDoubleAxiStreamPipeOut(udpIpArpEthRxTx.axiStreamTxOut);
    interface xdmaAxiStreamTxIn  = xdmaAxiStream512TxIn;
    interface xdmaAxiStreamRxOut = xdmaAxiStream512RxOut;
    interface cmacAxiStreamRxIn  = cmacAxiStream512RxIn;
    interface cmacAxiStreamTxOut = cmacAxiStream512TxOut;
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
(* synthesize, no_default_clock, no_default_reset *)
module mkXdmaUdpIpArpEthCmacRxTx(
    (* osc   = "udp_clk"       *) Clock udpClk,
    (* reset = "udp_reset"     *) Reset udpReset,
    (* osc   = "xdma_clk"      *) Clock xdmaClk,
    (* reset = "xdma_reset"    *) Reset xdmaReset,
    (* osc   = "cmac_rxtx_clk" *) Clock cmacRxTxClk,
    (* reset = "cmac_rx_reset" *) Reset cmacRxReset,
    (* reset = "cmac_tx_reset" *) Reset cmacTxReset,
    XdmaUdpIpArpEthCmacRxTx ifc
);
    let isEnableFlowControl = False;
    let isCmacTxWaitRxAligned = True;
    let asyncFifoDepth = valueOf(ASYNC_FIFO_DEPTH);
    let asyncCdcStages = valueOf(ASYNC_CDC_STAGES);

    let udpIpArpEthRxTxForXdma <- mkUdpIpArpEthRxTxForXdma(clocked_by udpClk, reset_by udpReset);
    
    // XDMA Clock Region
    let xdmaAxiStreamSync <- mkDuplexAxiStreamAsyncFifo(
        asyncFifoDepth,
        asyncCdcStages,
        udpClk,
        udpReset,
        xdmaClk,
        xdmaReset,
        xdmaReset,
        udpIpArpEthRxTxForXdma.xdmaAxiStreamTxIn,
        udpIpArpEthRxTxForXdma.xdmaAxiStreamRxOut
    );

    let rawXdmaAxiStreamRxOut <- mkPipeOutToRawAxiStreamMaster(xdmaAxiStreamSync.dstPipeOut, clocked_by xdmaClk, reset_by xdmaReset);
    let rawXdmaAxiStreamTxIn <- mkPipeInToRawAxiStreamSlave(xdmaAxiStreamSync.dstPipeIn, clocked_by xdmaClk, reset_by xdmaReset);

    // CMAC Clock Region
    let cmacAxiStreamSync <- mkDuplexAxiStreamAsyncFifo(
        asyncFifoDepth,
        asyncCdcStages,
        udpClk,
        udpReset,
        cmacRxTxClk,
        cmacRxReset,
        cmacTxReset,
        udpIpArpEthRxTxForXdma.cmacAxiStreamRxIn,
        udpIpArpEthRxTxForXdma.cmacAxiStreamTxOut
    );

    PipeOut#(FlowControlReqVec) txFlowCtrlReqVec <- mkDummyPipeOut;
    PipeIn#(FlowControlReqVec) rxFlowCtrlReqVec <- mkDummyPipeIn;
    
    let xilinxCmacCtrl <- mkXilinxCmacController(
        isEnableFlowControl,
        isCmacTxWaitRxAligned,
        cmacAxiStreamSync.dstPipeOut,
        cmacAxiStreamSync.dstPipeIn,
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

