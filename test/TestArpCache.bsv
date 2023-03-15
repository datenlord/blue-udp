import FIFOF::*;
import Randomizable::*;
import Connectable::*;
import Vector::*;
import PAClib::*;
import ClientServer::*;
import GetPut::*;

import ArpCache::*;
import TestUtils::*;

typedef 10 SIM_MEM_ADDR_WIDTH;
typedef TExp#(SIM_MEM_ADDR_WIDTH) SIM_MEM_SIZE;
typedef Bit#(SIM_MEM_ADDR_WIDTH) SimMemAddr;
typedef 16 SIM_MEM_DATA_WIDTH;
typedef Bit#(SIM_MEM_DATA_WIDTH) SimMemData;

(* synthesize *)
module mkTestArpCache();
    ArpCache arpCache <- mkArpCache();
    // Vector#(SIM_MEM_SIZE, Reg#(SimMemData)) simMem <- replicateM(mkRegU);

    
    // Randomize#(SimMemData) memDataRand <- mkGenericRandomizer;
    // Randomize#(SimMemAddr) memAddrRand <- mkGenericRandomizer;

    // Reg#(Bit#(16)) cycle <- mkReg(0);
    // rule test;
    //     if (cycle == 0) begin
    //         memDataRand.cntrl.init;
    //         memAddrRand.cntrl.init;
    //     end
    //     else if(cycle == 1) begin
    //         for(Integer i=0; i < valueOf(SIM_MEM_SIZE); i=i+1) begin
    //             let memData <- memDataRand.next;
    //             simMem[i] <= memData;
    //         end
    //     end
    //     cycle <= cycle + 1;
    //     $display("\nCycle %d -----------------------------------",cycle);
    //     if(cycle == 6000) begin
    //         $display("Error: Time Out!");
    //         $finish;
    //     end
    // endrule

    // Integer caseNum = 512;
    // FIFOF#(CacheData) refDataBuf <- mkSizedFIFOF(32);
    // FIFOF#(CacheAddr) refAddrBuf <- mkSizedFIFOF(32);

    // Reg#(Bit#(16)) reqCount <- mkReg(0);
    // rule doReq if(reqCount < fromInteger(caseNum) && cycle != 0);
    //     SimMemAddr memAddr <- memAddrRand.next;
    //     arpCache.req.put( zeroExtend(memAddr) );
    //     let refData = simMem[memAddr];
    //     refDataBuf.enq(zeroExtend(refData));
    //     refAddrBuf.enq(zeroExtend(memAddr));
    //     $display("Cache Req: Addr = %x", memAddr);
    //     reqCount <= reqCount + 1;
    // endrule

    // Reg#(Bit#(16)) respCount <- mkReg(0);
    // rule checkResp;
    //     let dutData = arpCache.resp.first; arpCache.resp.deq;
    //     let refData = refDataBuf.first; refDataBuf.deq;
    //     let refAddr = refAddrBuf.first; refAddrBuf.deq;
    //     if(dutData != refData) begin
    //         $display("Cache Resp: result is fault at Addr = %x", refAddr);
    //         $display("DUT Data: %x", dutData);
    //         $display("REF Data: %x", refData);
    //         $finish;
    //     end
    //     respCount <= respCount + 1;
    // endrule
    
    // RandomDelay#(ArpResp, 10) arpRespBuf <- mkRandomDelay(6);
    // rule doArpReq;
    //     SimMemAddr addr = truncate(arpCache.arpReq.first); arpCache.arpReq.deq;
    //     let data = simMem[addr];
    //     arpRespBuf.request.put(ArpResp{ipAddr: zeroExtend(addr), macAddr:zeroExtend(data)});
    // endrule

    // mkConnection(arpRespBuf.response, arpCache.arpResp);

    // rule doFinish;
    //     if(respCount == fromInteger(caseNum)) begin
    //         $display("Pass All test cases!");
    //         $finish;
    //     end
    // endrule

endmodule