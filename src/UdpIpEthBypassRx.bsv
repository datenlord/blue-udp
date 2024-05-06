import FIFOF :: *;
import GetPut :: *;
import Connectable :: *;

import Ports :: *;
import EthUtils :: *;
import EthernetTypes :: *;
import UdpIpEthRx :: *;
import PortConversion :: *;
import StreamHandler :: *;

import SemiFifo :: *;
import BusConversion :: *;
import AxiStreamTypes :: *;

function Bool checkRdmaPkt(AxiStream#(tKeepW, tUserW) axiStream) 
    provisos(Add#(a__, SizeOf#(TotalHeader), TMul#(tKeepW, 8)));
    TotalHeader totalHdr = unpack(swapEndian(truncate(axiStream.tData)));
    let isIpPkt = totalHdr.ethHeader.ethType == fromInteger(valueOf(ETH_TYPE_IP));
    let isUdpPkt = isIpPkt && (totalHdr.ipHeader.ipProtocol == fromInteger(valueOf(IP_PROTOCOL_UDP)));
    let isRdmaPkt = isUdpPkt && totalHdr.udpHeader.dstPort == fromInteger(valueOf(UDP_PORT_RDMA));
    return isRdmaPkt;
endfunction

interface ForkRdmaPktStream#(numeric type keepW, numeric type userW);
    interface FifoOut#(AxiStream#(keepW, userW)) rdmaPktStreamOut;
    interface FifoOut#(AxiStream#(keepW, userW)) otherPktStreamOut;
endinterface

typeclass ForkRdmaPkt#(numeric type keepW, numeric type userW);
    module mkForkRdmaPktStream#(
        FifoOut#(AxiStream#(keepW, userW)) streamIn
    )(ForkRdmaPktStream#(keepW, userW));
endtypeclass

instance ForkRdmaPkt#(AXIS256_TKEEP_WIDTH, AXIS_TUSER_WIDTH);
    module mkForkRdmaPktStream#(
        FifoOut#(AxiStream#(AXIS256_TKEEP_WIDTH, AXIS_TUSER_WIDTH)) axiStreamIn
    )(ForkRdmaPktStream#(AXIS256_TKEEP_WIDTH, AXIS_TUSER_WIDTH));
        let doubleAxiStreamIn <- mkDoubleAxiStreamFifoOut(axiStreamIn);

        let forkAxiStreamByHead <- mkForkAxiStreamByHead(doubleAxiStreamIn, checkRdmaPkt);

        let rdmaPktStream <- mkHalfAxiStreamFifoOut(forkAxiStreamByHead.trueAxiStreamOut);
        let otherPktStream <- mkHalfAxiStreamFifoOut(forkAxiStreamByHead.falseAxiStreamOut);

        interface rdmaPktStreamOut = rdmaPktStream;
        interface otherPktStreamOut = otherPktStream;
    endmodule
endinstance

instance ForkRdmaPkt#(AXIS512_TKEEP_WIDTH, AXIS_TUSER_WIDTH);
    module mkForkRdmaPktStream#(
        FifoOut#(AxiStream#(AXIS512_TKEEP_WIDTH, AXIS_TUSER_WIDTH)) axiStreamIn
    )(ForkRdmaPktStream#(AXIS512_TKEEP_WIDTH, AXIS_TUSER_WIDTH));
        let forkAxiStreamByHead <- mkForkAxiStreamByHead(axiStreamIn, checkRdmaPkt);

        interface rdmaPktStreamOut = forkAxiStreamByHead.trueAxiStreamOut;
        interface otherPktStreamOut = forkAxiStreamByHead.falseAxiStreamOut;
    endmodule
endinstance

instance ForkRdmaPkt#(AXIS1024_TKEEP_WIDTH, AXIS_TUSER_WIDTH);
    module mkForkRdmaPktStream#(
        FifoOut#(AxiStream#(AXIS1024_TKEEP_WIDTH, AXIS_TUSER_WIDTH)) axiStreamIn
    )(ForkRdmaPktStream#(AXIS1024_TKEEP_WIDTH, AXIS_TUSER_WIDTH));
        let forkAxiStreamByHead <- mkForkAxiStreamByHead(axiStreamIn, checkRdmaPkt);

        interface rdmaPktStreamOut = forkAxiStreamByHead.trueAxiStreamOut;
        interface otherPktStreamOut = forkAxiStreamByHead.falseAxiStreamOut;
    endmodule
endinstance

interface UdpIpEthBypassRx;
    interface Put#(UdpConfig) udpConfig;
    
    interface Put#(AxiStreamLocal) axiStreamIn;
        
    interface MacMetaDataFifoOut macMetaDataOut;
    interface UdpIpMetaDataFifoOut udpIpMetaDataOut;
    interface DataStreamFifoOut  dataStreamOut;
    
    interface DataStreamFifoOut  rawPktStreamOut;
endinterface

module mkGenericUdpIpEthBypassRx#(Bool isSupportRdma)(UdpIpEthBypassRx);
    FIFOF#(AxiStreamLocal) axiStreamInBuf <- mkFIFOF;

    let forkRdmaPktStream <- mkForkRdmaPktStream(convertFifoToFifoOut(axiStreamInBuf));
    let udpIpEthRx <- mkGenericUdpIpEthRx(isSupportRdma);

    mkConnection(udpIpEthRx.axiStreamIn, toGet(forkRdmaPktStream.rdmaPktStreamOut));
    let rawPktDataStreamOut <- mkAxiStreamToDataStream(forkRdmaPktStream.otherPktStreamOut);

    interface udpConfig = udpIpEthRx.udpConfig;

    interface axiStreamIn = toPut(axiStreamInBuf);

    interface macMetaDataOut = udpIpEthRx.macMetaDataOut;
    interface udpIpMetaDataOut = udpIpEthRx.udpIpMetaDataOut;
    interface dataStreamOut = udpIpEthRx.dataStreamOut;

    interface rawPktStreamOut = rawPktDataStreamOut;
endmodule

interface RawUdpIpEthBypassRx;
    (* prefix = "s_udp_config" *) 
    interface RawUdpConfigBusSlave rawUdpConfig;
    (* prefix = "s_axis" *) 
    interface RawAxiStreamLocalSlave rawAxiStreamIn;
    
    (* prefix = "m_mac_meta" *)
    interface RawMacMetaDataBusMaster rawMacMetaDataOut;
    (* prefix = "m_udp_meta" *)
    interface RawUdpIpMetaDataBusMaster rawUdpIpMetaDataOut;
    (* prefix = "m_data_stream" *)
    interface RawDataStreamBusMaster rawDataStreamOut;

    (* prefix = "m_pkt_stream" *)
    interface RawDataStreamBusMaster rawPktStreamOut;
endinterface

module mkGenericRawUdpIpEthBypassRx#(Bool isSupportRdma)(RawUdpIpEthBypassRx);
    UdpIpEthBypassRx udpIpEthBypassRx <- mkGenericUdpIpEthBypassRx(isSupportRdma);

    let rawUdpConfigBus <- mkRawUdpConfigBusSlave(udpIpEthBypassRx.udpConfig);
    let rawAxiStreamBus <- mkPutToRawAxiStreamSlave(udpIpEthBypassRx.axiStreamIn, CF);
    let rawMacMetaDataBus <- mkRawMacMetaDataBusMaster(udpIpEthBypassRx.macMetaDataOut);
    let rawUdpIpMetaDataBus <- mkRawUdpIpMetaDataBusMaster(udpIpEthBypassRx.udpIpMetaDataOut);
    let rawDataStreamBus <- mkRawDataStreamBusMaster(udpIpEthBypassRx.dataStreamOut);
    let rawPktStreamBus <- mkRawDataStreamBusMaster(udpIpEthBypassRx.rawPktStreamOut);

    interface rawUdpConfig = rawUdpConfigBus;
    interface rawAxiStreamIn = rawAxiStreamBus;
    interface rawMacMetaDataOut = rawMacMetaDataBus;
    interface rawUdpIpMetaDataOut = rawUdpIpMetaDataBus;
    interface rawDataStreamOut = rawDataStreamBus;
    interface rawPktStreamOut = rawPktStreamBus;
endmodule

(* synthesize *)
module mkRawUdpIpEthBypassRx(RawUdpIpEthBypassRx);
    let rawUdpIpEthBypassRx <- mkGenericRawUdpIpEthBypassRx(`IS_SUPPORT_RDMA);
    return rawUdpIpEthBypassRx;
endmodule
