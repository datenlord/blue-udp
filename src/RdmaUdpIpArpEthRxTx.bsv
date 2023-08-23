
import GetPut :: *;
import FIFOF :: *;

import Utils :: *;
import Ports :: *;
import MacLayer :: *;
import ArpCache :: *;
import UdpIpLayer :: *;
import ArpProcessor :: *;
import EthernetTypes :: *;
import UdpIpArpEthRxTx :: *;
import PortConversion :: *;
import UdpIpLayerForRdma :: *;

import SemiFifo :: *;
import AxiStreamTypes :: *;
import BusConversion :: *;

(* synthesize *)
module mkRdmaUdpIpArpEthRxTx(UdpIpArpEthRxTx);
    Reg#(Maybe#(UdpConfig)) udpConfigReg <- mkReg(Invalid);
    let udpConfigVal = fromMaybe(?, udpConfigReg);

    // buffer of input ports
    FIFOF#(UdpIpMetaData) udpMetaDataTxBuf <- mkSizedFIFOF(valueOf(CACHE_CBUF_SIZE));
    FIFOF#(UdpIpMetaData) arpMetaDataTxBuf <- mkFIFOF;
    FIFOF#(DataStream)  dataStreamInTxBuf <- mkFIFOF;
    FIFOF#(AxiStream512)   axiStreamInRxBuf <- mkFIFOF;

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
        convertFifoToPipeOut(arpStreamRxBuf),
        convertFifoToPipeOut(arpMetaDataTxBuf)
    );

    // Tx datapath
    DataStreamPipeOut ipUdpStreamTx <- mkUdpIpStreamForRdma(
        convertFifoToPipeOut(udpMetaDataTxBuf),
        convertFifoToPipeOut(dataStreamInTxBuf),
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

    DataStreamPipeOut macStreamTx <- mkMacStream(
        convertFifoToPipeOut(macPayloadTxBuf), 
        convertFifoToPipeOut(macMetaDataTxBuf), 
        udpConfigVal
    );
    AxiStream512PipeOut macAxiStreamOut <- mkDataStreamToAxiStream512(macStreamTx);

    // Rx Datapath
    let macStreamRx <- mkAxiStream512ToDataStream(
        convertFifoToPipeOut(axiStreamInRxBuf)
    );

    let macMetaAndUdpIpStream <- mkMacMetaDataAndUdpIpStream(
        macStreamRx, 
        udpConfigVal
    );

    rule doDemux;
        if (demuxState == INIT) begin
            let macMeta = macMetaAndUdpIpStream.macMetaDataOut.first;
            macMetaAndUdpIpStream.macMetaDataOut.deq;
            let udpIpStream = macMetaAndUdpIpStream.udpIpStreamOut.first;
            macMetaAndUdpIpStream.udpIpStreamOut.deq;

            if (macMeta.ethType == fromInteger(valueOf(ETH_TYPE_ARP))) begin
                arpStreamRxBuf.enq(udpIpStream);
                if (!udpIpStream.isLast) begin
                    demuxState <= ARP;
                end
            end
            else if (macMeta.ethType == fromInteger(valueOf(ETH_TYPE_IP))) begin
                ipUdpStreamRxBuf.enq(udpIpStream);
                if (!udpIpStream.isLast) begin
                    demuxState <= IP;
                end
            end
        end
        else if (demuxState == IP) begin
            let udpIpStream = macMetaAndUdpIpStream.udpIpStreamOut.first;
            macMetaAndUdpIpStream.udpIpStreamOut.deq;
            ipUdpStreamRxBuf.enq(udpIpStream);
            if (udpIpStream.isLast) begin
                demuxState <= INIT;
            end
        end
        else if (demuxState == ARP) begin
            let udpIpStream = macMetaAndUdpIpStream.udpIpStreamOut.first;
            macMetaAndUdpIpStream.udpIpStreamOut.deq;
            arpStreamRxBuf.enq(udpIpStream);
            if (udpIpStream.isLast) begin
                demuxState <= INIT;
            end 
        end
    endrule

    let udpIpMetaDataAndDataStream <- mkUdpIpMetaDataAndDataStreamForRdma(
        convertFifoToPipeOut(ipUdpStreamRxBuf), 
        udpConfigVal
    );


    // Udp Config Interface
    interface Put udpConfig;
        method Action put(UdpConfig conf);
            udpConfigReg <= tagged Valid conf;
            arpProcessor.udpConfig.put(conf);
        endmethod
    endinterface

    // Tx interface
    interface Put udpIpMetaDataInTx;
        method Action put(UdpIpMetaData meta) if (isValid(udpConfigReg));
            // generate ip packet
            udpMetaDataTxBuf.enq(meta);
            // mac address resolution request
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
        method Action put(AxiStream512 stream) if (isValid(udpConfigReg));
            axiStreamInRxBuf.enq(stream);
        endmethod
    endinterface
    interface PipeOut udpIpMetaDataOutRx = udpIpMetaDataAndDataStream.udpIpMetaDataOut;
    interface PipeOut dataStreamOutRx  = udpIpMetaDataAndDataStream.dataStreamOut;

endmodule


module mkRawRdmaUdpIpArpEthRxTx(RawUdpIpArpEthRxTx);
    UdpIpArpEthRxTx rdmaUdpRxTx <- mkRdmaUdpIpArpEthRxTx;

    let rawConfig <- mkRawUdpConfigBusSlave(rdmaUdpRxTx.udpConfig);
    let rawUdpIpMetaDataTx <- mkRawUdpIpMetaDataBusSlave(rdmaUdpRxTx.udpIpMetaDataInTx);
    let rawDataStreamTx <- mkRawDataStreamBusSlave(rdmaUdpRxTx.dataStreamInTx);
    let rawAxiStreamTx <- mkPipeOutToRawAxiStreamMaster(rdmaUdpRxTx.axiStreamOutTx);

    let rawUdpIpMetaDataRx <- mkRawUdpIpMetaDataBusMaster(rdmaUdpRxTx.udpIpMetaDataOutRx);
    let rawDataStreamRx <- mkRawDataStreamBusMaster(rdmaUdpRxTx.dataStreamOutRx);
    let rawAxiStreamRx <- mkPutToRawAxiStreamSlave(rdmaUdpRxTx.axiStreamInRx, CF);

    interface rawUdpConfig = rawConfig;

    interface rawUdpIpMetaDataInTx = rawUdpIpMetaDataTx;
    interface rawDataStreamInTx = rawDataStreamTx;
    interface rawAxiStreamOutTx = rawAxiStreamTx;

    interface rawUdpIpMetaDataOutRx = rawUdpIpMetaDataRx;
    interface rawDataStreamOutRx = rawDataStreamRx;
    interface rawAxiStreamInRx = rawAxiStreamRx;
endmodule












