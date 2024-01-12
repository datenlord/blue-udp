import FIFOF :: *;
import GetPut :: *;
import ClientServer :: *;

import Ports :: *;
import EthUtils :: *;
import ArpCache :: *;
import StreamHandler :: *;
import EthernetTypes :: *;

import SemiFifo :: *;

interface ArpProcessor;
    interface DataStreamPipeOut arpStreamOut;
    interface MacMetaDataPipeOut macMetaDataOut;
    interface Put#(UdpConfig) udpConfig;
endinterface


module mkArpProcessor#(
    DataStreamPipeOut arpStreamIn,
    UdpIpMetaDataPipeOut udpIpMetaDataIn
)(ArpProcessor);
    Reg#(UdpConfig) udpConfigReg <- mkRegU;
    FIFOF#(ArpFrame) arpRespBuf <- mkFIFOF;
    FIFOF#(ArpFrame) arpReqBuf <- mkFIFOF;
    FIFOF#(ArpFrame) arpFrameOutBuf <- mkFIFOF;
    FIFOF#(MacMetaData) arpMacMetaBuf <- mkFIFOF;
    FIFOF#(MacMetaData) macMetaOutBuf <- mkFIFOF;
    FIFOF#(DataStream) paddingOutBuf <- mkFIFOF;

    ArpCache arpCache <- mkArpCache;
    ExtractDataStream#(ArpFrame) arpFrameAndPadding <- mkExtractDataStreamHead(arpStreamIn);
    DataStreamPipeOut arpStream <- mkAppendDataStreamHead(
        HOLD,
        SWAP,
        convertFifoToPipeOut(paddingOutBuf),
        convertFifoToPipeOut(arpFrameOutBuf)
    );

    rule doCacheReq;
        let ipAddr = udpIpMetaDataIn.first.ipAddr;
        udpIpMetaDataIn.deq;
        // check whether host and target are in the same gateway
        if (!isInGateWay(udpConfigReg.netMask, udpConfigReg.ipAddr, ipAddr)) begin
            ipAddr = udpConfigReg.gateWay;
        end
        arpCache.cacheServer.request.put(ipAddr);
    endrule
    
    rule throwPadding;
        arpFrameAndPadding.dataStreamOut.deq;
    endrule

    rule forkArpFrameIn;
        let arpFrame = arpFrameAndPadding.extractDataOut.first;
        arpFrameAndPadding.extractDataOut.deq;
        arpCache.arpClient.response.put(
            ArpResp {
                ipAddr: arpFrame.arpSpa,
                macAddr: arpFrame.arpSha
            }
        );

        // do Arp reply when receiving matched arp req
        let isArpReq = arpFrame.arpOper == fromInteger(valueOf(ARP_OPER_REQ));
        let isIpMatch = arpFrame.arpTpa == udpConfigReg.ipAddr;
        if (isArpReq && isIpMatch) begin
            arpRespBuf.enq(
                ArpFrame{
                    arpHType: fromInteger(valueOf(ARP_HTYPE_ETH)),
                    arpPType: fromInteger(valueOf(ARP_PTYPE_IP)),
                    arpHLen: fromInteger(valueOf(ARP_HLEN_MAC)),
                    arpPLen: fromInteger(valueOf(ARP_PLEN_IP)),
                    arpOper: fromInteger(valueOf(ARP_OPER_REPLY)),
                    arpSha: udpConfigReg.macAddr,
                    arpSpa: udpConfigReg.ipAddr,
                    arpTha: arpFrame.arpSha,
                    arpTpa: arpFrame.arpSpa
                }
            );
        end
        $display("ArpProcessor: receive an arp frame:", fshow(arpFrame));
    endrule

    rule genArpReq;
        let targetIpAddr <- arpCache.arpClient.request.get;
        arpReqBuf.enq(
            ArpFrame{
                arpHType: fromInteger(valueOf(ARP_HTYPE_ETH)),
                arpPType: fromInteger(valueOf(ARP_PTYPE_IP)),
                arpHLen: fromInteger(valueOf(ARP_HLEN_MAC)),
                arpPLen: fromInteger(valueOf(ARP_PLEN_IP)),
                arpOper: fromInteger(valueOf(ARP_OPER_REQ)),
                arpSha: udpConfigReg.macAddr,
                arpSpa: udpConfigReg.ipAddr,
                arpTha: 0,
                arpTpa: targetIpAddr
            }
        );
    endrule

    rule selectArpFrameOut;
        if (arpReqBuf.notEmpty) begin
            arpFrameOutBuf.enq(arpReqBuf.first);
            arpReqBuf.deq;
            arpMacMetaBuf.enq(
                MacMetaData{
                    macAddr: setAllBits,
                    ethType: fromInteger(valueOf(ETH_TYPE_ARP))
                }
            );
            $display("ArpProcessor: broadcast an arpReq: ", fshow(arpReqBuf.first));
        end
        else if (arpRespBuf.notEmpty) begin
            arpFrameOutBuf.enq(arpRespBuf.first);
            arpRespBuf.deq;
            arpMacMetaBuf.enq(
                MacMetaData{
                    macAddr: arpRespBuf.first.arpTha,
                    ethType: fromInteger(valueOf(ETH_TYPE_ARP))
                }
            );
            $display("ArpProcessor: reply an arpReq: ", fshow(arpRespBuf.first));

        end
    endrule

    rule genPadding;
        ByteEn padByteEn = (1 << valueOf(ARP_PAD_BYTE_WIDTH)) - 1;
        paddingOutBuf.enq(
            DataStream{
                data: 0,
                byteEn: padByteEn,
                isFirst: True,
                isLast: True
            }
        );
    endrule

    rule selectMacMetaOut;
        if (arpMacMetaBuf.notEmpty) begin
            macMetaOutBuf.enq(arpMacMetaBuf.first);
            arpMacMetaBuf.deq;
        end
        else begin
            let dstMacAddr <- arpCache.cacheServer.response.get;
            macMetaOutBuf.enq(
                MacMetaData{
                    macAddr: dstMacAddr,
                    ethType: fromInteger(valueOf(ETH_TYPE_IP))
                }
            );
        end
    endrule


    interface PipeOut arpStreamOut = arpStream;
    interface PipeOut macMetaDataOut = convertFifoToPipeOut(macMetaOutBuf);
    interface Put udpConfig;
        method Action put(UdpConfig conf);
            udpConfigReg <= conf;
        endmethod
    endinterface

endmodule