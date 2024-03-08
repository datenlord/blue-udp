import FIFOF :: *;
import GetPut :: *;
import Connectable :: *;

import Ports :: *;
import EthUtils :: *;
import MacLayer :: *;
import UdpIpLayer :: *;
import StreamHandler :: *;
import EthernetTypes :: *;
import PortConversion :: *;
import UdpIpLayerForRdma :: *;

import SemiFifo :: *;
import AxiStreamTypes :: *;
import BusConversion :: *;

interface UdpIpEthRx;
    interface Put#(UdpConfig) udpConfig;
    
    interface Put#(AxiStream256) axiStreamIn;
    
    interface MacMetaDataFifoOut macMetaDataOut;
    interface UdpIpMetaDataFifoOut udpIpMetaDataOut;
    interface DataStreamFifoOut  dataStreamOut;
endinterface

module mkGenericUdpIpEthRx#(Bool isSupportRdma)(UdpIpEthRx);
    FIFOF#(AxiStream256) axiStreamInBuf <- mkFIFOF;
    
    Reg#(Maybe#(UdpConfig)) udpConfigReg <- mkReg(Invalid);
    let udpConfigVal = fromMaybe(?, udpConfigReg);

    let macStream <- mkAxiStream256ToDataStream(
        convertFifoToFifoOut(axiStreamInBuf)
    );

    let macMetaAndUdpIpStream <- mkMacMetaDataAndUdpIpStream(
        macStream, 
        udpConfigVal
    );

    UdpIpMetaDataAndDataStream udpIpMetaAndDataStream;
    if (isSupportRdma) begin
        udpIpMetaAndDataStream <- mkUdpIpMetaDataAndDataStreamForRdma(
            macMetaAndUdpIpStream.udpIpStreamOut,
            udpConfigVal
        );
    end
    else begin
        udpIpMetaAndDataStream <- mkUdpIpMetaDataAndDataStream(
            udpConfigVal,
            macMetaAndUdpIpStream.udpIpStreamOut,
            extractUdpIpMetaData
        );
    end

    interface Put udpConfig;
        method Action put(UdpConfig conf);
            udpConfigReg <= tagged Valid conf;
        endmethod
    endinterface

    interface Put axiStreamIn;
        method Action put(AxiStream256 stream) if (isValid(udpConfigReg));
            axiStreamInBuf.enq(stream);
        endmethod
    endinterface

    interface FifoOut macMetaDataOut = macMetaAndUdpIpStream.macMetaDataOut;
    interface FifoOut udpIpMetaDataOut = udpIpMetaAndDataStream.udpIpMetaDataOut;
    interface FifoOut dataStreamOut = udpIpMetaAndDataStream.dataStreamOut;
endmodule


interface ForkRdmaPktStream;
    interface AxiStream256FifoOut rdmaPktAxiStreamOut;
    interface DataStreamFifoOut pktStreamOut;
endinterface

module mkForkRdmaPktStream#(
    AxiStream512FifoOut pktAxiStreamIn
)(ForkRdmaPktStream);
    FIFOF#(AxiStream512) rdmaPktAxiStreamInterBuf <- mkFIFOF;
    FIFOF#(AxiStream512) pktAxiStreamInterBuf <- mkFIFOF;
    
    FIFOF#(AxiStream256) rdmaPktAxiStreamOutBuf <- mkFIFOF;
    FIFOF#(AxiStream256) pktAxiStreamOutBuf <- mkFIFOF;

    Reg#(Bool) isFirstFrameReg <- mkReg(True);
    Reg#(Bool) isRdmaPktReg <- mkReg(False);

    rule seekRdmaPkt if (isFirstFrameReg);
        let axiStream512 = pktAxiStreamIn.first;
        pktAxiStreamIn.deq;
        TotalHeader totalHdr = unpack(swapEndian(truncate(axiStream512.tData)));

        let isIpPkt = totalHdr.ethHeader.ethType == fromInteger(valueOf(ETH_TYPE_IP));
        let isUdpPkt = isIpPkt && (totalHdr.ipHeader.ipProtocol == fromInteger(valueOf(IP_PROTOCOL_UDP)));
        let isRdmaPkt = isUdpPkt && totalHdr.udpHeader.dstPort == fromInteger(valueOf(UDP_PORT_RDMA));
        if (isRdmaPkt) begin
            rdmaPktAxiStreamInterBuf.enq(axiStream512);
        end
        else begin
            pktAxiStreamInterBuf.enq(axiStream512);
        end
        isRdmaPktReg <= isRdmaPkt;
        isFirstFrameReg <= axiStream512.tLast;
    endrule

    rule deMuxPktAxiStream if (!isFirstFrameReg);
        let axiStream512 = pktAxiStreamIn.first;
        pktAxiStreamIn.deq;
        if (isRdmaPktReg) begin
            rdmaPktAxiStreamInterBuf.enq(axiStream512);
        end
        else begin
            pktAxiStreamInterBuf.enq(axiStream512);
        end
        isFirstFrameReg <= axiStream512.tLast;
    endrule

    // Convert Stream Width
    let pktAxiStreamInterFifoIn <- mkDoubleAxiStreamFifoIn(convertFifoToFifoIn(pktAxiStreamOutBuf));
    mkConnection(pktAxiStreamInterFifoIn, convertFifoToFifoOut(pktAxiStreamInterBuf));
    let pktStreamFifoOut <- mkAxiStream256ToDataStream(convertFifoToFifoOut(pktAxiStreamOutBuf));
    
    let rdmaPktAxiStreamInterFifoIn <- mkDoubleAxiStreamFifoIn(convertFifoToFifoIn(rdmaPktAxiStreamOutBuf));
    mkConnection(rdmaPktAxiStreamInterFifoIn, convertFifoToFifoOut(rdmaPktAxiStreamInterBuf));
    
    interface rdmaPktAxiStreamOut = convertFifoToFifoOut(rdmaPktAxiStreamOutBuf);
    interface pktStreamOut = pktStreamFifoOut;
endmodule

interface UdpIpEthBypassRx;
    interface Put#(UdpConfig) udpConfig;
    
    interface Put#(AxiStream512) axiStreamIn;
        
    interface MacMetaDataFifoOut macMetaDataOut;
    interface UdpIpMetaDataFifoOut udpIpMetaDataOut;
    interface DataStreamFifoOut  dataStreamOut;
    
    interface DataStreamFifoOut  rawPktStreamOut;
endinterface

module mkGenericUdpIpEthBypassRx#(Bool isSupportRdma)(UdpIpEthBypassRx);
    FIFOF#(AxiStream512) axiStreamInBuf <- mkFIFOF;

    let forkRdmaPktStream <- mkForkRdmaPktStream(convertFifoToFifoOut(axiStreamInBuf));
    let udpIpEthRx <- mkGenericUdpIpEthRx(isSupportRdma);

    mkConnection(udpIpEthRx.axiStreamIn, toGet(forkRdmaPktStream.rdmaPktAxiStreamOut));

    interface Put udpConfig = udpIpEthRx.udpConfig;

    interface Put axiStreamIn = toPut(axiStreamInBuf);

    interface FifoOut macMetaDataOut = udpIpEthRx.macMetaDataOut;
    interface FifoOut udpIpMetaDataOut = udpIpEthRx.udpIpMetaDataOut;
    interface FifoOut dataStreamOut = udpIpEthRx.dataStreamOut;

    interface FifoOut rawPktStreamOut = forkRdmaPktStream.pktStreamOut;
endmodule


interface RawUdpIpEthRx;
    (* prefix = "s_udp_config" *) 
    interface RawUdpConfigBusSlave rawUdpConfig;
    (* prefix = "s_axis" *) 
    interface RawAxiStreamSlave#(AXIS256_TKEEP_WIDTH, AXIS_TUSER_WIDTH) rawAxiStreamIn;
    
    (* prefix = "m_mac_meta" *)
    interface RawMacMetaDataBusMaster rawMacMetaDataOut;
    (* prefix = "m_udp_meta" *)
    interface RawUdpIpMetaDataBusMaster rawUdpIpMetaDataOut;
    (* prefix = "m_data_stream" *)
    interface RawDataStreamBusMaster rawDataStreamOut;
endinterface

module mkGenericRawUdpIpEthRx#(Bool isSupportRdma)(RawUdpIpEthRx);
    UdpIpEthRx udpIpEthRx <- mkGenericUdpIpEthRx(isSupportRdma);

    let rawUdpConfigBus <- mkRawUdpConfigBusSlave(udpIpEthRx.udpConfig);
    let rawMacMetaDataBus <- mkRawMacMetaDataBusMaster(udpIpEthRx.macMetaDataOut);
    let rawUdpIpMetaDataBus <- mkRawUdpIpMetaDataBusMaster(udpIpEthRx.udpIpMetaDataOut);
    let rawDataStreamBus <- mkRawDataStreamBusMaster(udpIpEthRx.dataStreamOut);
    let rawAxiStreamBus <- mkPutToRawAxiStreamSlave(udpIpEthRx.axiStreamIn, CF);

    interface rawUdpConfig = rawUdpConfigBus;
    interface rawAxiStreamIn = rawAxiStreamBus;
    interface rawMacMetaDataOut = rawMacMetaDataBus;
    interface rawUdpIpMetaDataOut = rawUdpIpMetaDataBus;
    interface rawDataStreamOut = rawDataStreamBus;
endmodule

(* synthesize *)
module mkRawUdpIpEthRx(RawUdpIpEthRx);
    let rawUdpIpEthRx <- mkGenericRawUdpIpEthRx(`IS_SUPPORT_RDMA);
    return rawUdpIpEthRx;
endmodule

