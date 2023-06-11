import GetPut :: *;
import FIFOF :: *;

import EthernetTypes :: *;
import Ports :: *;
import Utils :: *;
import SemiFifo :: *;


module mkMacStreamGenerator#(
    DataStreamPipeOut  udpIpStreamIn,
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

    PipeOut#(EthHeader) headerStream = convertFifoToPipeOut(ethHeaderBuf);
    DataStreamPipeOut macStreamOut <- mkDataStreamInsert(udpIpStreamIn, headerStream);
    return macStreamOut;

endmodule


function Bool checkMac(EthHeader hdr, UdpConfig udpConfig);
    // To be modified
    let arpMatch = hdr.ethType == fromInteger(valueOf(ETH_TYPE_ARP));
    let ipMatch = (hdr.ethType == fromInteger(valueOf(ETH_TYPE_IP))) && (hdr.dstMacAddr == udpConfig.macAddr);
    return arpMatch || ipMatch;
endfunction

interface MacMetaDataAndUdpIpStream;
    interface MacMetaDataPipeOut macMetaDataOut;
    interface DataStreamPipeOut  udpIpStreamOut;
endinterface

typedef enum{
    HEAD, PASS, THROW
} ExtState deriving(Bits, Eq);

module mkMacStreamExtractor#(
    DataStreamPipeOut macStreamIn,
    UdpConfig udpConfig
)(MacMetaDataAndUdpIpStream);
    
    FIFOF#(MacMetaData) macMetaDataOutBuf <- mkFIFOF;
    FIFOF#(DataStream) dataStreamOutBuf <- mkFIFOF;
    Reg#(ExtState) extState <- mkReg(HEAD);

    DataStreamExtract#(EthHeader) macExtractor <- mkDataStreamExtract(macStreamIn);

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
        let udpIpStream = macExtractor.dataStreamOut.first; 
        macExtractor.dataStreamOut.deq;
        dataStreamOutBuf.enq(udpIpStream);
        if (udpIpStream.isLast) begin
            extState <= HEAD;
        end
    endrule

    rule doThrow if (extState == THROW);
        let udpIpStream = macExtractor.dataStreamOut.first;
        macExtractor.dataStreamOut.deq;
        if (udpIpStream.isLast) begin
            extState <= HEAD;
        end
    endrule

    interface PipeOut udpIpStreamOut = convertFifoToPipeOut(dataStreamOutBuf);
    interface PipeOut macMetaDataOut = convertFifoToPipeOut(macMetaDataOutBuf);
endmodule
