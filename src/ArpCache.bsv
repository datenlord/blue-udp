import GetPut :: *;
import FIFOF :: *;
import Vector :: *;
import ClientServer :: *;

import SemiFifo :: *;
import CompletionBuf :: *;
import EthernetTypes :: *;
import RFile :: *;
import ContentAddressMem :: *;

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
typedef Bit#(CACHE_AGE_WIDTH) CacheAge;
typedef Bit#(CACHE_INDEX_WIDTH) CacheIndex;
typedef Bit#(CACHE_WAY_INDEX_WIDTH) CacheWayIndex;

typedef RFile#(CACHE_INDEX_WIDTH, CacheData) CacheDataWay;
typedef Vector#(CACHE_WAY_NUM, CacheDataWay) CacheDataSet;

typedef RFile#(CACHE_INDEX_WIDTH, Maybe#(CacheTag)) CacheTagWay;
typedef Vector#(CACHE_WAY_NUM, CacheTagWay) CacheTagSet;

typedef RFile#(CACHE_INDEX_WIDTH, CacheAge) CacheAgeWay;

//
typedef 8 CACHE_CBUF_SIZE;
typedef 8 CACHE_MAX_MISS;

// Useful Functions
function CacheTag getTag(CacheAddr addr);
    return truncateLSB(addr);
endfunction

function CacheIndex getIndex(CacheAddr addr);
    return truncate(addr);
endfunction

function Maybe#(CacheWayIndex) getHitWayIdx(CacheAddr addr, CacheTagSet tagSet);
    let tag = getTag(addr);
    let index = getIndex(addr);
    Maybe#(CacheWayIndex) wayIdx = tagged Invalid;
    for (Integer i = 0; i < valueOf(CACHE_WAY_NUM); i = i + 1) begin
        if (tagSet[i].rd(index) matches tagged Valid .x &&& x == tag) begin
            wayIdx = tagged Valid fromInteger(i);
        end
    end
    return wayIdx;
endfunction

function CacheWayIndex getReplaceWayIdx(CacheAge age);
    CacheWayIndex wayIdx = 0;
    Bit#(TLog#(CACHE_AGE_WIDTH)) ageIdx = 0;
    for (Integer i = 0; i < valueOf(CACHE_WAY_INDEX_WIDTH); i = i + 1) begin
        wayIdx[i] = age[ageIdx];
        if (wayIdx[i] == 0) begin 
            ageIdx = (ageIdx << 1) + 1;
        end
        else begin 
            ageIdx = (ageIdx << 1) + 2;
        end
    end
    return wayIdx;
endfunction

function Action setCacheAge(CacheIndex idx, CacheAgeWay age, CacheWayIndex wayIdx);
    action
        Bit#(TLog#(CACHE_AGE_WIDTH)) ageIdx = 0;
        CacheAge nextAge = age.rd(idx);
        for (Integer i = 0; i < valueOf(CACHE_WAY_INDEX_WIDTH); i = i + 1) begin
            if (wayIdx[i] == 0) begin
                nextAge[ageIdx] = 1;
                ageIdx = (ageIdx << 1) + 1;
            end
            else begin
                nextAge[ageIdx] = 0;
                ageIdx = (ageIdx << 1) + 2;
            end
        end
        age.wr(idx, nextAge);
    endaction
endfunction


typedef struct{
    IpAddr ipAddr;
    EthMacAddr macAddr;
} ArpResp deriving(Bits, Eq, FShow);

typedef struct{
    CBufIndex#(CACHE_CBUF_SIZE) token;
    CacheData data;
    CacheIndex index;
    CacheWayIndex wayIndex;
} HitMessage deriving(Bits, Eq, FShow);

interface ArpCache;
    interface Server#(CacheAddr, CacheData) cacheServer;
    interface Client#(CacheAddr,   ArpResp) arpClient;
endinterface

module mkArpCache(ArpCache);
    
    CacheDataSet dataSet <- replicateM(mkCFRFile);
    CacheTagSet  tagSet <- replicateM(mkCFRFile);
    CacheAgeWay  ageWay <- mkCFRFileInit(0);

    ContentAddressMem#(
        CACHE_MAX_MISS, CacheAddr, CBufIndex#(CACHE_CBUF_SIZE)
    ) missReqTable <- mkContentAddressMem;

    FIFOF#(HitMessage) hitBuf <- mkFIFOF;
    FIFOF#(HitMessage) missHitBuf <- mkFIFOF;
    FIFOF#(ArpResp) arpRespBuf <- mkFIFOF;
    FIFOF#(CacheAddr) arpReqBuf <- mkFIFOF;

    CompletionBuf#(CACHE_CBUF_SIZE, CacheData) respCBuf <- mkCompletionBuf;


    rule doRespCBuf;
        if (missHitBuf.notEmpty) begin
            let hitInfo = missHitBuf.first;
            missHitBuf.deq;
            respCBuf.complete(tuple2(hitInfo.token, hitInfo.data));
            setCacheAge(hitInfo.index, ageWay, hitInfo.wayIndex);
            $display("ArpCache: MissQHit enter respCBuf: addr=%x data=%x", hitInfo.index, hitInfo.data);
        end
        else if (hitBuf.notEmpty) begin
            let hitInfo = hitBuf.first;
            hitBuf.deq;
            respCBuf.complete(tuple2(hitInfo.token, hitInfo.data));
            setCacheAge(hitInfo.index, ageWay, hitInfo.wayIndex);
            $display("ArpCache: HitBuf enter respCBuf: addr=%x data=%x", hitInfo.index, hitInfo.data);
        end
    endrule

    rule doArpResp;
        let arpResp  = arpRespBuf.first; 
        arpRespBuf.deq;
        let cacheIdx = getIndex(arpResp.ipAddr);
        let cacheTag = getTag(arpResp.ipAddr);
        let cacheData = arpResp.macAddr;
        let repWayIdx = getReplaceWayIdx(ageWay.rd(cacheIdx));
        dataSet[repWayIdx].wr(cacheIdx, cacheData);
        tagSet[repWayIdx].wr(cacheIdx, tagged Valid cacheTag);

        if (missReqTable.search(arpResp.ipAddr)) begin
            let token = fromMaybe(?, missReqTable.read(arpResp.ipAddr));
            missReqTable.clear(arpResp.ipAddr);
            missHitBuf.enq(
                HitMessage{
                    token: token,
                    data: cacheData,
                    index: cacheIdx,
                    wayIndex: repWayIdx
                }
            );
        end
        $display("ArpCache: get arp reponse: addr=%x data=%x", arpResp.ipAddr, arpResp.macAddr);
    endrule

    interface Server cacheServer;
        interface Put request;
            method Action put(CacheAddr addr);
                let token <- respCBuf.reserve;
                let cacheIdx = getIndex(addr);
                let hitWayIdx = getHitWayIdx(addr, tagSet);
                if (hitWayIdx matches tagged Valid .wayIdx) begin
                    let cacheData = dataSet[wayIdx].rd(cacheIdx);
                    hitBuf.enq(
                        HitMessage{
                            token: token,
                            data: cacheData,
                            index: cacheIdx,
                            wayIndex: wayIdx
                        }
                    );
                    $display("ArpCache: Hit Directly: addr=%x", addr);
                end
                else begin
                    missReqTable.write(addr, token);
                    arpReqBuf.enq(addr);
                    $display("ArpCache: Miss: addr=%x", addr);
                end
            endmethod
        endinterface

        interface Get response = toGet(respCBuf);
    endinterface

    interface Client arpClient;
        interface Get request = toGet(arpReqBuf);
        interface Put response = toPut(arpRespBuf);
    endinterface
endmodule




