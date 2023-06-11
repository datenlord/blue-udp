import SemiFifo :: *;
import EthernetTypes :: *;
import AxiStreamTypes :: *;

typedef 8 BYTE_WIDTH;
typedef Bit#(BYTE_WIDTH) Byte;
typedef 16 WORD_WIDTH;
typedef Bit#(WORD_WIDTH) Word;

typedef 32 CRC32_WIDTH;
typedef TDiv#(CRC32_WIDTH, BYTE_WIDTH) CRC32_BYTE_WIDTH;
typedef Bit#(CRC32_WIDTH) Crc32Checksum;

typedef 256 DATA_BUS_WIDTH;
typedef TDiv#(DATA_BUS_WIDTH, 8) DATA_BUS_BYTE_WIDTH;
typedef Bit#(DATA_BUS_WIDTH) Data;
typedef Bit#(DATA_BUS_BYTE_WIDTH) ByteEn;
typedef Bit#(TLog#(TAdd#(DATA_BUS_WIDTH, 1))) DataShiftAmt;
typedef Bit#(TLog#(TAdd#(DATA_BUS_BYTE_WIDTH, 1))) DataByteShiftAmt;

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
} UdpIpMetaData deriving(Bits, Bounded, Eq, FShow);
typedef PipeOut#(UdpIpMetaData) UdpIpMetaDataPipeOut;

typedef struct {
    EthMacAddr macAddr;
    EthType    ethType;
} MacMetaData deriving(Bits, Eq, FShow);
typedef PipeOut#(MacMetaData) MacMetaDataPipeOut;

typedef struct {
    EthMacAddr macAddr;
    IpAddr     ipAddr;
    IpNetMask  netMask;
    IpGateWay  gateWay;
} UdpConfig deriving(Bits, Bounded, Eq, FShow);
typedef PipeOut#(UdpConfig) UdpConfigPipeOut;


typedef 512 AXIS_TDATA_WIDTH;
typedef TDiv#(AXIS_TDATA_WIDTH, BYTE_WIDTH) AXIS_TKEEP_WIDTH;
typedef 1 AXIS_TUSER_WIDTH;

typedef AxiStream#(AXIS_TKEEP_WIDTH, AXIS_TUSER_WIDTH) AxiStream512;
typedef PipeOut#(AxiStream512) AxiStream512PipeOut;

//4k Cache
