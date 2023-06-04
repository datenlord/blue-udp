import GetPut::*;
import PAClib::*;
import FIFOF::*;

import UdpIpLayer::*;
import MacLayer::*;
import Ports::*;
import EthernetTypes::*;
import Utils::*;

interface UdpEthRx;
    interface Put#(UdpConfig) udpConfig;
    
    interface Put#(AxiStream) axiStreamIn;
    
    interface MacMetaDataPipeOut macMetaDataOut;
    interface UdpIpMetaDataPipeOut udpIpMetaDataOut;
    interface DataStreamPipeOut  dataStreamOut;
endinterface

(* synthesize *)
module mkUdpEthRx (UdpEthRx);
    FIFOF#(AxiStream) axiStreamInBuf <- mkFIFOF;
    
    Reg#(Maybe#(UdpConfig)) udpConfigReg <- mkReg(Invalid);
    let udpConfigVal = fromMaybe(?, udpConfigReg);

    DataStreamPipeOut macStream <- mkAxiStreamToDataStream(
        f_FIFOF_to_PipeOut(axiStreamInBuf)
    );

    MacMetaDataAndUdpIpStream macMetaAndUdpIpStream <- mkMacStreamExtractor(
        macStream, 
        udpConfigVal
    );

    UdpIpMetaDataAndDataStream udpIpMetaAndDataStream <- mkUdpIpStreamExtractor(
        macMetaAndUdpIpStream.udpIpStreamOut, 
        udpConfigVal
    );

    interface Put udpConfig;
        method Action put(UdpConfig conf);
            udpConfigReg <= tagged Valid conf;
        endmethod
    endinterface

    interface Put axiStreamIn;
        method Action put(AxiStream stream) if (isValid(udpConfigReg));
            axiStreamInBuf.enq(stream);
        endmethod
    endinterface

    interface PipeOut macMetaDataOut = macMetaAndUdpIpStream.macMetaDataOut;
    interface PipeOut udpIpMetaDataOut = udpIpMetaAndDataStream.udpIpMetaDataOut;
    interface PipeOut dataStreamOut = udpIpMetaAndDataStream.dataStreamOut;
endmodule