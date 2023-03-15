import GetPut::*;
import FIFOF::*;
import PAClib::*;
import Vector::*;
import CompletionBuffer::*;

import EthernetTypes::*;

// ARP request/response

// 4-way set-associative non-blocking LRU
//
// Cache Size
// Ip Addr:32-bit/4-bytes Mac Addr:48-bit/6-bytes)
// exp(2+8)*(3 bytes + 6 bytes) = 9 KB

// replacement
// replcae Vector Reg
// Integrate


typedef 2 CACHE_WAY_INDEX_WIDTH;
typedef TExp#(CACHE_WAY_INDEX_WIDTH) CACHE_WAY_NUM;
typedef 6 CACHE_INDEX_WIDTH;
typedef TExp#(CACHE_INDEX_WIDTH) CACHE_ROW_NUM;
typedef ETH_MAC_ADDR_WIDTH CACHE_DATA_WIDTH;
typedef IP_ADDR_WIDTH CACHE_ADDR_WIDTH;
typedef TSub#(CACHE_ADDR_WIDTH, CACHE_INDEX_WIDTH) CACHE_TAG_WIDTH;
typedef TSub#(CACHE_WAY_NUM, 1) CACHE_AGE_WIDTH; // used in pseduo LRU

typedef Bit#(CACHE_DATA_WIDTH) CacheData;
typedef Bit#(CACHE_ADDR_WIDTH) CacheAddr;
typedef Bit#(CACHE_TAG_WIDTH) CacheTag;
typedef Bit#(CACHE_INDEX_WIDTH) CacheIndex;
typedef Bit#(CACHE_WAY_INDEX_WIDTH) CacheWayIndex;

typedef Vector#(CACHE_ROW_NUM, Reg#(CacheData)) CacheDataCol;
typedef Vector#(CACHE_ROW_NUM, Reg#(Maybe#(CacheTag))) CacheTagCol;
typedef Vector#(CACHE_AGE_WIDTH, Reg#(Bool)) CacheAgeCol;

typedef Vector#(CACHE_WAY_NUM, CacheDataCol) CacheDataArray;
typedef Vector#(CACHE_WAY_NUM, CacheTagCol) CacheTagArray;
typedef Vector#(CACHE_ROW_NUM, CacheAgeCol) CacheAgeArray;

//
typedef 8 CBUF_SIZE;
typedef 8 FILLQ_SIZE;

// Useful Functions
function CacheTag getTag(CacheAddr addr);
    return truncateLSB(addr);
endfunction

function CacheIndex getIndex(CacheAddr addr);
    return truncate(addr);
endfunction

function Maybe#(CacheWayIndex) getHitWayIdx(CacheAddr addr, CacheTagArray tagArray);
    let tag = getTag(addr);
    let index = getIndex(addr);
    Maybe#(CacheWayIndex) wayIdx = tagged Invalid;
    for(Integer i=0; i < valueOf(CACHE_WAY_NUM); i=i+1) begin
        if(tagArray[i][index] matches tagged Valid .x &&& x == tag) begin
            wayIdx = tagged Valid fromInteger(i);
        end
    end
    return wayIdx;
endfunction

// function CacheData getCacheData(CacheData addr, CacheTagArray tagArray, CacheDataArray dataArray);
//     let tag = getTag(addr);
//     let index = getIndex(addr);
//     let CacheData data;
//     for(Integer i = 0; i < valueOf(CACHE_WAY_NUM); i = i+1) begin
//         if(tagArray[i][index] matches tagged Valid .x && x == tag) begin
//             data = dataArray[i][index];
//         end
//     end
//     return data;
// endfunction

function CacheWayIndex getReplaceWayIdx(CacheAgeCol ageCol);
    CacheWayIndex wayIdx;
    Bit#(TLog#(CACHE_AGE_WIDTH)) ageIdx = 0;
    for(Integer i=0; i < valueOf(CACHE_WAY_INDEX_WIDTH); i=i+1) begin
        wayIdx[i] = pack(ageCol[ageIdx]);
        if (ageIdx == 0) ageIdx = (ageIdx << 1) + 1;
        else ageIdx = (ageIdx << 1) + 2;
    end
    return wayIdx;
endfunction

function Action setCacheAge(CacheAgeCol ageCol, CacheWayIndex wayIdx);
    action
        Bit#(TLog#(CACHE_AGE_WIDTH)) ageIdx = 0;
        for(Integer i=0; i < valueOf(CACHE_WAY_INDEX_WIDTH); i=i+1) begin
            if (wayIdx[i] == 0) begin
                ageCol[ageIdx] <= True;
                ageIdx = (ageIdx << 1) + 1;
            end
            else begin
                ageCol[ageIdx] <= False;
                ageIdx = (ageIdx << 1) + 2;
            end
        end
    endaction
endfunction

typedef struct{
    IpAddr ipAddr;
    EthMacAddr macAddr;
} ArpResp deriving(Bits, Eq, FShow);

interface ArpCache;
    interface Put#(CacheAddr) req;
    interface PipeOut#(CacheData) resp;
    interface Put#(ArpResp) arpResp;
    interface PipeOut#(CacheAddr) arpReq;
endinterface

module mkArpCache(ArpCache);
    // state elements
    CacheDataArray dataArray <- replicateM(replicateM(mkRegU));
    CacheTagArray tagArray <- replicateM(replicateM(mkReg(Invalid)));
    CacheAgeArray ageArray <- replicateM(replicateM(mkReg(False)));
    
    CompletionBuffer#(CBUF_SIZE, CacheData) respCBuf <- mkCompletionBuffer;

    FIFOF#(Tuple2#(CBToken#(CBUF_SIZE), CacheAddr)) fillQ <- mkSizedFIFOF(valueOf(FILLQ_SIZE));

    FIFOF#(CacheData) respBuf <- mkFIFOF;
    //FIFOF#(CacheAddr) reqBuf <- mkFIFOF;
    FIFOF#(ArpResp) arpRespBuf <- mkFIFOF;
    FIFOF#(CacheAddr) arpReqBuf <- mkFIFOF;
    

    rule deFillQ;
        match {.token, .addr} = fillQ.first;
        if (fillQ.notEmpty) begin
            let cacheIdx = getIndex(addr);
            let hitWayIdx = getHitWayIdx(addr, tagArray);
            if (hitWayIdx matches tagged Valid .wayIdx) begin
                let cacheData = dataArray[wayIdx][cacheIdx];
                fillQ.deq;
                respCBuf.complete.put(tuple2(token, cacheData));
                setCacheAge(ageArray[cacheIdx], wayIdx);
            end
        end
    endrule

    rule doArpResp;
        let arpResp = arpRespBuf.first; arpRespBuf.deq;
        let cacheIdx = getIndex(arpResp.ipAddr);
        let cacheTag = getTag(arpResp.ipAddr);
        let cacheData = arpResp.macAddr;
        let repWayIdx = getReplaceWayIdx(ageArray[cacheIdx]);
        dataArray[repWayIdx][cacheIdx] <= cacheData;
        tagArray[repWayIdx][cacheIdx] <= tagged Valid cacheTag;
    endrule

    rule doResp;
        let respData <- respCBuf.drain.get;
        respBuf.enq(respData);
    endrule

    interface Put req;
        method Action put(CacheAddr addr);
            let token <- respCBuf.reserve.get;
            let cacheIdx = getIndex(addr);
            let hitWayIdx = getHitWayIdx(addr, tagArray);
            if (hitWayIdx matches tagged Valid .wayIdx ) begin
                let cacheData = dataArray[wayIdx][cacheIdx];
                respCBuf.complete.put(tuple2(token, cacheData));
                setCacheAge(ageArray[cacheIdx], wayIdx);
            end
            else begin
                fillQ.enq(tuple2(token, addr));
                arpReqBuf.enq(addr);
            end
        endmethod
    endinterface

    interface PipeOut resp = f_FIFOF_to_PipeOut(respBuf);
    interface Put arpResp  = toPut(arpRespBuf);
    interface PipeOut arpReq = f_FIFOF_to_PipeOut(arpReqBuf);

endmodule


