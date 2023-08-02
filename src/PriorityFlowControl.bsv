import FIFOF :: *;
import Cntrs :: *;
import GetPut :: *;
import Vector :: *;
import Arbiter :: *;
import BRAMFIFO :: *;

import Ports :: *;
import Utils :: *;
import SemiFifo :: *;
import EthernetTypes :: *;

typedef enum {
    FLOW_CTRL_STOP,
    FLOW_CTRL_PASS
} FlowControlState deriving(Bits, Eq, FShow);

typedef struct {
    VirtualChannelIndex channelIdx;
    FlowControlState channelState;
} FlowControlRequest deriving(Bits, Eq, FShow);

module mkPipeOutFairArbiter#(Vector#(clientNum, PipeOut#(dType)) clients)(PipeOut#(dType))
    provisos(
        Bits#(dType, dSize),
        NumAlias#(TLog#(clientNum), clientIdxWidth)
    );

    Arbiter_IFC#(clientNum) fairArbiter <- mkArbiter(False);
    FIFOF#(Bit#(clientIdxWidth)) arbiterRespBuf <- mkFIFOF;
    FIFOF#(dType) clientOutBuf <- mkFIFOF;

    for (Integer i = 0; i < valueOf(clientNum); i = i + 1) begin
        rule sendArbiterReq if (arbiterRespBuf.notFull);
            if (clients[i].notEmpty) begin
                fairArbiter.clients[i].request;
            end
        endrule
    end

    rule recvArbiterResp;
        Vector#(clientNum, Bool) arbiterRespVec;
        for (Integer i = 0; i < valueOf(clientNum); i = i + 1) begin
            arbiterRespVec[i] = fairArbiter.clients[i].grant;
        end
        if (pack(arbiterRespVec) != 0) begin
            arbiterRespBuf.enq(fairArbiter.grant_id);
        end
    endrule

    rule selectClientOut;
        let clientIdx = arbiterRespBuf.first;
        arbiterRespBuf.deq;

        if (clients[clientIdx].notEmpty) begin
            let data = clients[clientIdx].first;
            clients[clientIdx].deq;
            clientOutBuf.enq(data);
        end
    endrule
    
    return convertFifoToPipeOut(clientOutBuf);
endmodule

interface PriorityFlowControlRx#(
    numeric type bufPacketNum, 
    numeric type maxPacketFrameNum,
    numeric type pfcThreshold
);
    // pause and resume request from receiver
    interface Get#(FlowControlRequest) flowControlReqOut;
    
    interface Vector#(VIRTUAL_CHANNEL_NUM, Get#(UdpIpMetaData)) udpIpMetaDataOutVec;
    interface Vector#(VIRTUAL_CHANNEL_NUM, Get#(DataStream)) dataStreamOutVec;
    interface Put#(UdpIpMetaDataAndChannelIdx) udpIpMetaAndChannelIdxIn;
    interface Put#(DataStream) dataStreamIn;
endinterface

module mkPriorityFlowControlRx(PriorityFlowControlRx#(bufPacketNum, maxPacketFrameNum, pfcThreshold))
    provisos(
        Add#(pfcThreshold, __a, bufPacketNum),
        Mul#(bufPacketNum, maxPacketFrameNum, bufFrameNum),
        Log#(TAdd#(bufPacketNum, 1), packetCountWidth)
    );
    Integer virtualChannelNum = valueOf(VIRTUAL_CHANNEL_NUM);
    Integer udpIpMetaBufDepth = valueOf(bufPacketNum);
    Integer dataStreamBufDepth = valueOf(bufFrameNum);
    Integer flowCtrlThreshold = valueOf(pfcThreshold);
    FIFOF#(UdpIpMetaDataAndChannelIdx) udpIpMetaAndChannelIdxInBuf <- mkFIFOF;
    FIFOF#(DataStream) dataStreamInBuf <- mkFIFOF;
    

    Vector#(VIRTUAL_CHANNEL_NUM, Count#(Bit#(packetCountWidth))) packetNumCountVec <- replicateM(mkCount(0));
    Vector#(VIRTUAL_CHANNEL_NUM, Reg#(FlowControlState)) flowCtrlStateVec <- replicateM(mkReg(FLOW_CTRL_PASS));
    Vector#(VIRTUAL_CHANNEL_NUM, FIFOF#(UdpIpMetaData)) udpIpMetaDataOutBufVec <- replicateM(mkSizedFIFOF(udpIpMetaBufDepth));
    Vector#(VIRTUAL_CHANNEL_NUM, FIFOF#(DataStream)) dataStreamOutBufVec <- replicateM(mkSizedBRAMFIFOF(dataStreamBufDepth));
    Vector#(VIRTUAL_CHANNEL_NUM, FIFOF#(FlowControlRequest)) flowControlReqBufVec <- replicateM(mkFIFOF);

    FIFOF#(VirtualChannelIndex) dataStreamPassIdxBuf <- mkFIFOF;
    rule passUdpIpMetaData;
        let udpIpMetaAndChannelIdx = udpIpMetaAndChannelIdxInBuf.first;
        udpIpMetaAndChannelIdxInBuf.deq;
        let channelIdx = udpIpMetaAndChannelIdx.channelIdx;
        let udpIpMetaData = udpIpMetaAndChannelIdx.udpIpMetaData;
        udpIpMetaDataOutBufVec[channelIdx].enq(udpIpMetaData);
        packetNumCountVec[channelIdx].incr(1);
        dataStreamPassIdxBuf.enq(channelIdx);
    endrule

    rule passDataStream;
        let channelIdx = dataStreamPassIdxBuf.first;
        let dataStream = dataStreamInBuf.first;
        dataStreamInBuf.deq;
        dataStreamOutBufVec[channelIdx].enq(dataStream);
        if (dataStream.isLast) begin
            dataStreamPassIdxBuf.deq;
        end
    endrule

    for (Integer i = 0; i < virtualChannelNum; i = i + 1) begin
        rule genFlowControlReq;
            let flowControlReq = FlowControlRequest {
                channelIdx: fromInteger(i),
                channelState: FLOW_CTRL_STOP
            };
            if (packetNumCountVec[i] >= fromInteger(flowCtrlThreshold)) begin
                if (flowCtrlStateVec[i] == FLOW_CTRL_PASS) begin
                    flowControlReqBufVec[i].enq(flowControlReq);
                    flowCtrlStateVec[i] <= FLOW_CTRL_STOP;
                end
            end
            else begin
                if (flowCtrlStateVec[i] == FLOW_CTRL_STOP) begin
                    flowControlReq.channelState = FLOW_CTRL_PASS;
                    flowControlReqBufVec[i].enq(flowControlReq);
                    flowCtrlStateVec[i] <= FLOW_CTRL_PASS;
                end
            end
        endrule
    end

    let flowControlReqPipeOut <- mkPipeOutFairArbiter(
        map(convertFifoToPipeOut, flowControlReqBufVec)
    );

    Vector#(VIRTUAL_CHANNEL_NUM, Get#(DataStream)) dataStreamPorts = newVector;
    Vector#(VIRTUAL_CHANNEL_NUM, Get#(UdpIpMetaData)) udpIpMetaDataPorts = newVector;
    for (Integer i = 0; i < virtualChannelNum; i = i + 1) begin
        udpIpMetaDataPorts[i] = toGet(udpIpMetaDataOutBufVec[i]);
        dataStreamPorts[i] = (
            interface Get#(DataStream)
                method ActionValue#(DataStream) get;
                    let dataStream = dataStreamOutBufVec[i].first;
                    dataStreamOutBufVec[i].deq;
                    if (dataStream.isLast) begin
                        packetNumCountVec[i].decr(1);
                    end
                    return dataStream;
                endmethod
            endinterface
        );
    end

    interface flowControlReqOut = toGet(flowControlReqPipeOut);
    interface dataStreamOutVec = dataStreamPorts;
    interface udpIpMetaDataOutVec = udpIpMetaDataPorts;
    interface udpIpMetaAndChannelIdxIn = toPut(udpIpMetaAndChannelIdxInBuf);
    interface dataStreamIn = toPut(dataStreamInBuf);
endmodule


interface PriorityFlowControlTx#(
    numeric type bufPacketNum, 
    numeric type maxPacketFrameNum
);
    // 
    interface Put#(FlowControlRequest) flowControlReqIn;
    //
    interface Vector#(VIRTUAL_CHANNEL_NUM, Put#(UdpIpMetaData)) udpIpMetaDataInVec;
    interface Vector#(VIRTUAL_CHANNEL_NUM, Put#(DataStream)) dataStreamInVec;
    
    interface Get#(UdpIpMetaDataAndChannelIdx) udpIpMetaAndChannelIdxOut;
    interface Get#(DataStream) dataStreamOut;
endinterface

module mkPriorityFlowControlTx(PriorityFlowControlTx#(bufPacketNum, maxPacketFrameNum))
    provisos(Mul#(bufPacketNum, maxPacketFrameNum, bufFrameNum));
    Integer udpIpMetaBufDepth = valueOf(bufPacketNum);
    Integer dataStreamBufDepth = valueOf(bufFrameNum);
    Integer virtualChannelNum = valueOf(VIRTUAL_CHANNEL_NUM);

    Vector#(VIRTUAL_CHANNEL_NUM, FIFOF#(DataStream)) dataStreamInBufVec <- replicateM(mkSizedBRAMFIFOF(dataStreamBufDepth));
    Vector#(VIRTUAL_CHANNEL_NUM, FIFOF#(UdpIpMetaData)) udpIpMetaDataInBufVec <- replicateM(mkSizedBRAMFIFOF(udpIpMetaBufDepth));
    Vector#(VIRTUAL_CHANNEL_NUM, FIFOF#(UdpIpMetaDataAndChannelIdx)) udpIpMetaAndChannelIdxBufVec <- replicateM(mkFIFOF);
    Vector#(VIRTUAL_CHANNEL_NUM, Reg#(FlowControlState)) channelStateVec <- replicateM(mkReg(FLOW_CTRL_PASS));
    
    FIFOF#(FlowControlRequest) flowControlReqBufVec <- mkFIFOF;
    FIFOF#(DataStream) dataStreamOutBufVec <- mkFIFOF;
    FIFOF#(UdpIpMetaDataAndChannelIdx) udpIpMetaAndChannelIdxOutBuf <- mkFIFOF;
    
    FIFOF#(VirtualChannelIndex) dataStreamPassIdxBuf <- mkFIFOF;

    rule setChannelState;
        let request = flowControlReqBufVec.first;
        flowControlReqBufVec.deq;
        channelStateVec[request.channelIdx] <= request.channelState;
    endrule

    for (Integer idx = 0; idx < virtualChannelNum; idx = idx + 1) begin
        rule passUdpIpMetaData if (channelStateVec[idx] == FLOW_CTRL_PASS);
            let udpIpMetaData = udpIpMetaDataInBufVec[idx].first;
            udpIpMetaDataInBufVec[idx].deq;
            udpIpMetaAndChannelIdxBufVec[idx].enq(
                UdpIpMetaDataAndChannelIdx {
                    udpIpMetaData: udpIpMetaData,
                    channelIdx: fromInteger(idx)
                }
            );
        endrule
    end

    let udpIpMetaAndChannelIdxPipeOut <- mkPipeOutFairArbiter(
        map(convertFifoToPipeOut, udpIpMetaAndChannelIdxBufVec)
    );
    rule passUdpIpMetaAndChannelIdx;
        let udpIpMetaAndChannelIdx = udpIpMetaAndChannelIdxPipeOut.first;
        udpIpMetaAndChannelIdxPipeOut.deq;
        let channelIdx = udpIpMetaAndChannelIdx.channelIdx;
        udpIpMetaAndChannelIdxOutBuf.enq(udpIpMetaAndChannelIdx);
        dataStreamPassIdxBuf.enq(channelIdx);
    endrule

    rule passDataStream;
        let channelIdx = dataStreamPassIdxBuf.first;
        let dataStream = dataStreamInBufVec[channelIdx].first;
        dataStreamInBufVec[channelIdx].deq;
        dataStreamOutBufVec.enq(dataStream);
        if (dataStream.isLast) begin
            dataStreamPassIdxBuf.deq;
        end
    endrule

    Vector#(VIRTUAL_CHANNEL_NUM, Put#(DataStream)) dataStreamPorts = newVector;
    Vector#(VIRTUAL_CHANNEL_NUM, Put#(UdpIpMetaData)) udpIpMetaDataPorts = newVector;
    for (Integer i = 0; i < virtualChannelNum; i = i + 1) begin
        dataStreamPorts[i] = toPut(dataStreamInBufVec[i]);
        udpIpMetaDataPorts[i] = toPut(udpIpMetaDataInBufVec[i]);
    end
    
    interface flowControlReqIn = toPut(flowControlReqBufVec);
    interface dataStreamInVec = dataStreamPorts;
    interface udpIpMetaDataInVec = udpIpMetaDataPorts;
    interface udpIpMetaAndChannelIdxOut = toGet(udpIpMetaAndChannelIdxOutBuf);
    interface dataStreamOut = toGet(dataStreamOutBufVec);
endmodule




