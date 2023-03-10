import EthernetTypes::*;
import Ports::*;

typedef DATA_BUS_WIDTH FRAGMENT_WIDTH;
typedef Bit#(FRAGMENT_WIDTH) Fragment;
typedef TDiv#(TOTAL_HDR_WIDTH, FRAGMENT_WIDTH) FRAGMENT_NUM;
typedef TLog#(FRAGMENT_NUM) FRAGMENT_COUNTER_WIDTH;
typedef Bit#(FRAGMENT_COUNTER_WIDTH) FragmentCounter;

typedef TMul#(FRAGMENT_NUM, FRAGMENT_WIDTH) PRE_FRAGMENT_WIDTH;
typedef  Bit#(PRE_FRAGMENT_WIDTH) PreFragment;
typedef TSub#(PRE_FRAGMENT_WIDTH, TOTAL_HDR_WIDTH) RESIDUE_WIDTH;
typedef TDiv#(RESIDUE_WIDTH, BYTE_WIDTH) RESIDUE_BYTE_WIDTH;
typedef TSub#(FRAGMENT_WIDTH, RESIDUE_WIDTH) UNALIGNMENT_WIDTH;
typedef TDiv#(UNALIGNMENT_WIDTH, BYTE_WIDTH) UNALIGNMENT_BYTE_WIDTH;
typedef  Bit#(RESIDUE_WIDTH) Residue;
typedef  Bit#(RESIDUE_BYTE_WIDTH) ResidueByteEn;
typedef  Bit#(UNALIGNMENT_WIDTH) Unalignment;
typedef  Bit#(UNALIGNMENT_BYTE_WIDTH) UnalignByteEn;
typedef struct{
    Residue residue;
    ResidueByteEn residueByteEn;
    Unalignment unalignData;
    UnalignByteEn unalignByteEn;
} SepDataStream deriving(Bits);
function SepDataStream seperateDataStreamOut(DataStream in);
    return SepDataStream{
        residue: truncate(in.data),
        residueByteEn: truncate(in.byteEn),
        unalignData: truncateLSB(in.data),
        unalignByteEn: truncateLSB(in.byteEn)
    };
endfunction