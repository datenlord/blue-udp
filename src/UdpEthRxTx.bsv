import GetPut::*;
import PAClib::*;
import FIFOF::*;

import IpUdpLayer::*;
import MacLayer::*;
import Ports::*;


interface UdpEthRxTx;
    interface Put#(UdpConfig)  udpConfig;
    // Tx
    interface Put#(MetaData)   metaDataTx;
    interface Put#(DataStream) dataStreamInTx;
    interface DataStreamPipeOut dataStreamOutTx;
    
    // Rx
    interface Put#(DataStream) dataStreamInRx;
    interface MetaDataPipeOut metaDataRx;
    interface DataStreamPipeOut dataStreamOutRx;
endinterface


module mkUdpEthRxTx#(
    // For testing
    MacMetaDataPipeOut macMetaDataIn

)(UdpEthRxTx);
    Reg#(Maybe#(UdpConfig)) udpConfigReg <- mkReg(Invalid);
    FIFOF#(MetaData) metaDataTxBuf <- mkFIFOF;
    FIFOF#(DataStream) dataStreamInTxBuf <- mkFIFOF;
    FIFOF#(DataStream) dataStreamInRxBuf <- mkFIFOF;

    // Tx datapath
    DataStreamPipeOut udpIpStream <- mkIpUdpGenerator(
        f_FIFOF_to_PipeOut(metaDataTxBuf),
        f_FIFOF_to_PipeOut(dataStreamInTxBuf),
        udpConfigReg
    );
    DataStreamPipeOut macStream <- mkMacGenerator(
        udpIpStream, macMetaDataIn, udpConfigReg
    ); 

    // Rx Datapath
    MacExtractor macExtractor <- mkMacExtractor(
        f_FIFOF_to_PipeOut(dataStreamInRxBuf), udpConfigReg
    );
    IpUdpExtractor ipUdpExtractor <- mkIpUdpExtractor(
        macExtractor.dataStreamOut, udpConfigReg
    );

    rule doDemux;
        macExtractor.macMetaDataOut.deq;
    endrule

    interface Put udpConfig;
        method Action put(UdpConfig conf);
            udpConfigReg <= tagged Valid conf;
        endmethod
    endinterface

    // Tx interface
    interface Put metaDataTx = toPut(metaDataTxBuf);
    interface Put dataStreamInTx = toPut(dataStreamInTxBuf);
    interface PipeOut dataStreamOutTx = macStream;

    // Rx interface
    interface Put dataStreamInRx = toPut(dataStreamInRxBuf);
    interface PipeOut metaDataRx = ipUdpExtractor.metaDataOut;
    interface PipeOut dataStreamOutRx = ipUdpExtractor.dataStreamOut;

endmodule