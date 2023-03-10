import PAClib::*;

import EthernetTypes::*;

typedef 8 BYTE_WIDTH;
typedef Bit#(BYTE_WIDTH) Byte;
typedef 16 WORD_WIDTH;
typedef Bit#(WORD_WIDTH) Word;

typedef 256 DATA_BUS_WIDTH;
typedef TDiv#( DATA_BUS_WIDTH, 8 ) DATA_BUS_BYTE_WIDTH;
typedef Bit#( DATA_BUS_WIDTH ) Data;
typedef Bit#( DATA_BUS_BYTE_WIDTH ) ByteEn;
typedef struct {
    Data data;
    ByteEn byteEn;
    Bool isFirst;
    Bool isLast;
} DataStream deriving(Bits, Bounded, Eq, FShow);
typedef PipeOut#(DataStream) DataStreamPipeOut;


typedef struct{
    UdpLength  dataLen;
    EthMacAddr macAddr;
    IpAddr     ipAddr;
    UdpPort    dstPort;
    UdpPort    srcPort;
} MetaData deriving(Bits, Bounded, Eq, FShow);
typedef PipeOut#(MetaData) MetaDataPipeOut;


typedef struct{
    EthMacAddr srcMacAddr;
    IpAddr     srcIpAddr;
} UdpConfig deriving(Bits, Bounded, Eq, FShow);


//4k Cache
