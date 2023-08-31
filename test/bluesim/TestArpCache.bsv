import FIFOF :: *;
import Randomizable :: *;
import Connectable :: *;
import Vector :: *;
import ClientServer :: *;
import GetPut :: *;

import SemiFifo :: *;
import ArpCache :: *;
import TestUtils :: *;

typedef 9 SIM_MEM_ADDR_WIDTH;
typedef TExp#(SIM_MEM_ADDR_WIDTH) SIM_MEM_SIZE;
typedef Bit#(SIM_MEM_ADDR_WIDTH) SimMemAddr;
typedef 16 SIM_MEM_DATA_WIDTH;
typedef Bit#(SIM_MEM_DATA_WIDTH) SimMemData;

// MemServer with random response delay and order
typedef 8 MAX_SERVER_DELAY;
typedef 8 REORDER_BUF_SIZE;

interface RandomArpMem;
    method CacheData getRefResp(CacheAddr addr);
    interface Server#(CacheAddr, ArpResp) memServer;
endinterface

module mkRandomArpMem(RandomArpMem);
    Reg#(Bool) randInit <- mkReg(False);
    Reg#(Bool) memInit <- mkReg(False);
    Vector#(SIM_MEM_SIZE, Randomize#(SimMemData)) memDataRand <- replicateM(mkGenericRandomizer);
    Randomize#(Bool) selectRand <- mkGenericRandomizer;
    Vector#(SIM_MEM_SIZE, Reg#(SimMemData)) simMem <- replicateM(mkRegU);
    FIFOF#(ArpResp) inputBuf <- mkFIFOF;
    FIFOF#(ArpResp) reorderBuf <- mkSizedFIFOF(valueOf(REORDER_BUF_SIZE));
    RandomDelay#(ArpResp, MAX_SERVER_DELAY) randDelay <- mkRandomDelay;

    rule doRandInit if (!randInit);
        for (Integer i = 0; i < valueOf(SIM_MEM_SIZE); i = i + 1) begin
            memDataRand[i].cntrl.init;
        end
        selectRand.cntrl.init;
        $display("Init Randomizer");
        randInit <= True;
    endrule

    rule doMemInit if (randInit && !memInit);
        for (Integer i = 0; i < valueOf(SIM_MEM_SIZE); i = i + 1) begin
            let memData <- memDataRand[i].next;
            simMem[i] <= memData;
            $display("Init Sim Addr:%x Data:%x", i, memData);
        end
        memInit <= True;
        $display("Init SimMem Finish");
    endrule

    rule doReorder;
        let select <- selectRand.next;
        if (select) begin
            if (inputBuf.notEmpty) begin
                let arpResp = inputBuf.first;
                inputBuf.deq;
                randDelay.request.put(arpResp);
                $display("SimMem Resp: addr=%x data=%x", arpResp.ipAddr, arpResp.macAddr);
            end

            if (reorderBuf.notEmpty) begin
                let arpResp = reorderBuf.first;
                reorderBuf.deq;
                reorderBuf.enq(arpResp);
            end
        end
        else begin
            if (inputBuf.notEmpty) begin
                let arpResp = inputBuf.first;
                inputBuf.deq;
                reorderBuf.enq(arpResp);
            end

            if (reorderBuf.notEmpty) begin
                let arpResp = reorderBuf.first;
                reorderBuf.deq;
                randDelay.request.put(arpResp);
                $display("SimMem Resp: addr=%x data=%x", arpResp.ipAddr, arpResp.macAddr);
            end
        end

    endrule

    method CacheData getRefResp(CacheAddr addr) if (memInit);
        SimMemAddr simAddr = truncate(addr);
        return zeroExtend(simMem[simAddr]);
    endmethod

    interface Server memServer;
        interface Put request;
            method Action put(CacheAddr addr);
                SimMemAddr simAddr = truncate(addr);
                inputBuf.enq(
                    ArpResp{
                        ipAddr: addr,
                        macAddr: zeroExtend(simMem[simAddr])
                    }
                );
            endmethod
        endinterface

        interface Get response = randDelay.response;
    endinterface

endmodule

typedef 2048 CASE_NUM;
typedef 10000 MAX_CYCLE;
typedef 32 REF_RESP_BUF_SIZE;
typedef Bit#(16) TestbenchCycle;
typedef Bit#(16) TestCaseCount;
(* synthesize *)
module mkTestArpCache();

    Integer caseNum = valueOf(CASE_NUM);
    Integer maxCycle = valueOf(MAX_CYCLE);
    
    ArpCache arpCache <- mkArpCache();
    RandomArpMem arpMem <- mkRandomArpMem;
    mkConnection(arpCache.arpClient, arpMem.memServer);
    Randomize#(SimMemAddr) memAddrRand <- mkGenericRandomizer;

    Reg#(TestbenchCycle) cycle <- mkReg(0);
    Reg#(TestCaseCount) reqCount <- mkReg(0);
    Reg#(TestCaseCount) respCount <- mkReg(0);

    FIFOF#(ArpResp) refRespBuf <- mkSizedFIFOF(valueOf(REF_RESP_BUF_SIZE));

    rule test;
        if (cycle == 0) begin
            memAddrRand.cntrl.init;
        end
        cycle <= cycle + 1;

        immAssert(
            cycle != fromInteger(maxCycle),
            "Testbench timeout assertion @ mkTestArpCache",
            $format("Cycle count can't overflow %d", maxCycle)
        );
        $display("\nCycle %d -----------------------------------",cycle);
    endrule

    rule sendCacheReq if (reqCount < fromInteger(caseNum));
        SimMemAddr memAddr <- memAddrRand.next;
        CacheAddr cacheAddr = zeroExtend(memAddr);
        arpCache.cacheServer.request.put(cacheAddr);
        let refData = arpMem.getRefResp(cacheAddr);
        refRespBuf.enq(ArpResp{ipAddr: cacheAddr, macAddr:refData});
        $display("Send %d Cache Req: Addr = %x", reqCount, memAddr);
        reqCount <= reqCount + 1;
    endrule

    rule checkCacheResp if (respCount < fromInteger(caseNum));
        let dutResp <- arpCache.cacheServer.response.get;
        let refResp = refRespBuf.first; 
        refRespBuf.deq;
        $display("Check %d Cache Response\nDUT:data=%x\nREF:addr=%x data=%x", respCount, dutResp, refResp.ipAddr, refResp.macAddr);

        //assert
        immAssert(
            dutResp == refResp.macAddr,
            "Check output assertion @ mkTestArpCache",
            $format("The responses of dut and ref are inconsistent.")
        );
        respCount <= respCount + 1;
    endrule

    rule doFinish if (respCount == fromInteger(caseNum));
        $display("Pass all %d test cases!", caseNum);
        $finish;
    endrule

endmodule