import GetPut::*;
import PAClib::*;
import FIFOF::*;

import EthernetTypes::*;
import Ports::*;
import Utils::*;


module mkMacGenerator#(
    DataStreamPipeOut dataStreamIn,
    MacMetaDataPipeOut macMetaDataIn,
    Maybe#(UdpConfig) udpConfig
)( DataStreamPipeOut );
    FIFOF#(EthHeader) ethHeaderBuf <- mkFIFOF;
    let udpConfigVal = fromMaybe(?,udpConfig);
    
    rule genEthHeader if (isValid(udpConfig));
        let macMeta = macMetaDataIn.first; macMetaDataIn.deq;
        let ethHeader = EthHeader{
            dstMacAddr: macMeta.macAddr,
            srcMacAddr: udpConfigVal.srcMacAddr,
            ethType: macMeta.ethType
        };
        ethHeaderBuf.enq(ethHeader);
    endrule

    PipeOut#(EthHeader) headerStream = f_FIFOF_to_PipeOut(ethHeaderBuf);
    DataStreamPipeOut dataStreamOut <- mkDataStreamInsert(dataStreamIn, headerStream);
    return dataStreamOut;

endmodule


function Bool checkMac(EthHeader hdr, UdpConfig udpConfig);
    // To be modified
    let arpMatch = hdr.ethType == fromInteger(valueOf(ETH_TYPE_ARP));
    let ipMatch = (hdr.ethType == fromInteger(valueOf(ETH_TYPE_IP))) && (hdr.dstMacAddr == udpConfig.srcMacAddr);
    return arpMatch || ipMatch;
endfunction

interface MacExtractor;
    interface MacMetaDataPipeOut macMetaDataOut;
    interface DataStreamPipeOut dataStreamOut;
endinterface

typedef enum{
    PASS, THROW
} ExtState deriving(Bits, Eq);

module mkMacExtractor#(
    DataStreamPipeOut dataStreamIn,
    Maybe#(UdpConfig) udpConfig
)(MacExtractor);
    
    FIFOF#(MacMetaData) macMetaDataOutBuf <- mkFIFOF;
    FIFOF#(DataStream) dataStreamOutBuf <- mkFIFOF;
    Reg#(Maybe#(ExtState)) extState[2] <- mkCReg(2, Invalid);

    DataStreamExtract#(EthHeader) macExt <- mkDataStreamExtract(dataStreamIn);

    rule doCheck if (isValid(udpConfig));
        let header = macExt.extractDataOut.first; macExt.extractDataOut.deq;
        let checkRes = checkMac(header, fromMaybe(?,udpConfig));
        if (checkRes) begin
            let macMeta = MacMetaData{
                macAddr: header.srcMacAddr,
                ethType: header.ethType
            };
            macMetaDataOutBuf.enq(macMeta);
            extState[0] <= tagged Valid PASS;
            $display("Mac Ext: Check Pass ");
        end
        else begin
            extState[0] <= tagged Valid THROW;
            $display("Mac Ext: Check Fail");
        end
    endrule

    rule doPass if (isValid(extState[1]));
        let dataStream = macExt.dataStreamOut.first; macExt.dataStreamOut.deq;
        if (fromMaybe(?, extState[1]) == PASS) begin
            dataStreamOutBuf.enq(dataStream);
        end
        if (dataStream.isLast) begin
            extState[1] <= tagged Invalid;
        end
    endrule

    interface PipeOut dataStreamOut = f_FIFOF_to_PipeOut(dataStreamOutBuf);
    interface PipeOut macMetaDataOut = f_FIFOF_to_PipeOut(macMetaDataOutBuf);

endmodule
