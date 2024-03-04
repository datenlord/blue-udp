import FIFOF :: *;
import Cntrs :: *;
import GetPut :: *;
import Vector :: *;
import Arbiter :: *;
import BRAMFIFO :: *;

import Ports :: *;
import EthUtils :: *;
import SemiFifo :: *;
import EthernetTypes :: *;

function VirtualChannelIndex mapDscpToChannelIdx(IpDscp ipDscp);
    return truncateLSB(ipDscp);
endfunction

function IpDscp mapChannelIdxToDscp(VirtualChannelIndex channelIdx);
    return {channelIdx, 0};
endfunction

module mkFifoOutFairArbiter#(Vector#(clientNum, FifoOut#(dType)) clients)(FifoOut#(dType))
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
    
    return convertFifoToFifoOut(clientOutBuf);
endmodule

interface PriorityFlowControlRx#(
    numeric type bufPacketNum, 
    numeric type maxPacketFrameNum,
    numeric type pfcThreshold
);
    // pause and resume request from receiver
    interface FifoOut#(FlowControlReqVec) flowControlReqVecOut;
    
    interface Vector#(VIRTUAL_CHANNEL_NUM, FifoOut#(DataStream)) dataStreamOutVec;
    interface Vector#(VIRTUAL_CHANNEL_NUM, FifoOut#(UdpIpMetaData)) udpIpMetaDataOutVec;
endinterface

module mkPriorityFlowControlRx#(
    DataStreamFifoOut dataStreamIn,
    UdpIpMetaDataFifoOut udpIpMetaDataIn
)(PriorityFlowControlRx#(bufPacketNum, maxPacketFrameNum, pfcThreshold))
    provisos(
        Add#(pfcThreshold, __a, bufPacketNum),
        Mul#(bufPacketNum, maxPacketFrameNum, bufFrameNum),
        Log#(TAdd#(bufPacketNum, 1), packetCountWidth)
    );
    Integer virtualChannelNum = valueOf(VIRTUAL_CHANNEL_NUM);
    Integer udpIpMetaBufDepth = valueOf(bufPacketNum);
    Integer dataStreamBufDepth = valueOf(bufFrameNum);
    Integer flowCtrlThreshold = valueOf(pfcThreshold);
    
    FIFOF#(FlowControlReqVec) flowControlReqVecOutBuf <- mkFIFOF;
    Vector#(VIRTUAL_CHANNEL_NUM, Count#(Bit#(packetCountWidth))) packetNumCountVec <- replicateM(mkCount(0));
    Vector#(VIRTUAL_CHANNEL_NUM, Reg#(FlowControlRequest)) flowCtrlStateVec <- replicateM(mkReg(FLOW_CTRL_PASS));
    Vector#(VIRTUAL_CHANNEL_NUM, FIFOF#(UdpIpMetaData)) udpIpMetaDataOutBufVec <- replicateM(mkSizedFIFOF(udpIpMetaBufDepth));
    Vector#(VIRTUAL_CHANNEL_NUM, FIFOF#(DataStream)) dataStreamOutBufVec <- replicateM(mkSizedBRAMFIFOF(dataStreamBufDepth));
    

    FIFOF#(VirtualChannelIndex) dataStreamPassIdxBuf <- mkFIFOF;
    rule passUdpIpMetaData;
        let udpIpMetaData = udpIpMetaDataIn.first;
        udpIpMetaDataIn.deq;
        VirtualChannelIndex channelIdx = mapDscpToChannelIdx(udpIpMetaData.ipDscp);
        udpIpMetaData.ipDscp = 0;
        udpIpMetaDataOutBufVec[channelIdx].enq(udpIpMetaData);
        packetNumCountVec[channelIdx].incr(1);
        dataStreamPassIdxBuf.enq(channelIdx);
    endrule

    rule passDataStream;
        let channelIdx = dataStreamPassIdxBuf.first;
        let dataStream = dataStreamIn.first;
        dataStreamIn.deq;
        dataStreamOutBufVec[channelIdx].enq(dataStream);
        if (dataStream.isLast) begin
            dataStreamPassIdxBuf.deq;
        end
    endrule

    rule genFlowControlReq;
        FlowControlReqVec flowControlReqVec = replicate(tagged Invalid);
        Bool hasRequest = False;
        for (Integer i = 0; i < virtualChannelNum; i = i + 1) begin
            if (packetNumCountVec[i] >= fromInteger(flowCtrlThreshold)) begin
                if (flowCtrlStateVec[i] == FLOW_CTRL_PASS) begin
                    flowControlReqVec[i] = tagged Valid FLOW_CTRL_STOP;
                    flowCtrlStateVec[i] <= FLOW_CTRL_STOP;
                    hasRequest = True;
                    $display("PriorityFlowControlRx: channel %d send pause request", i);
                end
            end
            else begin
                if (flowCtrlStateVec[i] == FLOW_CTRL_STOP) begin
                    flowControlReqVec[i] = tagged Valid FLOW_CTRL_PASS;
                    flowCtrlStateVec[i] <= FLOW_CTRL_PASS;
                    hasRequest = True;
                    $display("PriorityFlowControlRx: channel %d send resume request", i);
                end
            end
        end
        if (hasRequest) begin
            flowControlReqVecOutBuf.enq(flowControlReqVec);
        end
    endrule


    Vector#(VIRTUAL_CHANNEL_NUM, FifoOut#(DataStream)) dataStreamVec = newVector;
    Vector#(VIRTUAL_CHANNEL_NUM, FifoOut#(UdpIpMetaData)) udpIpMetaDataVec = newVector;
    for (Integer i = 0; i < virtualChannelNum; i = i + 1) begin
        udpIpMetaDataVec[i] = convertFifoToFifoOut(udpIpMetaDataOutBufVec[i]);
        dataStreamVec[i] = (
            interface FifoOut#(DataStream)
                method DataStream first = dataStreamOutBufVec[i].first;
                method Bool notEmpty = dataStreamOutBufVec[i].notEmpty;
                method Action deq;
                    let dataStream = dataStreamOutBufVec[i].first;
                    dataStreamOutBufVec[i].deq;
                    if (dataStream.isLast) begin
                        packetNumCountVec[i].decr(1);
                    end
                endmethod
            endinterface
        );
    end

    interface flowControlReqVecOut = convertFifoToFifoOut(flowControlReqVecOutBuf);
    interface dataStreamOutVec = dataStreamVec;
    interface udpIpMetaDataOutVec = udpIpMetaDataVec;
endmodule


interface PriorityFlowControlTx;
    interface Get#(UdpIpMetaData) udpIpMetaDataOut;
    interface Get#(DataStream) dataStreamOut;
endinterface

module mkPriorityFlowControlTx#(
    FifoOut#(FlowControlReqVec) flowControlReqVecIn,
    Vector#(VIRTUAL_CHANNEL_NUM, DataStreamFifoOut) dataStreamInVec,
    Vector#(VIRTUAL_CHANNEL_NUM, UdpIpMetaDataFifoOut) udpIpMetaDataInVec
)(PriorityFlowControlTx);

    Integer virtualChannelNum = valueOf(VIRTUAL_CHANNEL_NUM);

    Vector#(VIRTUAL_CHANNEL_NUM, FIFOF#(UdpIpMetaData)) udpIpMetaDataInterBufVec <- replicateM(mkFIFOF);
    Vector#(VIRTUAL_CHANNEL_NUM, Reg#(FlowControlRequest)) channelStateVec <- replicateM(mkReg(FLOW_CTRL_PASS));
    
    FIFOF#(DataStream) dataStreamOutBuf <- mkFIFOF;
    FIFOF#(VirtualChannelIndex) dataStreamPassIdxBuf <- mkFIFOF;

    rule updateChannelState;
        let flowCtrlReqVec = flowControlReqVecIn.first;
        flowControlReqVecIn.deq;
        for (Integer i = 0; i < virtualChannelNum; i = i + 1) begin
            if (flowCtrlReqVec[i] matches tagged Valid .newState) begin
                channelStateVec[i] <= newState;
                String newStateStr = (newState == FLOW_CTRL_PASS) ? "Pass" : "Pause";
                $display("PriorityFlowControlTx: Channel %d switch to ", i, newStateStr);
            end
        end
    endrule

    for (Integer idx = 0; idx < virtualChannelNum; idx = idx + 1) begin
        rule passUdpIpMetaData if (channelStateVec[idx] == FLOW_CTRL_PASS);
            let udpIpMetaData = udpIpMetaDataInVec[idx].first;
            udpIpMetaDataInVec[idx].deq;
            udpIpMetaData.ipDscp = mapChannelIdxToDscp(fromInteger(idx));
            udpIpMetaDataInterBufVec[idx].enq(udpIpMetaData);
        endrule
    end

    let udpIpMetaDataArbitrated <- mkFifoOutFairArbiter(
        map(convertFifoToFifoOut, udpIpMetaDataInterBufVec)
    );

    rule passDataStream;
        let channelIdx = dataStreamPassIdxBuf.first;
        let dataStream = dataStreamInVec[channelIdx].first;
        dataStreamInVec[channelIdx].deq;
        dataStreamOutBuf.enq(dataStream);
        if (dataStream.isLast) begin
            dataStreamPassIdxBuf.deq;
        end
    endrule

    interface Get udpIpMetaDataOut;
        method ActionValue#(UdpIpMetaData) get();
            let udpIpMetaData = udpIpMetaDataArbitrated.first;
            udpIpMetaDataArbitrated.deq;
            dataStreamPassIdxBuf.enq(mapDscpToChannelIdx(udpIpMetaData.ipDscp));
            return udpIpMetaData;
        endmethod
    endinterface
    interface dataStreamOut = toGet(dataStreamOutBuf);
endmodule
