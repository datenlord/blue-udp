import GetPut :: *;
import FIFOF :: *;
import Vector :: *;
import ClientServer :: *;

import RFile :: *;
import Utils :: *;
import CompletionBuf :: *;
import EthernetTypes :: *;
import ContentAddressMem :: *;

import SemiFifo :: *;

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

typedef RFileBram#(CacheIndex, CacheData) CacheDataWay;
typedef Vector#(CACHE_WAY_NUM, CacheDataWay) CacheDataSet;

typedef RFileBram#(CacheIndex, Maybe#(CacheTag)) CacheTagWay;
typedef Vector#(CACHE_WAY_NUM, CacheTagWay) CacheTagSet;

typedef RFile#(CACHE_INDEX_WIDTH, CacheAge) CacheAgeWay;

//
typedef 4 CACHE_CBUF_SIZE;
typedef 4 CACHE_MAX_MISS;

// Useful Functions
function CacheTag getTag(CacheAddr addr);
    return truncateLSB(addr);
endfunction

function CacheIndex getIndex(CacheAddr addr);
    return truncate(addr);
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


typedef struct {
    IpAddr ipAddr;
    EthMacAddr macAddr;
} ArpResp deriving(Bits, Eq, FShow);

typedef struct {
    Maybe#(CacheWayIndex) wayIdx;
    CacheData data;
    CacheAddr addr;
} CheckTagResult deriving(Bits, Eq, FShow);

typedef struct {
    CacheIndex cacheIdx;
    CacheWayIndex cacheWayIdx;
    CacheTag   cacheTag;
    CacheData  cacheData;
} CacheWriteResult deriving(Bits, Eq, FShow);

typedef struct {
    CacheAddr cacheAddr;
    CacheData cacheData;
    CacheWayIndex cacheWayIdx;
} MissTabSearchReq deriving(Bits, Eq, FShow);

typedef struct {
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
    
    CacheDataSet dataSet <- replicateM(mkRFileBram);
    CacheTagSet  tagSet <- replicateM(mkRFileBram);
    CacheAgeWay  ageWay <- mkCFRFileInit(0);

    ContentAddressMem#(
        CACHE_MAX_MISS, CacheAddr, CBufIndex#(CACHE_CBUF_SIZE)
    ) missReqTable <- mkContentAddressMem;

    FIFOF#(CacheAddr) cacheReqBuf <- mkFIFOF;
    FIFOF#(CacheAddr) cacheRdBuf <- mkFIFOF;
    FIFOF#(CheckTagResult) checkTagResBuf <- mkFIFOF;
    FIFOF#(CacheWriteResult) cacheWrBuf <- mkFIFOF;
    FIFOF#(HitMessage) hitBuf <- mkFIFOF;
    FIFOF#(HitMessage) missHitBuf <- mkFIFOF;
    FIFOF#(ArpResp) arpRespBuf <- mkFIFOF;
    FIFOF#(MissTabSearchReq) missTabSearchReqBuf <- mkFIFOF;
    FIFOF#(CacheAddr) arpReqBuf <- mkFIFOF;

    CompletionBuf#(CACHE_CBUF_SIZE, CacheData) respCBuf <- mkCompletionBuf;

    rule sendTagAndDataReadReq;
        let addr = cacheReqBuf.first;
        cacheReqBuf.deq;
        for (Integer i = 0; i < valueOf(CACHE_WAY_NUM); i = i + 1) begin
            let index = getIndex(addr);
            dataSet[i].readServer.request.put(index);
            tagSet[i].readServer.request.put(index);
        end
        cacheRdBuf.enq(addr);
    endrule

    rule recvTagAndDataReadResp;
        let addr = cacheRdBuf.first;
        cacheRdBuf.deq;
        let tag = getTag(addr);
        Maybe#(CacheWayIndex) wayIdx = tagged Invalid;
        CacheData data = 0;

        for (Integer i = 0; i < valueOf(CACHE_WAY_NUM); i = i + 1) begin
            let cacheTag <- tagSet[i].readServer.response.get();
            let cacheData <- dataSet[i].readServer.response.get();
            if (cacheTag matches tagged Valid .x &&& x == tag) begin
                wayIdx = tagged Valid fromInteger(i);
                data = cacheData;
            end
        end

        let checkTagRes = CheckTagResult {
            wayIdx: wayIdx,
            data: data,
            addr: addr
        };
        checkTagResBuf.enq(checkTagRes);
    endrule

    rule doCheckTagResult;
        let checkTagRes = checkTagResBuf.first;
        checkTagResBuf.deq;

        let token <- respCBuf.reserve();
        let addr = checkTagRes.addr;
        let data = checkTagRes.data;

        if (checkTagRes.wayIdx matches tagged Valid .wayIdx) begin
            let cacheIdx = getIndex(addr);
            hitBuf.enq(
                HitMessage{
                    token: token,
                    data: data,
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
    endrule

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
        let arpResp = arpRespBuf.first; 
        arpRespBuf.deq;
        let cacheIdx = getIndex(arpResp.ipAddr);
        let cacheTag = getTag(arpResp.ipAddr);
        let cacheData = arpResp.macAddr;
        let repWayIdx = getReplaceWayIdx(ageWay.rd(cacheIdx));

        CacheWriteResult wrRes = CacheWriteResult {
            cacheIdx: cacheIdx,
            cacheWayIdx: repWayIdx,
            cacheTag: cacheTag,
            cacheData: cacheData
        };
        cacheWrBuf.enq(wrRes);

        missTabSearchReqBuf.enq(
            MissTabSearchReq {
                cacheAddr: arpResp.ipAddr,
                cacheData: cacheData,
                cacheWayIdx: repWayIdx
            }
        );
        $display("ArpCache: get arp reponse: addr=%x data=%x", arpResp.ipAddr, arpResp.macAddr);
    endrule

    rule doSearchMissTab;
        let searchReq = missTabSearchReqBuf.first;
        missTabSearchReqBuf.deq;
        
        let cacheAddr = searchReq.cacheAddr;
        let cacheIdx = getIndex(cacheAddr);
        let cacheData = searchReq.cacheData;
        let repWayIdx = searchReq.cacheWayIdx;
        if (missReqTable.search(cacheAddr)) begin
            let token = fromMaybe(?, missReqTable.read(cacheAddr));
            missReqTable.clear(cacheAddr);
            missHitBuf.enq(
                HitMessage{
                    token: token,
                    data: cacheData,
                    index: cacheIdx,
                    wayIndex: repWayIdx
                }
            );
        end
    endrule

    rule writeCache;
        let wrRes = cacheWrBuf.first;
        cacheWrBuf.deq;
        dataSet[wrRes.cacheWayIdx].write(wrRes.cacheIdx, wrRes.cacheData);
        tagSet[wrRes.cacheWayIdx].write(wrRes.cacheIdx, tagged Valid wrRes.cacheTag);
    endrule

    interface Server cacheServer;
        interface Put request = toPut(cacheReqBuf);
        interface Get response = toGet(respCBuf);
    endinterface

    interface Client arpClient;
        interface Get request = toGet(arpReqBuf);
        interface Put response = toPut(arpRespBuf);
    endinterface
endmodule




