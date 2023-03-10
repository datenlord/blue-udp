import Vector::*;
import FIFOF::*;
import GetPut::*;
import ClientServer::*;

import Utils::*;
import EthernetTypes::*;
import Ports::*;
import FragmentTypes::*;


function TotalHeader genTotalHeader(MetaData metaData, UdpConfig udpConfig, IpID ipIdCount);

    EthHeader ethHeader = EthHeader{
        dstMacAddr: metaData.macAddr,
        srcMacAddr: udpConfig.srcMacAddr,
        etherType : fromInteger(valueOf(ETH_TYPE_VAL))
    };

    UdpLength udpLen = metaData.dataLen + fromInteger(valueOf(UDP_HDR_BYTE_WIDTH));
    IpTL ipLen = udpLen + fromInteger(valueOf(IP_HDR_BYTE_WIDTH));

    IpHeader ipHeader = IpHeader{
        ipVersion: fromInteger(valueOf(IP_VERSION_VAL)),
        ipIHL:     fromInteger(valueOf(IP_IHL_VAL)),
        ipDS:      fromInteger(valueOf(IP_DS_VAL)),
        ipTL:      ipLen,
        ipID:      ipIdCount,
        ipFlag:    fromInteger(valueOf(IP_FLAGS_VAL)),
        ipOffset:  fromInteger(valueOf(IP_OFFSET_VAL)),
        ipTTL:     fromInteger(valueOf(IP_TTL_VAL)),
        ipProtocol:fromInteger(valueOf(IP_PROTOCOL_VAL)),
        ipChecksum:0,
        srcIpAddr :udpConfig.srcIpAddr,
        dstIpAddr :metaData.ipAddr
    };

    Vector#(IP_HDR_WORD_WIDTH, Word) ipHdrVec = unpack(pack(ipHeader));
    ipHeader.ipChecksum = getCheckSum(ipHdrVec);

    UdpHeader udpHeader = UdpHeader{
        srcPort: metaData.srcPort,
        dstPort: metaData.dstPort,
        length:  udpLen,
        checksum:0
    };

    Vector#(UDP_HDR_WORD_WIDTH, Word) udpHdrVec = unpack(pack(udpHeader));
    udpHeader.checksum = getCheckSum(udpHdrVec);

    TotalHeader totalHeader = TotalHeader{
        ethHeader: ethHeader,
        ipHeader : ipHeader,
        udpHeader: udpHeader
    };
    return totalHeader;
endfunction

typedef Server#(MetaData, DataStream) HeaderGenerator;

module mkHeaderGenerator#(Maybe#(UdpConfig) udpConfig)( HeaderGenerator );
    FIFOF#( MetaData ) metaDataInBuf <- mkFIFOF;
    FIFOF#( DataStream ) metaDataOutBuf <- mkFIFOF;
    Reg#( IpID ) ipIdCounter <- mkReg(0);
    Reg#(FragmentCounter) fragCounter <- mkReg(0);
    FragmentCounter fragCountMax = fromInteger(valueOf(FRAGMENT_NUM) - 1);

    // Generate ethernet header signals
    let totalHdr= genTotalHeader(metaDataInBuf.first, fromMaybe(?,udpConfig),ipIdCounter);

    PreFragment preFragment = zeroExtend(pack(totalHdr));
    Vector#(FRAGMENT_NUM, Fragment) fragmentVec = unpack(preFragment);


    rule doFragment( isValid( udpConfig ) );
        Bool first = (fragCounter == 0);
        Bool last = (fragCounter == fragCountMax);
        FragmentCounter fragCountNext = last ? 0 : fragCounter + 1;
        ByteEn byteEn = 1 << valueOf(DATA_BUS_BYTE_WIDTH) - 1;
        if (last) byteEn = 1 << valueOf(UNALIGNMENT_BYTE_WIDTH) - 1;
        DataStream dataStream = DataStream{
            data: fragmentVec[fragCounter],
            byteEn: byteEn,
            isFirst: first,
            isLast: last
        };
        if (metaDataInBuf.notEmpty) begin
            metaDataOutBuf.enq( dataStream );
            fragCounter <= fragCountNext;
            if( last ) begin
                metaDataInBuf.deq;
                ipIdCounter <= ipIdCounter + 1;
            end
        end

    endrule

    interface Put request  = toPut( metaDataInBuf  );
    interface Get response = toGet( metaDataOutBuf );
endmodule