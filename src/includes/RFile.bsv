import Vector :: *;


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
