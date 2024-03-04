import FIFOF :: *;
import GetPut :: *;
import Vector :: *;
import Clocks :: *;
import Connectable :: *;
import BRAMFIFO :: *;

import Ports :: *;
import PortConversion :: *;
import EthernetTypes :: *;
import UdpIpArpEthRxTx :: *;
import PriorityFlowControl :: *;

import SemiFifo :: *;
import BusConversion :: *;
import AxiStreamTypes :: *;

typedef 8 BUF_PKT_NUM;
typedef 64 MAX_PKT_FRAME_NUM;
typedef 3 PFC_THRESHOLD;

interface PfcUdpIpArpEthRxTx#(
    numeric type bufPacketNum, 
    numeric type maxPacketFrameNum,
    numeric type pfcThreshold
);
    // Udp Config
    interface Put#(UdpConfig) udpConfig;

    // Tx Channels
    interface AxiStream256FifoOut axiStreamTxOut;
    interface Vector#(VIRTUAL_CHANNEL_NUM, Put#(DataStream))    dataStreamTxInVec;
    interface Vector#(VIRTUAL_CHANNEL_NUM, Put#(UdpIpMetaData)) udpIpMetaDataTxInVec; 

    // Rx Channels
    interface Put#(AxiStream256)   axiStreamRxIn;
    interface Vector#(VIRTUAL_CHANNEL_NUM, DataStreamFifoOut)    dataStreamRxOutVec;
    interface Vector#(VIRTUAL_CHANNEL_NUM, UdpIpMetaDataFifoOut) udpIpMetaDataRxOutVec;
        
    // PFC Request
    interface Put#(FlowControlReqVec) flowControlReqVecIn;
    interface FifoOut#(FlowControlReqVec) flowControlReqVecOut;

endinterface

module mkGenericPfcUdpIpArpEthRxTx#(Bool isSupportRdma)(PfcUdpIpArpEthRxTx#(bufPacketNum, maxPacketFrameNum, pfcThreshold))
    provisos(Add#(pfcThreshold, a__, bufPacketNum));

    FIFOF#(FlowControlReqVec) flowControlReqVecInBuf <- mkFIFOF;
    Vector#(VIRTUAL_CHANNEL_NUM, FIFOF#(UdpIpMetaData)) udpIpMetaDataTxInBufVec <- replicateM(mkFIFOF);
    Vector#(VIRTUAL_CHANNEL_NUM, FIFOF#(DataStream)) dataStreamTxInBufVec <- replicateM(mkFIFOF);

    let udpIpArpEthRxTx <- mkGenericUdpIpArpEthRxTx(isSupportRdma);

    let pfcTx <- mkPriorityFlowControlTx(
        convertFifoToFifoOut(flowControlReqVecInBuf),
        map(convertFifoToFifoOut, dataStreamTxInBufVec),
        map(convertFifoToFifoOut, udpIpMetaDataTxInBufVec)
    );
    mkConnection(pfcTx.udpIpMetaDataOut, udpIpArpEthRxTx.udpIpMetaDataTxIn);
    mkConnection(pfcTx.dataStreamOut, udpIpArpEthRxTx.dataStreamTxIn);

    PriorityFlowControlRx#(bufPacketNum, maxPacketFrameNum, pfcThreshold) pfcRx <- mkPriorityFlowControlRx(
        udpIpArpEthRxTx.dataStreamRxOut,
        udpIpArpEthRxTx.udpIpMetaDataRxOut
    );

    interface udpConfig = udpIpArpEthRxTx.udpConfig;

    interface axiStreamTxOut = udpIpArpEthRxTx.axiStreamTxOut;
    interface dataStreamTxInVec = map(toPut, dataStreamTxInBufVec);
    interface udpIpMetaDataTxInVec = map(toPut, udpIpMetaDataTxInBufVec);

    interface axiStreamRxIn = udpIpArpEthRxTx.axiStreamRxIn;
    interface dataStreamRxOutVec = pfcRx.dataStreamOutVec;
    interface udpIpMetaDataRxOutVec = pfcRx.udpIpMetaDataOutVec;

    interface flowControlReqVecIn = toPut(flowControlReqVecInBuf);
    interface flowControlReqVecOut = pfcRx.flowControlReqVecOut;
endmodule


// interface RawPfcUdpIpArpEthRxTx;
//     (* prefix = "s_udp_config" *)
//     interface RawUdpConfigBusSlave rawUdpConfig;
    
//     // Tx
//     interface Vector#(VIRTUAL_CHANNEL_NUM, RawUdpIpMetaDataBusSlave) rawUdpIpMetaSlaveVec;
//     interface Vector#(VIRTUAL_CHANNEL_NUM, RawDataStreamBusSlave) rawDataStreamSlaveVec;
//     (* prefix = "m_axi_stream" *)
//     interface RawAxiStreamMaster#(AXIS_TKEEP_WIDTH, AXIS_TUSER_WIDTH) rawAxiStreamOutTx;
    
//     // Rx
//     interface Vector#(VIRTUAL_CHANNEL_NUM, RawUdpIpMetaDataBusMaster) rawUdpIpMetaMasterVec;
//     interface Vector#(VIRTUAL_CHANNEL_NUM, RawDataStreamBusMaster) rawDataStreamMasterVec;
//     (* prefix = "s_axi_stream" *)
//     interface RawAxiStreamSlave#(AXIS_TKEEP_WIDTH, AXIS_TUSER_WIDTH) rawAxiStreamInRx;
// endinterface

// module mkRawPfcUdpIpArpEthRxTx(RawPfcUdpIpArpEthRxTx);

//     Vector#(VIRTUAL_CHANNEL_NUM, RawUdpIpMetaDataBusSlave) rawUdpIpMetaDataInTxVec;
//     Vector#(VIRTUAL_CHANNEL_NUM, RawDataStreamBusSlave) rawDataStreamInTxVec;
//     Vector#(VIRTUAL_CHANNEL_NUM, RawUdpIpMetaDataBusMaster) rawUdpIpMetaDataOutRxVec;
//     Vector#(VIRTUAL_CHANNEL_NUM, RawDataStreamBusMaster) rawDataStreamOutRxVec;

//     PfcUdpIpArpEthRxTx#(BUF_PKT_NUM, MAX_PKT_FRAME_NUM, PFC_THRESHOLD) pfcUdpIpArpEthRxTx <- mkGenericPfcUdpIpArpEthRxTx(`IS_SUPPORT_RDMA);

//     for (Integer i = 0; i < valueOf(VIRTUAL_CHANNEL_NUM); i = i + 1) begin
//         let rawUdpIpMetaInTx <- mkRawUdpIpMetaDataBusSlave(pfcUdpIpArpEthRxTx.udpIpMetaDataInTxVec[i]);
//         let rawDataStreamInTx <- mkRawDataStreamBusSlave(pfcUdpIpArpEthRxTx.dataStreamInTxVec[i]);
//         let rawUdpIpMetaOutRx <- mkRawUdpIpMetaDataBusMaster(pfcUdpIpArpEthRxTx.udpIpMetaDataOutRxVec[i]);
//         let rawDataStreamOutRx <- mkRawDataStreamBusMaster(pfcUdpIpArpEthRxTx.dataStreamOutRxVec[i]);

//         rawUdpIpMetaDataInTxVec[i] = rawUdpIpMetaInTx;
//         rawDataStreamInTxVec[i] = rawDataStreamInTx;
//         rawUdpIpMetaDataOutRxVec[i] = rawUdpIpMetaOutRx;
//         rawDataStreamOutRxVec[i] = rawDataStreamOutRx;
//     end

//     let rawConfig <- mkRawUdpConfigBusSlave(pfcUdpIpArpEthRxTx.udpConfig);
//     let rawAxiStreamTx <- mkFifoOutToRawAxiStreamMaster(pfcUdpIpArpEthRxTx.axiStreamOutTx);
//     let rawAxiStreamRx <- mkPutToRawAxiStreamSlave(pfcUdpIpArpEthRxTx.axiStreamInRx, CF);
//     interface rawUdpConfig = rawConfig;
//     interface rawAxiStreamOutTx = rawAxiStreamTx;
//     interface rawUdpIpMetaSlaveVec = rawUdpIpMetaDataInTxVec;
//     interface rawDataStreamSlaveVec = rawDataStreamInTxVec;
//     interface rawAxiStreamInRx = rawAxiStreamRx;
//     interface rawUdpIpMetaMasterVec = rawUdpIpMetaDataOutRxVec;
//     interface rawDataStreamMasterVec = rawDataStreamOutRxVec;
// endmodule
