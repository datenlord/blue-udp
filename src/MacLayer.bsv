import GetPut :: *;
import PAClib :: *;
import FIFOF :: *;

import EthernetTypes :: *;
import Ports :: *;
import Utils :: *;


module mkMacGenerator#(
    DataStreamPipeOut dataStreamIn,
    MacMetaDataPipeOut macMetaDataIn,
    UdpConfig udpConfig
)( DataStreamPipeOut );
    FIFOF#(EthHeader) ethHeaderBuf <- mkFIFOF;
    
    rule genEthHeader;
        let macMeta = macMetaDataIn.first; macMetaDataIn.deq;
        let ethHeader = EthHeader{
            dstMacAddr: macMeta.macAddr,
            srcMacAddr: udpConfig.macAddr,
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
    let ipMatch = (hdr.ethType == fromInteger(valueOf(ETH_TYPE_IP))) && (hdr.dstMacAddr == udpConfig.macAddr);
    return arpMatch || ipMatch;
endfunction

interface MacExtractor;
    interface MacMetaDataPipeOut macMetaDataOut;
    interface DataStreamPipeOut dataStreamOut;
endinterface

typedef enum{
    HEAD, PASS, THROW
} ExtState deriving(Bits, Eq);

module mkMacExtractor#(
    DataStreamPipeOut dataStreamIn,
    UdpConfig udpConfig
)(MacExtractor);
    
    FIFOF#(MacMetaData) macMetaDataOutBuf <- mkFIFOF;
    FIFOF#(DataStream) dataStreamOutBuf <- mkFIFOF;
    Reg#(ExtState) extState <- mkReg(HEAD);

    DataStreamExtract#(EthHeader) macExtractor <- mkDataStreamExtract(dataStreamIn);

    rule doCheck if (extState == HEAD);
        let header = macExtractor.extractDataOut.first; 
        macExtractor.extractDataOut.deq;
        let checkRes = checkMac(header, udpConfig);
        if (checkRes) begin
            let macMeta = MacMetaData{
                macAddr: header.srcMacAddr,
                ethType: header.ethType
            };
            macMetaDataOutBuf.enq(macMeta);
            extState <= PASS;
            $display("Mac Extractor Mac Addr Check: Pass");
        end
        else begin
            extState <= THROW;
            $display("Mac Extractor Mac Addr Check: Fail");
        end
    endrule

    rule doPass if (extState == PASS);
        let dataStream = macExtractor.dataStreamOut.first; 
        macExtractor.dataStreamOut.deq;
        dataStreamOutBuf.enq(dataStream);
        if (dataStream.isLast) begin
            extState <= HEAD;
        end
    endrule

    rule doThrow if (extState == THROW);
        let dataStream = macExtractor.dataStreamOut.first;
        macExtractor.dataStreamOut.deq;
        if (dataStream.isLast) begin
            extState <= HEAD;
        end
    endrule

    interface PipeOut dataStreamOut = f_FIFOF_to_PipeOut(dataStreamOutBuf);
    interface PipeOut macMetaDataOut = f_FIFOF_to_PipeOut(macMetaDataOutBuf);
endmodule
