import PAClib :: *;

import EthernetTypes :: *;

typedef 8 BYTE_WIDTH;
typedef Bit#(BYTE_WIDTH) Byte;
typedef 16 WORD_WIDTH;
typedef Bit#(WORD_WIDTH) Word;

typedef 32 CRC32_WIDTH;
typedef TDiv#(CRC32_WIDTH, BYTE_WIDTH) CRC32_BYTE_WIDTH;
typedef Bit# (CRC32_WIDTH) Crc32Checksum;
typedef TAdd#(CRC32_BYTE_WIDTH, DATA_BUS_BYTE_WIDTH) CRC32_TAB_NUM;
typedef 32'hFFFFFFFF CRC32_FINAL_XOR_VAL;

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


typedef struct {
    UdpLength  dataLen;
    IpAddr     ipAddr;
    UdpPort    dstPort;
    UdpPort    srcPort;
} UdpMetaData deriving(Bits, Bounded, Eq, FShow);
typedef PipeOut#(UdpMetaData) UdpMetaDataPipeOut;

typedef struct {
    EthMacAddr macAddr;
    EthType    ethType;
} MacMetaData deriving(Bits, Eq);
typedef PipeOut#(MacMetaData) MacMetaDataPipeOut;

typedef struct {
    EthMacAddr macAddr;
    IpAddr     ipAddr;
    IpNetMask  netMask;
    IpGateWay  gateWay;
} UdpConfig deriving(Bits, Bounded, Eq, FShow);


typedef 512 AXIS_TDATA_WIDTH;
typedef Bit#(AXIS_TDATA_WIDTH) AxiStreamTData;
typedef TDiv#(AXIS_TDATA_WIDTH, BYTE_WIDTH) AXIS_TKEEP_WIDTH;
typedef Bit#(AXIS_TKEEP_WIDTH) AxiStreamTKeep;
typedef struct{
    AxiStreamTData tData;
    AxiStreamTKeep tKeep;
    Bool tUser;
    Bool tLast;
} AxiStream deriving(Bits, Eq, FShow);

typedef PipeOut#(AxiStream) AxiStreamPipeOut;

//4k Cache
