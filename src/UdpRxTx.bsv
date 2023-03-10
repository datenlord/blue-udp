import GetPut::*;
import PAClib::*;

import UdpTransmitter::*;
import UdpReceiver::*;
import Ports::*;


interface UdpRxTx;
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

module mkUdpRxTx(UdpRxTx);
    UdpTransmitter udpTx <- mkUdpTransmitter;
    UdpReceiver    udpRx <- mkUdpReceiver;


    interface Put udpConfig;
        method Action put(UdpConfig conf);
            udpTx.udpConfig.put(conf);
            udpRx.udpConfig.put(conf);
        endmethod
    endinterface

    interface Put metaDataTx = udpTx.metaDataIn;
    interface Put dataStreamInTx = udpTx.dataStreamIn;
    interface Put dataStreamInRx  = udpRx.dataStreamIn;
    interface PipeOut dataStreamOutTx= udpTx.dataStreamOut;
    interface PipeOut metaDataRx = udpRx.metaDataOut;
    interface PipeOut dataStreamOutRx = udpRx.dataStreamOut;
endmodule