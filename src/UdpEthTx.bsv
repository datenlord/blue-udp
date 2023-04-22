import GetPut::*;
import PAClib::*;
import FIFOF::*;

import IpUdpLayer::*;
import MacLayer::*;
import Ports::*;
import EthernetTypes::*;
import Utils::*;

interface UdpEthTx;
    interface Put#(UdpConfig) udpConfig;
    interface Put#(UdpMetaData) udpMetaDataInTx;
    interface Put#(MacMetaData) macMetaDataInTx;
    interface Put#(DataStream) dataStreamInTx;
    interface AxiStreamPipeOut axiStreamOutTx;
endinterface

(* synthesize *)
module mkUdpEthTx (UdpEthTx);
    FIFOF#( DataStream) dataStreamInTxBuf <- mkFIFOF;
    FIFOF#(UdpMetaData) udpMetaDataInTxBuf <- mkFIFOF;
    FIFOF#(MacMetaData) macMetaDataInTxBuf <- mkFIFOF;
    
    Reg#(Maybe#(UdpConfig)) udpConfigReg <- mkReg(Invalid);
    
    DataStreamPipeOut ipUdpStream <- mkIpUdpGenerator(
        f_FIFOF_to_PipeOut(udpMetaDataInTxBuf),
        f_FIFOF_to_PipeOut(dataStreamInTxBuf),
        fromMaybe(?, udpConfigReg)
    );

    DataStreamPipeOut macStream <- mkMacGenerator(
        ipUdpStream, 
        f_FIFOF_to_PipeOut(macMetaDataInTxBuf), 
        fromMaybe(?, udpConfigReg)
    );

    AxiStreamPipeOut macAxiStream <- mkDataStreamToAxiStream(
        macStream
    );

    interface Put udpConfig;
        method Action put(UdpConfig conf);
            udpConfigReg <= tagged Valid conf;
        endmethod
    endinterface

    interface Put udpMetaDataInTx;
        method Action put(UdpMetaData meta) if (isValid(udpConfigReg));
            udpMetaDataInTxBuf.enq(meta);
        endmethod
    endinterface

    interface Put dataStreamInTx;
        method Action put(DataStream stream) if (isValid(udpConfigReg));
            dataStreamInTxBuf.enq(stream);
        endmethod
    endinterface

    interface Put macMetaDataInTx;
        method Action put(MacMetaData macMeta) if (isValid(udpConfigReg));
            macMetaDataInTxBuf.enq(macMeta);
        endmethod
    endinterface

    interface PipeOut axiStreamOutTx = macAxiStream;
endmodule