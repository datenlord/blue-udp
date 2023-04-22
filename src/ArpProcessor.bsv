import PAClib :: *;
import FIFOF :: *;
import GetPut :: *;
import ClientServer :: *;

import Ports :: *;
import Utils :: *;
import EthernetTypes :: *;
import ArpCache :: *;

interface ArpProcessor;
    interface DataStreamPipeOut arpStreamOut;
    interface MacMetaDataPipeOut macMetaDataOut;
endinterface


module mkArpProcessor#(
    DataStreamPipeOut arpStreamIn,
    UdpMetaDataPipeOut metaDataIn,
    UdpConfig udpConfig
)(ArpProcessor);
    FIFOF#(ArpFrame) arpReplyBuf <- mkFIFOF;
    FIFOF#(ArpFrame) arpReqBuf <- mkFIFOF;
    FIFOF#(ArpFrame) arpFrameOutBuf <- mkFIFOF;
    FIFOF#(MacMetaData) arpMacMetaBuf <- mkFIFOF;
    FIFOF#(MacMetaData) macMetaOutBuf <- mkFIFOF;
    FIFOF#(DataStream) paddingOutBuf <- mkFIFOF;

    ArpCache arpCache <- mkArpCache;
    DataStreamExtract#(ArpFrame) arpExtractor <- mkDataStreamExtract(arpStreamIn);
    DataStreamPipeOut arpGenerator <- mkDataStreamInsert(
        f_FIFOF_to_PipeOut(paddingOutBuf),
        f_FIFOF_to_PipeOut(arpFrameOutBuf)
    );

    rule doCacheReq;
        let ipAddr = metaDataIn.first.ipAddr;
        metaDataIn.deq;
        // check whether host and target are in the same gateway
        if( !isInGateWay(udpConfig.netMask, udpConfig.ipAddr, ipAddr)) begin
            ipAddr = udpConfig.gateWay;
        end
        arpCache.cacheServer.request.put(ipAddr);
    endrule
    
    rule throwPadding;
        arpExtractor.dataStreamOut.deq;
    endrule

    rule forkArpFrameIn;
        let arpFrame = arpExtractor.extractDataOut.first;
        arpExtractor.extractDataOut.deq;
        arpCache.arpClient.response.put(
            ArpResp{
                ipAddr: arpFrame.arpSpa,
                macAddr: arpFrame.arpSha
            }
        );

        // do Arp reply when receiving matched arp req
        let isArpReq = arpFrame.arpOper == fromInteger(valueOf(ARP_OPER_REQ));
        let isIpMatch = arpFrame.arpTpa == udpConfig.ipAddr;
        if (isArpReq && isIpMatch) begin
            arpReplyBuf.enq(
                ArpFrame{
                    arpHType: fromInteger(valueOf(ARP_HTYPE_ETH)),
                    arpPType: fromInteger(valueOf(ARP_PTYPE_IP)),
                    arpHLen: fromInteger(valueOf(ARP_HLEN_MAC)),
                    arpPLen: fromInteger(valueOf(ARP_PLEN_IP)),
                    arpOper: fromInteger(valueOf(ARP_OPER_REPLY)),
                    arpSha: udpConfig.macAddr,
                    arpSpa: udpConfig.ipAddr,
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
                arpSha: udpConfig.macAddr,
                arpSpa: udpConfig.ipAddr,
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
        else if (arpReplyBuf.notEmpty) begin
            arpFrameOutBuf.enq(arpReplyBuf.first);
            arpReplyBuf.deq;
            arpMacMetaBuf.enq(
                MacMetaData{
                    macAddr: arpReplyBuf.first.arpTha,
                    ethType: fromInteger(valueOf(ETH_TYPE_ARP))
                }
            );
            $display("ArpProcessor: reply an arpReq: ", fshow(arpReplyBuf.first));

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


    interface PipeOut arpStreamOut = arpGenerator;
    interface PipeOut macMetaDataOut = f_FIFOF_to_PipeOut(macMetaOutBuf);

endmodule