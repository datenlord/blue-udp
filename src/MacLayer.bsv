import FIFOF :: *;
import GetPut :: *;

import Ports :: *;
import StreamHandler :: *;
import EthernetTypes :: *;

import SemiFifo :: *;


module mkMacStream#(
    DataStreamFifoOut  udpIpStreamIn,
    MacMetaDataFifoOut macMetaDataIn,
    UdpConfig udpConfig
)(DataStreamFifoOut);
    FIFOF#(EthHeader) ethHeaderBuf <- mkFIFOF;
    
    rule genEthHeader;
        let macMeta = macMetaDataIn.first; 
        macMetaDataIn.deq;
        let ethHeader = EthHeader{
            dstMacAddr: macMeta.macAddr,
            srcMacAddr: udpConfig.macAddr,
            ethType: macMeta.ethType
        };
        ethHeaderBuf.enq(ethHeader);
    endrule

    FifoOut#(EthHeader) headerStream = convertFifoToFifoOut(ethHeaderBuf);
    DataStreamFifoOut macStreamOut <- mkAppendDataStreamHead(HOLD, SWAP, udpIpStreamIn, headerStream);
    return macStreamOut;

endmodule


function Bool checkMacHeader(EthHeader hdr, UdpConfig udpConfig);
    // To be modified
    let arpMatch = hdr.ethType == fromInteger(valueOf(ETH_TYPE_ARP));
    let ipMatch = (hdr.ethType == fromInteger(valueOf(ETH_TYPE_IP))) && (hdr.dstMacAddr == udpConfig.macAddr);
    return arpMatch || ipMatch;
endfunction

interface MacMetaDataAndUdpIpStream;
    interface MacMetaDataFifoOut macMetaDataOut;
    interface DataStreamFifoOut  udpIpStreamOut;
endinterface


module mkMacMetaDataAndUdpIpStream#(
    DataStreamFifoOut macStreamIn,
    UdpConfig udpConfig
)(MacMetaDataAndUdpIpStream);

    FIFOF#(MacMetaData) macMetaDataOutBuf <- mkFIFOF;
    FIFOF#(DataStream) udpIpStreamOutBuf <- mkFIFOF;
    Reg#(Maybe#(Bool)) hdrCheckState <- mkReg(tagged Invalid);

    ExtractDataStream#(EthHeader) macExtractor <- mkExtractDataStreamHead(macStreamIn);

    rule checkHdr if (!isValid(hdrCheckState));
        let header = macExtractor.extractDataOut.first; 
        macExtractor.extractDataOut.deq;
        let checkRes = checkMacHeader(header, udpConfig);

        hdrCheckState <= tagged Valid checkRes;
        if (checkRes) begin
            let macMeta = MacMetaData{
                macAddr: header.srcMacAddr,
                ethType: header.ethType
            };
            macMetaDataOutBuf.enq(macMeta);
            $display("Mac Extractor Mac Addr Check: Pass");
        end
        else begin
            $display("Mac Extractor Mac Addr Check: Fail");
        end
    endrule

    rule passStream if (isValid(hdrCheckState));
        let udpIpStream = macExtractor.dataStreamOut.first; 
        macExtractor.dataStreamOut.deq;
        if (fromMaybe(?, hdrCheckState)) begin
            udpIpStreamOutBuf.enq(udpIpStream);
        end
        if (udpIpStream.isLast) begin
            hdrCheckState <= tagged Invalid;
        end
    endrule

    interface FifoOut udpIpStreamOut = convertFifoToFifoOut(udpIpStreamOutBuf);
    interface FifoOut macMetaDataOut = convertFifoToFifoOut(macMetaDataOutBuf);
endmodule
