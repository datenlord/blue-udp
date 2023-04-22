import GetPut::*;
import PAClib::*;
import FIFOF::*;

import IpUdpLayer::*;
import MacLayer::*;
import Ports::*;
import EthernetTypes::*;
import Utils::*;

interface UdpEthRx;
    interface Put#(UdpConfig) udpConfig;
    interface Put#(AxiStream) axiStreamInRx;
    
    interface MacMetaDataPipeOut macMetaDataOutRx;
    interface UdpMetaDataPipeOut udpMetaDataOutRx;
    interface DataStreamPipeOut  dataStreamOutRx;
endinterface

(* synthesize *)
module mkUdpEthRx (UdpEthRx);
    FIFOF#(AxiStream) axiStreamInRxBuf <- mkFIFOF;
    
    Reg#(Maybe#(UdpConfig)) udpConfigReg <- mkReg(Invalid);

    DataStreamPipeOut macStream <- mkAxiStreamToDataStream(
        f_FIFOF_to_PipeOut(axiStreamInRxBuf)
    );

    MacExtractor macMetaAndIpUdpStream <- mkMacExtractor(
        macStream, 
        fromMaybe(?, udpConfigReg)
    );

    IpUdpExtractor udpMetaAndLoadStream <- mkIpUdpExtractor(
        macMetaAndIpUdpStream.dataStreamOut, 
        fromMaybe(?, udpConfigReg)
    );

    interface Put udpConfig;
        method Action put(UdpConfig conf);
            udpConfigReg <= tagged Valid conf;
        endmethod
    endinterface
    interface Put axiStreamInRx;
        method Action put(AxiStream stream) if (isValid(udpConfigReg));
            axiStreamInRxBuf.enq(stream);
        endmethod
    endinterface
    interface PipeOut macMetaDataOutRx = macMetaAndIpUdpStream.macMetaDataOut;
    interface PipeOut udpMetaDataOutRx = udpMetaAndLoadStream.udpMetaDataOut;
    interface PipeOut dataStreamOutRx = udpMetaAndLoadStream.dataStreamOut;
endmodule