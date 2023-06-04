import GetPut::*;
import PAClib::*;
import FIFOF::*;

import UdpIpLayer::*;
import MacLayer::*;
import Ports::*;
import EthernetTypes::*;
import Utils::*;

interface UdpEthTx;
    interface Put#(UdpConfig) udpConfig;
    interface Put#(UdpIpMetaData) udpIpMetaDataIn;
    interface Put#(MacMetaData) macMetaDataIn;
    interface Put#(DataStream) dataStreamIn;
    interface AxiStreamPipeOut axiStreamOut;
endinterface

(* synthesize *)
module mkUdpEthTx (UdpEthTx);
    FIFOF#( DataStream) dataStreamInBuf <- mkFIFOF;
    FIFOF#(UdpIpMetaData) udpIpMetaDataInBuf <- mkFIFOF;
    FIFOF#(MacMetaData) macMetaDataInBuf <- mkFIFOF;
    
    Reg#(Maybe#(UdpConfig)) udpConfigReg <- mkReg(Invalid);
    let udpConfigVal = fromMaybe(?, udpConfigReg);
    
    DataStreamPipeOut ipUdpStream <- mkUdpIpStreamGenerator(
        f_FIFOF_to_PipeOut(udpIpMetaDataInBuf),
        f_FIFOF_to_PipeOut(dataStreamInBuf),
        udpConfigVal
    );

    DataStreamPipeOut macStream <- mkMacStreamGenerator(
        ipUdpStream, 
        f_FIFOF_to_PipeOut(macMetaDataInBuf), 
        udpConfigVal
    );

    AxiStreamPipeOut macAxiStream <- mkDataStreamToAxiStream(
        macStream
    );

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
        method Action put(MacMetaData macMeta) if (isValid(udpConfigReg));
            macMetaDataInBuf.enq(macMeta);
        endmethod
    endinterface

    interface PipeOut axiStreamOut = macAxiStream;
endmodule