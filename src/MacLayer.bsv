import FIFOF :: *;
import GetPut :: *;

import Ports :: *;
import StreamHandler :: *;
import EthernetTypes :: *;

import SemiFifo :: *;


module mkMacStream#(
    DataStreamPipeOut  udpIpStreamIn,
    MacMetaDataPipeOut macMetaDataIn,
    UdpConfig udpConfig
)(DataStreamPipeOut);
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
    DataStreamPipeOut macStreamOut <- mkAppendDataStreamHead(HOLD, SWAP, udpIpStreamIn, headerStream);
    return macStreamOut;

endmodule


function Bool checkMacHeader(EthHeader hdr, UdpConfig udpConfig);
    // To be modified
    let arpMatch = hdr.ethType == fromInteger(valueOf(ETH_TYPE_ARP));
    let ipMatch = (hdr.ethType == fromInteger(valueOf(ETH_TYPE_IP))) && (hdr.dstMacAddr == udpConfig.macAddr);
    return arpMatch || ipMatch;
endfunction

interface MacMetaDataAndUdpIpStream;
    interface MacMetaDataPipeOut macMetaDataOut;
    interface DataStreamPipeOut  udpIpStreamOut;
endinterface


module mkMacMetaDataAndUdpIpStream#(
    DataStreamPipeOut macStreamIn,
    UdpConfig udpConfig
)(MacMetaDataAndUdpIpStream);
    
    FIFOF#(MacMetaData) macMetaDataOutBuf <- mkFIFOF;
    FIFOF#(DataStream) udpIpStreamOutBuf <- mkFIFOF;
    Reg#(Bool) throwUdpIpStream <- mkReg(False);

    ExtractDataStream#(EthHeader) macExtractor <- mkExtractDataStreamHead(macStreamIn);

    rule doCheck;
        let header = macExtractor.extractDataOut.first; 
        macExtractor.extractDataOut.deq;
        let checkRes = checkMacHeader(header, udpConfig);
        if (checkRes) begin
            let macMeta = MacMetaData{
                macAddr: header.srcMacAddr,
                ethType: header.ethType
            };
            macMetaDataOutBuf.enq(macMeta);
            throwUdpIpStream <= False;
            $display("Mac Extractor Mac Addr Check: Pass");
        end
        else begin
            throwUdpIpStream <= True;
            $display("Mac Extractor Mac Addr Check: Fail");
        end
    endrule

    rule doPass if (!throwUdpIpStream);
        let udpIpStream = macExtractor.dataStreamOut.first; 
        macExtractor.dataStreamOut.deq;
        udpIpStreamOutBuf.enq(udpIpStream);
    endrule

    rule doThrow if (throwUdpIpStream);
        let udpIpStream = macExtractor.dataStreamOut.first;
        macExtractor.dataStreamOut.deq;
    endrule

    interface PipeOut udpIpStreamOut = convertFifoToPipeOut(udpIpStreamOutBuf);
    interface PipeOut macMetaDataOut = convertFifoToPipeOut(macMetaDataOutBuf);
endmodule
