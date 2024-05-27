import FIFOF :: *;
import GetPut :: *;

import Ports :: *;
import EthUtils :: *;
import MacLayer :: *;
import UdpIpLayer :: *;
import UdpIpLayerForRdma :: *;

import SemiFifo :: *;

interface UdpIpEthBypassTx;
    interface Put#(UdpConfig) udpConfig;
    interface Put#(UdpIpMetaData) udpIpMetaDataIn;
    interface Put#(MacMetaDataWithBypassTag) macMetaDataIn;
    interface Put#(DataStream) dataStreamIn;
    interface AxiStreamLocalFifoOut axiStreamOut;
endinterface

module mkGenericUdpIpEthBypassTx#(Bool isSupportRdma)(UdpIpEthBypassTx);

    Integer bypassTagBufDepth = 8;

    Reg#(Maybe#(UdpConfig)) udpConfigReg <- mkReg(Invalid);
    let udpConfigVal = fromMaybe(?, udpConfigReg);

    FIFOF#(DataStream) dataStreamInBuf <- mkFIFOF;
    FIFOF#(UdpIpMetaData) udpIpMetaDataInBuf <- mkFIFOF;
    FIFOF#(MacMetaData) macMetaDataInBuf <- mkFIFOF;

    FIFOF#(Bool) isForkBypassChannelBuf <- mkSizedFIFOF(bypassTagBufDepth);
    FIFOF#(Bool) isJoinBypassChannelBuf <- mkSizedFIFOF(bypassTagBufDepth);
    FIFOF#(DataStream) dataStreamInterBuf <- mkFIFOF;
    FIFOF#(DataStream) rawPktStreamInterBuf <- mkFIFOF;
    FIFOF#(DataStream) joinedFinalMacOutputStreamBuf <- mkFIFOF;

    rule forkDataStream if (isForkBypassChannelBuf.notEmpty);
        let dataStream = dataStreamInBuf.first;
        dataStreamInBuf.deq;

        if (isForkBypassChannelBuf.first) begin
            rawPktStreamInterBuf.enq(dataStream);
        end
        else begin
            dataStreamInterBuf.enq(dataStream);
        end
        if (dataStream.isLast) begin
            isForkBypassChannelBuf.deq;
        end
    endrule
    
    DataStreamFifoOut udpIpStream = ?;
    if (isSupportRdma) begin
        udpIpStream <- mkUdpIpStreamForRdma(
            convertFifoToFifoOut(udpIpMetaDataInBuf),
            convertFifoToFifoOut(dataStreamInterBuf),
            udpConfigVal
        );
    end
    else begin
        udpIpStream <- mkUdpIpStream(
            udpConfigVal,
            convertFifoToFifoOut(dataStreamInterBuf),
            convertFifoToFifoOut(udpIpMetaDataInBuf),
            genUdpIpHeader
        );
    end

    DataStreamFifoOut macStream <- mkMacStream(
        udpIpStream, 
        convertFifoToFifoOut(macMetaDataInBuf), 
        udpConfigVal
    );

    rule joinDataStream if (isJoinBypassChannelBuf.notEmpty);
        DataStream dataStream;

        if (isJoinBypassChannelBuf.first) begin
            dataStream = rawPktStreamInterBuf.first;
            rawPktStreamInterBuf.deq;
        end
        else begin
            dataStream = macStream.first;
            macStream.deq;
        end
        if (dataStream.isLast) begin
            isJoinBypassChannelBuf.deq;
        end
        joinedFinalMacOutputStreamBuf.enq(dataStream);
    endrule



    interface Put udpConfig;
        method Action put(UdpConfig conf);
            udpConfigReg <= tagged Valid conf;
        endmethod
    endinterface

    interface Put udpIpMetaDataIn;
        method Action put(UdpIpMetaData udpIpMeta) if (isValid(udpConfigReg));
            udpIpMetaDataInBuf.enq(udpIpMeta);
        endmethod
    endinterface

    interface Put dataStreamIn;
        method Action put(DataStream stream) if (isValid(udpConfigReg));
            dataStreamInBuf.enq(stream);
        endmethod
    endinterface

    interface Put macMetaDataIn;
        method Action put(MacMetaDataWithBypassTag macMetaAndTag) if (isValid(udpConfigReg));
            if (!macMetaAndTag.isBypass) begin
                macMetaDataInBuf.enq(macMetaAndTag.macMetaData);
            end
            isForkBypassChannelBuf.enq(macMetaAndTag.isBypass);
            isJoinBypassChannelBuf.enq(macMetaAndTag.isBypass);
        endmethod
    endinterface
    interface FifoOut axiStreamOut = convertDataStreamToAxiStream(convertFifoToFifoOut(joinedFinalMacOutputStreamBuf));
endmodule
