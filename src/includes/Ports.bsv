import Vector :: *;

import EthernetTypes :: *;

import SemiFifo :: *;
import AxiStreamTypes :: *;

typedef 8 BYTE_WIDTH;
typedef Bit#(BYTE_WIDTH) Byte;
typedef 16 WORD_WIDTH;
typedef Bit#(WORD_WIDTH) Word;

typedef 32 CRC32_WIDTH;
typedef TDiv#(CRC32_WIDTH, BYTE_WIDTH) CRC32_BYTE_WIDTH;
typedef Bit#(CRC32_WIDTH) Crc32Checksum;

typedef 512 DATA_BUS_WIDTH;
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
typedef FifoOut#(DataStream) DataStreamFifoOut;

typedef struct {
    UdpLength  dataLen;
    IpAddr     ipAddr;
    IpDscp     ipDscp;
    IpEcn      ipEcn;
    UdpPort    dstPort;
    UdpPort    srcPort;
} UdpIpMetaData deriving(Bits, Bounded, Eq, FShow);
typedef FifoOut#(UdpIpMetaData) UdpIpMetaDataFifoOut;

typedef struct {
    EthMacAddr macAddr;
    EthType    ethType;
} MacMetaData deriving(Bits, Eq, FShow);
typedef FifoOut#(MacMetaData) MacMetaDataFifoOut;

typedef struct {
    MacMetaData macMetaData;
    Bool isBypass;
} MacMetaDataWithBypassTag deriving(Bits, Eq, FShow);

typedef struct {
    EthMacAddr macAddr;
    IpAddr     ipAddr;
    IpNetMask  netMask;
    IpGateWay  gateWay;
} UdpConfig deriving(Bits, Bounded, Eq, FShow);
typedef FifoOut#(UdpConfig) UdpConfigFifoOut;

typedef enum {
    FLOW_CTRL_STOP,
    FLOW_CTRL_PASS
} FlowControlRequest deriving(Bits, Eq, FShow);

typedef Vector#(VIRTUAL_CHANNEL_NUM, Maybe#(FlowControlRequest)) FlowControlReqVec;
typedef SizeOf#(FlowControlReqVec) FlowCtrlReqVecWidth;


typedef 512 AXIS512_TDATA_WIDTH;
typedef 64  AXIS512_TKEEP_WIDTH;
typedef 256 AXIS256_TDATA_WIDTH;
typedef 32  AXIS256_TKEEP_WIDTH;
typedef 1   AXIS_TUSER_WIDTH;

typedef AxiStream#(AXIS512_TKEEP_WIDTH, AXIS_TUSER_WIDTH) AxiStream512;
typedef AxiStream#(AXIS256_TKEEP_WIDTH, AXIS_TUSER_WIDTH) AxiStream256;
typedef FifoOut#(AxiStream256) AxiStream256FifoOut;
typedef FifoOut#(AxiStream512) AxiStream512FifoOut;
typedef FifoIn#(AxiStream256) AxiStream256FifoIn;
typedef FifoIn#(AxiStream512) AxiStream512FifoIn;

typedef RawAxiStreamSlaveToGet#(AXIS512_TKEEP_WIDTH, AXIS_TUSER_WIDTH) RawAxiStreamSlaveToGet512;


//4k Cache
