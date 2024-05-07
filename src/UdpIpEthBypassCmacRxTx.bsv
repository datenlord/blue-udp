import GetPut :: *;
import FIFOF :: *;

import Ports :: *;
import EthUtils :: *;
import EthernetTypes :: *;
import StreamHandler :: *;
import UdpIpEthBypassRx :: *;
import UdpIpEthBypassTx :: *;
import XilinxAxiStreamAsyncFifo :: *;
import XilinxCmacController :: *;

import SemiFifo :: *;

// UdpIpEthRxTx with bypass channel
interface UdpIpEthBypassRxTx;
    interface Put#(UdpConfig) udpConfig;
    
    // Tx Channel
    interface Put#(MacMetaDataWithBypassTag) macMetaDataTxIn;
    interface Put#(UdpIpMetaData) udpIpMetaDataTxIn;
    interface Put#(DataStream)    dataStreamTxIn;
    interface AxiStreamLocalFifoOut axiStreamTxOut;
    
    // Rx Channel
    interface Put#(AxiStreamLocal)   axiStreamRxIn;
    interface MacMetaDataFifoOut   macMetaDataRxOut;
    interface UdpIpMetaDataFifoOut udpIpMetaDataRxOut;
    interface DataStreamFifoOut    dataStreamRxOut;
    interface DataStreamFifoOut    rawPktStreamRxOut;
endinterface

module mkGenericUdpIpEthBypassRxTx#(Bool isSupportRdma)(UdpIpEthBypassRxTx);
    
    let udpIpEthBypassRx <- mkGenericUdpIpEthBypassRx(isSupportRdma);
    let udpIpEthBypassTx <- mkGenericUdpIpEthBypassTx(isSupportRdma);

    interface Put udpConfig;
        method Action put(UdpConfig udpConfig);
            udpIpEthBypassRx.udpConfig.put(udpConfig);
            udpIpEthBypassTx.udpConfig.put(udpConfig);
        endmethod
    endinterface

    interface macMetaDataTxIn = udpIpEthBypassTx.macMetaDataIn;
    interface udpIpMetaDataTxIn = udpIpEthBypassTx.udpIpMetaDataIn;
    interface dataStreamTxIn = udpIpEthBypassTx.dataStreamIn;
    interface axiStreamTxOut = udpIpEthBypassTx.axiStreamOut;

    interface axiStreamRxIn = udpIpEthBypassRx.axiStreamIn;
    interface macMetaDataRxOut = udpIpEthBypassRx.macMetaDataOut;
    interface udpIpMetaDataRxOut = udpIpEthBypassRx.udpIpMetaDataOut;
    interface dataStreamRxOut = udpIpEthBypassRx.dataStreamOut;
    interface rawPktStreamRxOut = udpIpEthBypassRx.rawPktStreamOut;
endmodule


// UdpIpEthRxTx with Xilinx 100Gb CMAC Controller
interface UdpIpEthBypassCmacRxTx;
    // Interface with CMAC IP
    (* prefix = "" *)
    interface XilinxCmacController cmacController;
    
    interface Put#(UdpConfig) udpConfig;
    
    // Tx Channel
    interface Put#(MacMetaDataWithBypassTag) macMetaDataTxIn;
    interface Put#(UdpIpMetaData) udpIpMetaDataTxIn;
    interface Put#(DataStream)    dataStreamTxIn;
            
    // Rx Channel
    interface MacMetaDataFifoOut   macMetaDataRxOut;
    interface UdpIpMetaDataFifoOut udpIpMetaDataRxOut;
    interface DataStreamFifoOut    dataStreamRxOut;
    interface DataStreamFifoOut    rawPktStreamRxOut;
endinterface

(* default_clock_osc = "udp_clk", default_reset = "udp_reset" *)
module mkUdpIpEthBypassCmacRxTx#(
    Bool isSupportRdma,
    Bool isEnableRsFec,
    Bool isCmacTxWaitRxAligned,
    Integer syncBramBufDepth,
    Integer cdcSyncStages
)(
    Clock cmacRxTxClk,
    Reset cmacRxReset,
    Reset cmacTxReset,
    UdpIpEthBypassCmacRxTx ifc
);
    let isEnableFlowControl = False;

    let udpClk <- exposeCurrentClock;
    let udpReset <- exposeCurrentReset;

    let udpIpEthBypassRxTx <- mkGenericUdpIpEthBypassRxTx(isSupportRdma);

    let axiStream512TxOut <- mkAxiStream512FifoOut(udpIpEthBypassRxTx.axiStreamTxOut);
    
    let axiStreamRxIn <- mkPutToFifoIn(udpIpEthBypassRxTx.axiStreamRxIn);
    let axiStream512RxIn <- mkAxiStream512FifoIn(axiStreamRxIn);

    let axiStream512Sync <- mkDuplexAxiStreamAsyncFifo(
        syncBramBufDepth,
        cdcSyncStages,
        udpClk,
        udpReset,
        cmacRxTxClk,
        cmacRxReset,
        cmacTxReset,
        axiStream512RxIn,
        axiStream512TxOut
    );

    FifoOut#(FlowControlReqVec) txFlowCtrlReqVec <- mkDummyFifoOut;
    FifoIn#(FlowControlReqVec) rxFlowCtrlReqVec <- mkDummyFifoIn;
    let xilinxCmacCtrl <- mkXilinxCmacController(
        isEnableRsFec,
        isEnableFlowControl,
        isCmacTxWaitRxAligned,
        axiStream512Sync.dstFifoOut,
        axiStream512Sync.dstFifoIn,
        txFlowCtrlReqVec,
        rxFlowCtrlReqVec,
        cmacRxReset,
        cmacTxReset,
        clocked_by cmacRxTxClk
    );

    interface udpConfig = udpIpEthBypassRxTx.udpConfig;

    interface cmacController = xilinxCmacCtrl;

    interface macMetaDataTxIn = udpIpEthBypassRxTx.macMetaDataTxIn;
    interface udpIpMetaDataTxIn = udpIpEthBypassRxTx.udpIpMetaDataTxIn;
    interface dataStreamTxIn = udpIpEthBypassRxTx.dataStreamTxIn;

    interface macMetaDataRxOut = udpIpEthBypassRxTx.macMetaDataRxOut;
    interface udpIpMetaDataRxOut = udpIpEthBypassRxTx.udpIpMetaDataRxOut;
    interface dataStreamRxOut = udpIpEthBypassRxTx.dataStreamRxOut;
    interface rawPktStreamRxOut = udpIpEthBypassRxTx.rawPktStreamRxOut;
endmodule

typedef 48'h7486e21ace80 TARGET_MAC_ADDR;
typedef 48'h7486e21ace80 SOURCE_MAC_ADDR;

typedef 32'hC0A80102 TARGET_IP_ADDR;
typedef 32'hC0A80102 SOURCE_IP_ADDR;

typedef 32'h00000000 TEST_NET_MASK;
typedef 32'h00000000 TEST_GATE_WAY;
typedef 88 TEST_UDP_PORT;
typedef 2048 TEST_PAYLOAD_SIZE;


interface UdpIpEthBypassSimpleWrapper;
    interface AxiStreamLocalFifoIn  payloadAxiStreamTxIn;
    interface AxiStreamLocalFifoOut payloadAxiStreamRxOut;
    interface AxiStreamLocalFifoIn  packetAxiStreamRxIn;
    interface AxiStreamLocalFifoOut packetAxiStreamTxOut;
endinterface

module mkUdpIpEthBypassSimpleWrapper(UdpIpEthBypassSimpleWrapper);
    Bool isSupportRdma = True;
    Reg#(Bool) isUdpConfig <- mkReg(False);

    FIFOF#(AxiStreamLocal) axiStreamTxInBuf <- mkFIFOF;
    let dataStreamTxIn <- mkAxiStreamToDataStream(convertFifoToFifoOut(axiStreamTxInBuf));
    let udpIpEthBypassRxTx <- mkGenericUdpIpEthBypassRxTx(isSupportRdma);

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

    let axiStreamTxIn = convertFifoToFifoIn(axiStreamTxInBuf);
    let axiStreamRxOut = convertDataStreamToAxiStream(udpIpEthBypassRxTx.dataStreamRxOut);

    let axiStreamTxOut = udpIpEthBypassRxTx.axiStreamTxOut;
    let axiStreamRxIn <- mkPutToFifoIn(udpIpEthBypassRxTx.axiStreamRxIn);
    interface payloadAxiStreamTxIn  = axiStreamTxIn;
    interface payloadAxiStreamRxOut = axiStreamRxOut;
    interface packetAxiStreamRxIn  = axiStreamRxIn;
    interface packetAxiStreamTxOut = axiStreamTxOut;
endmodule
