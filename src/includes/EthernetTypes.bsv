/////////////// Link Layer
typedef 48 ETH_MAC_ADDR_WIDTH;
typedef 16 ETH_TYPE_WIDTH;
typedef 32 ETH_FCS_WIDTH;

typedef Bit#(ETH_MAC_ADDR_WIDTH) EthMacAddr;
typedef Bit#(ETH_TYPE_WIDTH    ) EthType;
typedef Bit#(ETH_FCS_WIDTH     ) EthFcs;
typedef struct{
    EthMacAddr dstMacAddr;
    EthMacAddr srcMacAddr;
    EthType    etherType;
} EthHeader deriving( FShow, Eq, Bounded);

instance Bits#(EthHeader, ETH_HDR_WIDTH );
    function Bit#(ETH_HDR_WIDTH) pack(EthHeader x);
        return {x.etherType, x.srcMacAddr, x.dstMacAddr};
    endfunction

    function EthHeader unpack( Bit#(ETH_HDR_WIDTH) x);
        return EthHeader{ dstMacAddr:x[47:0], srcMacAddr:x[95:48], etherType:x[111:96]};
    endfunction
endinstance

typedef 2048 ETH_TYPE_VAL;   // TYPE = 0x0800


/////////////// IP Layer
typedef 4  IP_VERSION_WIDTH;
typedef 4  IP_IHL_WIDTH;
typedef 8  IP_DS_WIDTH;
typedef 16 IP_TL_WIDTH;
typedef 16 IP_ID_WIDTH;
typedef 3  IP_FLAGS_WIDTH;
typedef 13 IP_OFFSET_WIDTH;
typedef 8  IP_TTL_WIDTH;
typedef 8  IP_PROTOCOL_WIDTH;
typedef 16 IP_CHECKSUM_WIDTH;
typedef 32 IP_ADDR_WIDTH;

typedef Bit#(IP_VERSION_WIDTH ) IpVersion;
typedef Bit#(IP_IHL_WIDTH     ) IpIHL;
typedef Bit#(IP_DS_WIDTH      ) IpDS;
typedef Bit#(IP_TL_WIDTH      ) IpTL;
typedef Bit#(IP_ID_WIDTH      ) IpID;
typedef Bit#(IP_FLAGS_WIDTH   ) IpFlags;
typedef Bit#(IP_OFFSET_WIDTH  ) IpOffset;
typedef Bit#(IP_TTL_WIDTH     ) IpTTL;
typedef Bit#(IP_PROTOCOL_WIDTH) IpProtocol;
typedef Bit#(IP_CHECKSUM_WIDTH) IpCheckSum;
typedef Bit#(IP_ADDR_WIDTH    ) IpAddr;
typedef struct{
    IpVersion  ipVersion;
    IpIHL      ipIHL;
    IpDS       ipDS;
    IpTL       ipTL;
    IpID       ipID;
    IpFlags    ipFlag;
    IpOffset   ipOffset;
    IpTTL      ipTTL;
    IpProtocol ipProtocol;
    IpCheckSum ipChecksum;
    IpAddr     srcIpAddr;
    IpAddr     dstIpAddr;
} IpHeader deriving( FShow, Eq, Bounded);

instance Bits#(IpHeader, IP_HDR_WIDTH);
    function Bit#(IP_HDR_WIDTH) pack(IpHeader x);
        return {
            x.dstIpAddr, x.srcIpAddr, x.ipChecksum, x.ipProtocol, x.ipTTL,
            x.ipOffset, x.ipFlag, x.ipID, x.ipTL, x.ipDS, x.ipIHL, x.ipVersion
        };
    endfunction

    function IpHeader unpack(Bit#(IP_HDR_WIDTH) x);
        return IpHeader{
            ipVersion:x[3:0], ipIHL:x[7:4], ipDS:x[15:8], ipTL:x[31:16], ipID:x[47:32],
            ipFlag:x[50:48], ipOffset:x[63: 51], ipTTL:x[71:64], ipProtocol:x[79:72],
            ipChecksum:x[95:80], srcIpAddr:x[127:96], dstIpAddr:x[159:128]
        };
    endfunction
endinstance

typedef 4  IP_VERSION_VAL;         // VERSION = 0x4
typedef 5  IP_IHL_VAL;             // IHL = 0x5
typedef 0  IP_DS_VAL;              // DS  = 0x0
typedef 2  IP_FLAGS_VAL;           // FLAGS = 0x2
typedef 0  IP_OFFSET_VAL;          // FRAGMENT_OFFSET = 0
typedef 64 IP_TTL_VAL;             // TTL = 0x40
typedef 17 IP_PROTOCOL_VAL;        // PROTOCOL = 0x11(UDP)


//////////////// Transport Layer
typedef 16 UDP_PORT_WIDTH;
typedef 16 UDP_LENGTH_WIDTH;
typedef 16 UDP_CHECKSUM_WIDTH;

typedef Bit#( UDP_PORT_WIDTH     ) UdpPort;
typedef Bit#( UDP_LENGTH_WIDTH   ) UdpLength;
typedef Bit#( UDP_CHECKSUM_WIDTH ) UdpCheckSum;
typedef struct{
    UdpPort     srcPort;
    UdpPort     dstPort;
    UdpLength   length;
    UdpCheckSum checksum;
} UdpHeader deriving( FShow, Eq, Bounded);
instance Bits#(UdpHeader, UDP_HDR_WIDTH);
    function Bit#(UDP_HDR_WIDTH) pack(UdpHeader x);
        return {x.checksum, x.length, x.dstPort, x.srcPort};
    endfunction
    
    function UdpHeader unpack( Bit#(UDP_HDR_WIDTH) x);
        return UdpHeader{ srcPort:x[15:0], dstPort:x[31:16], length:x[47:32], checksum:x[63:48]};
    endfunction
endinstance


//////////////// 
typedef 14 ETH_HDR_BYTE_WIDTH;                 // 14 bytes
typedef TMul#(IP_IHL_VAL,4) IP_HDR_BYTE_WIDTH; // 20 bytes
typedef 8  UDP_HDR_BYTE_WIDTH;                 // 8 bytes

typedef TDiv#(ETH_HDR_BYTE_WIDTH,2) ETH_HDR_WORD_WIDTH; // 7 words
typedef TDiv#(IP_HDR_BYTE_WIDTH ,2) IP_HDR_WORD_WIDTH;  // 10 words
typedef TDiv#(UDP_HDR_BYTE_WIDTH,2) UDP_HDR_WORD_WIDTH; // 4 words

typedef TAdd#(ETH_HDR_BYTE_WIDTH, TAdd#(IP_HDR_BYTE_WIDTH,UDP_HDR_BYTE_WIDTH)) TOTAL_HDR_BYTE_WIDTH;
typedef TMul#(ETH_HDR_BYTE_WIDTH, 8) ETH_HDR_WIDTH;
typedef TMul#(IP_HDR_BYTE_WIDTH,  8) IP_HDR_WIDTH;
typedef TMul#(UDP_HDR_BYTE_WIDTH, 8) UDP_HDR_WIDTH;
typedef TMul#(TOTAL_HDR_BYTE_WIDTH, 8) TOTAL_HDR_WIDTH;

typedef 1500 ETH_DATA_MAX_SIZE;  // The maximum byte-width of payload of Ethnernrt Frame
typedef 46   ETH_DATA_MIN_SIZE;  // The minimum byte-width of payload of Ethnernrt Frame
typedef ETH_DATA_MAX_SIZE IP_MAX_SIZE;
typedef ETH_DATA_MIN_SIZE IP_MIN_SIZE;
typedef TSub#(ETH_DATA_MAX_SIZE, IP_HDR_BYTE_WIDTH) UDP_MAX_SIZE;
typedef TSub#(ETH_DATA_MIN_SIZE, IP_HDR_BYTE_WIDTH) UDP_MIN_SIZE;
typedef TSub#(UDP_MAX_SIZE, UDP_HDR_BYTE_WIDTH) DATA_MAX_SIZE; // 1472 bytes
typedef TSub#(UDP_MIN_SIZE, UDP_HDR_BYTE_WIDTH) DATA_MIN_SIZE; // 18 bytes

typedef struct{
    EthHeader ethHeader;
    IpHeader  ipHeader;
    UdpHeader udpHeader;
} TotalHeader deriving( FShow, Eq, Bounded);

instance Bits#(TotalHeader, TOTAL_HDR_WIDTH);
    function Bit#(TOTAL_HDR_WIDTH) pack(TotalHeader x);
        return { pack(x.udpHeader), pack(x.ipHeader), pack(x.ethHeader) };
    endfunction
    
    function TotalHeader unpack( Bit#(TOTAL_HDR_WIDTH) x);
        return TotalHeader{
            ethHeader: unpack(x[111:0]),
            ipHeader:  unpack(x[271:112]),
            udpHeader: unpack(x[335:272])
        };
    endfunction
endinstance

