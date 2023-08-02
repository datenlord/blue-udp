import BRAM :: *;
import Vector :: *;
import GetPut :: *;
import ClientServer :: *;


interface RFile#(numeric type indexWidth, type dataType);
    method dataType rd(Bit#(indexWidth) index);
    method Action wr(Bit#(indexWidth) index, dataType data);
endinterface

module mkCFRFile(RFile#(iWidth, dType)) provisos(Bits#(dType, dSz));
    Vector#(TExp#(iWidth), Reg#(dType)) rfile <- replicateM(mkRegU);
    Wire#(Maybe#(Tuple2#(Bit#(iWidth), dType))) wrReq <- mkDWire(Invalid);

    (* fire_when_enabled *)
	(* no_implicit_conditions *)
    rule cononicalize;
        if (isValid(wrReq)) begin
            match{.index, .data} = fromMaybe(?, wrReq);
            rfile[index] <= data;
        end
    endrule

    method Action wr(Bit#(iWidth) index, dType data);
        wrReq <= tagged Valid tuple2(index, data);
    endmethod

    method dType rd(Bit#(iWidth) index);
        return rfile[index];
    endmethod
endmodule

module mkCFRFileInit#(dType initVal)(RFile#(iWidth, dType)) provisos(Bits#(dType, dSz));
    Vector#(TExp#(iWidth), Reg#(dType)) rfile <- replicateM(mkReg(initVal));
    Wire#(Maybe#(Tuple2#(Bit#(iWidth), dType))) wrReq <- mkDWire(Invalid);
    
    (* fire_when_enabled *)
	(* no_implicit_conditions *)
    rule cononicalize;
        if (isValid(wrReq)) begin
            match{.index, .data} = fromMaybe(?, wrReq);
            rfile[index] <= data;
        end
    endrule

    method Action wr(Bit#(iWidth) index, dType data);
        wrReq <= tagged Valid tuple2(index, data);
    endmethod

    method dType rd(Bit#(iWidth) index);
        return rfile[index];
    endmethod
endmodule

interface RFileBram#(type addrType, type dataType);
    interface Server#(addrType, dataType) readServer;
    method Action write(addrType addr, dataType data);
endinterface

module mkRFileBram(RFileBram#(addrType, dataType)) provisos(
    Bits#(addrType, addrWidth),
    Bits#(dataType, dataWidth)
);
    BRAM_Configure bramConf = defaultValue;
    bramConf.latency = 2;
    bramConf.outFIFODepth = bramConf.latency + 2;
    BRAM2Port#(addrType, Bit#(dataWidth)) bram2Port <- mkBRAM2Server(bramConf);

    interface Server readServer;
        interface Put request;
            method Action put(addrType addr);
                BRAMRequest#(addrType, Bit#(dataWidth)) req = BRAMRequest {
                    write: False,
                    responseOnWrite: False,
                    address: addr,
                    datain: 0
                };
                bram2Port.portA.request.put(req);
            endmethod
        endinterface

        interface Get response;
            method ActionValue#(dataType) get();
                let data <- bram2Port.portA.response.get();
                return unpack(data);
            endmethod
        endinterface
    endinterface

    method Action write(addrType addr, dataType data);
        BRAMRequest#(addrType, Bit#(dataWidth)) req = BRAMRequest {
            write: True,
            responseOnWrite: False,
            address: addr,
            datain: pack(data)
        };
        bram2Port.portB.request.put(req);
    endmethod

endmodule