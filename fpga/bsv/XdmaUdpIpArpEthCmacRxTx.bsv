import FIFOF :: *;
import GetPut :: *;
import Connectable :: *;

import Ports :: *;
import BusConversion :: *;
import StreamHandler :: *;
import UdpIpArpEthRxTx :: *;
import XilinxCmacRxTxWrapper :: *;

import SemiFifo :: *;
import AxiStreamTypes :: *;


typedef 8 CMAC_SYNC_BUF_DEPTH;
typedef 48'h7486e21ace80 TEST_MAC_ADDR;
typedef 32'h7F000000 TEST_IP_ADDR;
typedef 32'h00000000 TEST_NET_MASK;
typedef 32'h00000000 TEST_GATE_WAY;
typedef 88 TEST_UDP_PORT;
typedef 2048 TEST_PAYLOAD_SIZE;

interface XdmaUdpIpArpEthCmacRxTx;
    // Interface with CMAC IP
    (* prefix = "" *)
    interface XilinxCmacRxTxWrapper cmacRxTxWrapper;
    
    // AXI-Stream Bus interacting with xdma
    (* prefix = "xdma_rx_axis" *)
    interface RawAxiStreamMaster#(AXIS_TKEEP_WIDTH, AXIS_TUSER_WIDTH) xdmaAxiStreamOutRx;
    (* prefix = "xdma_tx_axis" *)
    interface RawAxiStreamSlave#(AXIS_TKEEP_WIDTH, AXIS_TUSER_WIDTH) xdmaAxiStreamInTx;

endinterface

(* synthesize, default_clock_osc = "udp_clk", default_reset = "udp_reset" *)
module mkXdmaUdpIpArpEthCmacRxTx(
    (* osc = "cmac_rxtx_clk" *)   Clock cmacRxTxClk,
    (* reset = "cmac_rx_reset" *) Reset cmacRxReset,
    (* reset = "cmac_tx_reset" *) Reset cmacTxReset,
    XdmaUdpIpArpEthCmacRxTx ifc
);
    Reg#(Bool) isUdpConfig <- mkReg(False);
    FIFOF#(AxiStream512) xdmaAxiStreamInBuf <- mkFIFOF;
    Bool isWaitRxAligned = True;
    let udpIpArpEthCmacRxTx <- mkUdpIpArpEthCmacRxTx(
        `IS_SUPPORT_RDMA,
        isWaitRxAligned,
        valueOf(CMAC_SYNC_BUF_DEPTH),
        cmacRxTxClk,
        cmacRxReset,
        cmacTxReset
    );

    let axiStreamOutRx <- mkDataStreamToAxiStream512(udpIpArpEthCmacRxTx.dataStreamOutRx);
    let rawAxiStreamOutRx <- mkPipeOutToRawAxiStreamMaster(axiStreamOutRx);

    let rawAxiStreamInTx <- mkPipeInToRawAxiStreamSlave(convertFifoToPipeIn(xdmaAxiStreamInBuf));
    let dataStreamInTx <- mkAxiStream512ToDataStream(convertFifoToPipeOut(xdmaAxiStreamInBuf));
    //mkConnection(toGet(dataStreamInTx), udpIpArpEthCmacRxTx.dataStreamInTx);

    rule udpConfig if (!isUdpConfig);
        udpIpArpEthCmacRxTx.udpConfig.put(
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
        let dataStream = dataStreamInTx.first;
        dataStreamInTx.deq;
        if (dataStream.isFirst) begin
            udpIpArpEthCmacRxTx.udpIpMetaDataInTx.put(
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
        udpIpArpEthCmacRxTx.dataStreamInTx.put(dataStream);
    endrule

    rule recvUdpIpMetaData;
        let udpIpMetaData = udpIpArpEthCmacRxTx.udpIpMetaDataOutRx.first;
        udpIpArpEthCmacRxTx.udpIpMetaDataOutRx.deq;
    endrule
    
    
    interface cmacRxTxWrapper = udpIpArpEthCmacRxTx.cmacRxTxWrapper;
    interface xdmaAxiStreamInTx = rawAxiStreamInTx;
    interface xdmaAxiStreamOutRx = rawAxiStreamOutRx;
endmodule