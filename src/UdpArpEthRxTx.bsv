import GetPut :: *;
import PAClib :: *;
import FIFOF :: *;

import IpUdpLayer :: *;
import MacLayer :: *;
import ArpProcessor :: *;
import ArpCache :: *;
import Ports :: *;
import EthernetTypes :: *;
import Utils::*;

interface UdpArpEthRxTx;
    interface Put#(UdpConfig)  udpConfig;
    // Tx
    interface Put#(UdpMetaData) udpMetaDataInTx;
    interface Put#(DataStream)  dataStreamInTx;
    interface AxiStreamPipeOut  axiStreamOutTx;
    
    // Rx
    interface Put#(AxiStream)    axiStreamInRx;
    interface UdpMetaDataPipeOut udpMetaDataOutRx;
    interface DataStreamPipeOut  dataStreamOutRx;
endinterface

typedef enum{
    INIT, IP, ARP
} MuxState deriving(Bits, Eq);
typedef MuxState DemuxState;

(* synthesize *)
module mkUdpArpEthRxTx(UdpArpEthRxTx);
    Reg#(Maybe#(UdpConfig)) udpConfigReg <- mkReg(Invalid);
    let udpConfigVal = fromMaybe(?, udpConfigReg);
    // buffer of input ports
    FIFOF#(UdpMetaData) udpMetaDataTxBuf <- mkSizedFIFOF(valueOf(CACHE_CBUF_SIZE));
    FIFOF#(UdpMetaData) arpMetaDataTxBuf <- mkFIFOF;
    FIFOF#(DataStream)  dataStreamInTxBuf <- mkFIFOF;
    FIFOF#(AxiStream)  axiStreamInRxBuf <- mkFIFOF;

    // state elements of Tx datapath
    Reg#(MuxState) muxState <- mkReg(INIT);
    FIFOF#(DataStream) macPayloadTxBuf <- mkFIFOF;
    FIFOF#(MacMetaData) macMetaDataTxBuf <- mkFIFOF;

    // state elements of Rx datapath
    Reg#(DemuxState) demuxState <- mkReg(INIT); 
    FIFOF#(DataStream) ipUdpStreamRxBuf <- mkFIFOF;
    FIFOF#(DataStream) arpStreamRxBuf <- mkFIFOF;

    // Arp Processor
    ArpProcessor arpProcessor <- mkArpProcessor(
        f_FIFOF_to_PipeOut(arpStreamRxBuf),
        f_FIFOF_to_PipeOut(arpMetaDataTxBuf),
        udpConfigVal
    );

    // Tx datapath
    DataStreamPipeOut ipUdpStreamTx <- mkIpUdpGenerator(
        f_FIFOF_to_PipeOut(udpMetaDataTxBuf),
        f_FIFOF_to_PipeOut(dataStreamInTxBuf),
        udpConfigVal
    );
    rule doMux;
        if (muxState == INIT) begin
            let macMeta = arpProcessor.macMetaDataOut.first;
            arpProcessor.macMetaDataOut.deq;
            macMetaDataTxBuf.enq(macMeta);
            if (macMeta.ethType == fromInteger(valueOf(ETH_TYPE_ARP))) begin
                let arpStream = arpProcessor.arpStreamOut.first;
                arpProcessor.arpStreamOut.deq;
                macPayloadTxBuf.enq(arpStream);
                if (!arpStream.isLast) begin
                    muxState <= ARP;
                end
            end
            else if (macMeta.ethType == fromInteger(valueOf(ETH_TYPE_IP))) begin
                let ipUdpStream = ipUdpStreamTx.first;
                ipUdpStreamTx.deq;
                macPayloadTxBuf.enq(ipUdpStream);
                if (!ipUdpStream.isLast) begin
                    muxState <= IP;
                end
            end
        end
        else if (muxState == IP) begin
            let ipUdpStream = ipUdpStreamTx.first;
            ipUdpStreamTx.deq;
            macPayloadTxBuf.enq(ipUdpStream);
            if (ipUdpStream.isLast) begin
                muxState <= INIT;
            end
        end
        else if (muxState == ARP) begin
            let arpStream = arpProcessor.arpStreamOut.first;
            arpProcessor.arpStreamOut.deq;
            macPayloadTxBuf.enq(arpStream);
            if (arpStream.isLast) begin
                muxState <= INIT;
            end           
        end

    endrule
    DataStreamPipeOut macStreamTx <- mkMacGenerator(
        f_FIFOF_to_PipeOut(macPayloadTxBuf), 
        f_FIFOF_to_PipeOut(macMetaDataTxBuf), 
        udpConfigVal
    );
    AxiStreamPipeOut macAxiStreamOut <- mkDataStreamToAxiStream(macStreamTx);

    // Rx Datapath
    DataStreamPipeOut macStreamRx <- mkAxiStreamToDataStream(
        f_FIFOF_to_PipeOut(axiStreamInRxBuf)
    );
    MacExtractor macMetaAndLoad <- mkMacExtractor(
        macStreamRx, 
        udpConfigVal
    );

    rule doDemux;
        if (demuxState == INIT) begin
            let macMeta = macMetaAndLoad.macMetaDataOut.first;
            macMetaAndLoad.macMetaDataOut.deq;
            let dataStream = macMetaAndLoad.dataStreamOut.first;
            macMetaAndLoad.dataStreamOut.deq;

            if (macMeta.ethType == fromInteger(valueOf(ETH_TYPE_ARP))) begin
                arpStreamRxBuf.enq(dataStream);
                if (!dataStream.isLast) begin
                    demuxState <= ARP;
                end
            end
            else if (macMeta.ethType == fromInteger(valueOf(ETH_TYPE_IP))) begin
                ipUdpStreamRxBuf.enq(dataStream);
                if (!dataStream.isLast) begin
                    demuxState <= IP;
                end
            end
        end
        else if (demuxState == IP) begin
            let dataStream = macMetaAndLoad.dataStreamOut.first;
            macMetaAndLoad.dataStreamOut.deq;
            ipUdpStreamRxBuf.enq(dataStream);
            if (dataStream.isLast) begin
                demuxState <= INIT;
            end
        end
        else if (demuxState == ARP) begin
            let dataStream = macMetaAndLoad.dataStreamOut.first;
            macMetaAndLoad.dataStreamOut.deq;
            arpStreamRxBuf.enq(dataStream);
            if (dataStream.isLast) begin
                demuxState <= INIT;
            end         
        end
    endrule

    IpUdpExtractor udpMetaAndLoad <- mkIpUdpExtractor(
        f_FIFOF_to_PipeOut(ipUdpStreamRxBuf), 
        udpConfigVal
    );


    // Config Interface
    interface Put udpConfig;
        method Action put(UdpConfig conf);
            udpConfigReg <= tagged Valid conf;
        endmethod
    endinterface

    // Tx interface
    interface Put udpMetaDataInTx;
        method Action put(UdpMetaData meta) if (isValid(udpConfigReg));
            udpMetaDataTxBuf.enq(meta);
            arpMetaDataTxBuf.enq(meta);
        endmethod
    endinterface
    interface Put dataStreamInTx;
        method Action put(DataStream stream) if (isValid(udpConfigReg));
            dataStreamInTxBuf.enq(stream);
        endmethod
    endinterface
    interface PipeOut axiStreamOutTx = macAxiStreamOut;

    // Rx interface
    interface Put axiStreamInRx;
        method Action put(AxiStream stream) if (isValid(udpConfigReg));
            axiStreamInRxBuf.enq(stream);
        endmethod
    endinterface
    interface PipeOut udpMetaDataOutRx = udpMetaAndLoad.udpMetaDataOut;
    interface PipeOut dataStreamOutRx  = udpMetaAndLoad.dataStreamOut;

endmodule