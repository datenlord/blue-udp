import FIFOF :: *;
import GetPut :: *;
import Vector :: *;
import Clocks :: *;
import Connectable :: *;
import BRAMFIFO :: *;

import Ports :: *;
import EthernetTypes :: *;
import UdpIpArpEthRxTx :: *;
import XilinxCmacRxTxWrapper :: *;
import PriorityFlowControl :: *;

import SemiFifo :: *;


interface UdpIpArpEthRxTxWithPfc#(
    numeric type bufPacketNum, 
    numeric type maxPacketFrameNum,
    numeric type pfcThreshold
);
    // Udp Config
    interface Put#(UdpConfig) udpConfig;

    // Tx Channels
    interface AxiStream512PipeOut axiStreamOutTx;
    interface Vector#(VIRTUAL_CHANNEL_NUM, Put#(DataStream))    dataStreamInTxVec;
    interface Vector#(VIRTUAL_CHANNEL_NUM, Put#(UdpIpMetaData)) udpIpMetaDataInTxVec; 

    // Rx Channels
    interface Put#(AxiStream512)   axiStreamInRx;
    interface Vector#(VIRTUAL_CHANNEL_NUM, Get#(DataStream))    dataStreamOutRxVec;
    interface Vector#(VIRTUAL_CHANNEL_NUM, Get#(UdpIpMetaData)) udpIpMetaDataOutRxVec;
        
    // PFC Request
    interface Put#(FlowControlReqVec) flowControlReqVecIn;
    interface PipeOut#(FlowControlReqVec) flowControlReqVecOut;

endinterface

module mkUdpIpArpEthRxTxWithPfc(UdpIpArpEthRxTxWithPfc#(bufPacketNum, maxPacketFrameNum, pfcThreshold))
    provisos(Add#(pfcThreshold, a__, bufPacketNum));

    FIFOF#(FlowControlReqVec) flowControlReqVecInBuf <- mkFIFOF;
    Vector#(VIRTUAL_CHANNEL_NUM, FIFOF#(UdpIpMetaData)) udpIpMetaDataInTxBufVec <- replicateM(mkFIFOF);
    Vector#(VIRTUAL_CHANNEL_NUM, FIFOF#(DataStream)) dataStreamInTxBufVec <- replicateM(mkFIFOF);

    let udpIpArpEthRxTx <- mkUdpIpArpEthRxTx;

    let pfcTx <- mkPriorityFlowControlTx(
        convertFifoToPipeOut(flowControlReqVecInBuf),
        map(convertFifoToPipeOut, dataStreamInTxBufVec),
        map(convertFifoToPipeOut, udpIpMetaDataInTxBufVec)
    );
    mkConnection(pfcTx.udpIpMetaDataOut, udpIpArpEthRxTx.udpIpMetaDataInTx);
    mkConnection(pfcTx.dataStreamOut, udpIpArpEthRxTx.dataStreamInTx);

    PriorityFlowControlRx#(bufPacketNum, maxPacketFrameNum, pfcThreshold) pfcRx <- mkPriorityFlowControlRx(
        udpIpArpEthRxTx.dataStreamOutRx,
        udpIpArpEthRxTx.udpIpMetaDataOutRx
    );

    interface udpConfig = udpIpArpEthRxTx.udpConfig;

    interface axiStreamOutTx = udpIpArpEthRxTx.axiStreamOutTx;
    interface dataStreamInTxVec = map(toPut, dataStreamInTxBufVec);
    interface udpIpMetaDataInTxVec = map(toPut, udpIpMetaDataInTxBufVec);

    interface axiStreamInRx = udpIpArpEthRxTx.axiStreamInRx;
    interface dataStreamOutRxVec = pfcRx.dataStreamOutVec;
    interface udpIpMetaDataOutRxVec = pfcRx.udpIpMetaDataOutVec;

    interface flowControlReqVecIn = toPut(flowControlReqVecInBuf);
    interface flowControlReqVecOut = pfcRx.flowControlReqVecOut;
endmodule

interface UdpIpArpEthCmacRxTxWithPfc#(
    numeric type bufPacketNum, 
    numeric type maxPacketFrameNum,
    numeric type pfcThreshold
);
    // Interface with CMAC IP
    (* prefix = "" *)
    interface XilinxCmacRxTxWrapper cmacRxTxWrapper;
    
    // Configuration Interface
    interface Put#(UdpConfig)  udpConfig;
        
    // Tx Channels
    interface Vector#(VIRTUAL_CHANNEL_NUM, Put#(DataStream))    dataStreamInTxVec;
    interface Vector#(VIRTUAL_CHANNEL_NUM, Put#(UdpIpMetaData)) udpIpMetaDataInTxVec; 
    
    // Rx Channels
    interface Vector#(VIRTUAL_CHANNEL_NUM, Get#(DataStream))    dataStreamOutRxVec;
    interface Vector#(VIRTUAL_CHANNEL_NUM, Get#(UdpIpMetaData)) udpIpMetaDataOutRxVec;
endinterface

module mkUdpIpArpEthCmacRxTxWithPfc#(
    Bool isCmacTxWaitRxAligned,
    Integer syncBramBufDepth
)(
    Clock cmacRxTxClk,
    Reset cmacRxReset,
    Reset cmacTxReset,
    UdpIpArpEthCmacRxTxWithPfc#(bufPacketNum, maxPacketFrameNum, pfcThreshold) ifc
) provisos(Add#(pfcThreshold, a__, bufPacketNum));
    
    let isEnableFlowControl = True;
    let currentClock <- exposeCurrentClock;
    let currentReset <- exposeCurrentReset;
    
    SyncFIFOIfc#(AxiStream512) txAxiStreamSyncBuf <- mkSyncBRAMFIFO(
        syncBramBufDepth,
        currentClock,
        currentReset,
        cmacRxTxClk,
        cmacTxReset
    );

    SyncFIFOIfc#(AxiStream512) rxAxiStreamSyncBuf <- mkSyncBRAMFIFO(
        syncBramBufDepth,
        cmacRxTxClk,
        cmacRxReset,
        currentClock,
        currentReset
    );

    SyncFIFOIfc#(FlowControlReqVec) txFlowCtrlReqVecSyncBuf <- mkSyncBRAMFIFO(
        syncBramBufDepth,
        currentClock,
        currentReset,
        cmacRxTxClk,
        cmacTxReset
    );

    SyncFIFOIfc#(FlowControlReqVec) rxFlowCtrlReqVecSyncBuf <- mkSyncBRAMFIFO(
        syncBramBufDepth,
        cmacRxTxClk,
        cmacRxReset,
        currentClock,
        currentReset
    );

    let cmacWrapper <- mkXilinxCmacRxTxWrapper(
        isEnableFlowControl,
        isCmacTxWaitRxAligned,
        convertSyncFifoToPipeOut(txAxiStreamSyncBuf),
        convertSyncFifoToPipeIn(rxAxiStreamSyncBuf),
        convertSyncFifoToPipeOut(txFlowCtrlReqVecSyncBuf),
        convertSyncFifoToPipeIn(rxFlowCtrlReqVecSyncBuf),
        cmacRxReset,
        cmacTxReset,
        clocked_by cmacRxTxClk
    );

    UdpIpArpEthRxTxWithPfc#(bufPacketNum, maxPacketFrameNum, pfcThreshold) udpIpArpEthRxTxWithPfc <- mkUdpIpArpEthRxTxWithPfc;
    mkConnection(convertSyncFifoToPipeIn(txAxiStreamSyncBuf), udpIpArpEthRxTxWithPfc.axiStreamOutTx);
    mkConnection(toGet(convertSyncFifoToPipeOut(rxAxiStreamSyncBuf)), udpIpArpEthRxTxWithPfc.axiStreamInRx);
    mkConnection(convertSyncFifoToPipeIn(txFlowCtrlReqVecSyncBuf), udpIpArpEthRxTxWithPfc.flowControlReqVecOut);
    mkConnection(toGet(convertSyncFifoToPipeOut(rxFlowCtrlReqVecSyncBuf)), udpIpArpEthRxTxWithPfc.flowControlReqVecIn);


    interface cmacRxTxWrapper = cmacWrapper;
    interface udpConfig = udpIpArpEthRxTxWithPfc.udpConfig;
    interface udpIpMetaDataInTxVec = udpIpArpEthRxTxWithPfc.udpIpMetaDataInTxVec;
    interface dataStreamInTxVec = udpIpArpEthRxTxWithPfc.dataStreamInTxVec;
    interface udpIpMetaDataOutRxVec = udpIpArpEthRxTxWithPfc.udpIpMetaDataOutRxVec;
    interface dataStreamOutRxVec = udpIpArpEthRxTxWithPfc.dataStreamOutRxVec;
endmodule




