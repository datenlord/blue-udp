import Vector::*;

typedef Bit#(TLog#(size)) CamAddr#(numeric type size);
interface ContentAddressMem#(
    numeric type size, type tagType, type dataType
);
    method Action write(CamAddr#(size) addr, tagType tag, dataType data);
    method Action clear(CamAddr#(size) addr);
    method Maybe#(CamAddr#(size)) searchEmpty;
    method Maybe#(CamAddr#(size)) searchTag(tagType tag);
    method dataType read(CamAddr#(size) addr);

endinterface

module mkContentAddressMem(ContentAddressMem#(size, tagType, dataType)) 
    provisos(Bits#(tagType, tagSz), Bits#(dataType, dataSz), Eq#(tagType));
    Vector#(size, Reg#(dataType)) dataArray <- replicateM(mkRegU);
    Vector#(size, Reg#(tagType)) tagArray <- replicateM(mkRegU);
    Vector#(size, Reg#(Bool)) validArray <- replicateM(mkReg(False));

    Reg#(Maybe#(Tuple3#(CamAddr#(size), tagType, dataType))) wrReq[2] <- mkCReg(2, Invalid);
    Reg#(Maybe#(CamAddr#(size))) clearReq[2] <- mkCReg(2, Invalid);

    (* fire_when_enabled *)
    (* no_implicit_conditions *)
    rule canonicalize;
        match {.wrAddr, .wrTag, .wrData} = fromMaybe(?, wrReq[1]);
        let clearAddr = fromMaybe(?, clearReq[1]);
        let wrEn = isValid(wrReq[1]);
        let clearEn = isValid(clearReq[1]);
        if (wrEn) begin
            tagArray[wrAddr] <= wrTag;
            dataArray[wrAddr] <= wrData;
        end

        if (wrEn && clearEn && clearAddr == wrAddr) begin
            validArray[clearAddr] <= False;
        end
        else begin
            if (wrEn) begin 
                validArray[wrAddr] <= True; 
            end
            if (clearEn) begin 
                validArray[clearAddr] <= False;
            end
        end

        wrReq[1] <= tagged Invalid;
        clearReq[1] <= tagged Invalid;
    endrule

    method Action write(CamAddr#(size) addr, tagType tag, dataType data);
        wrReq[0] <= tagged Valid tuple3(addr, tag, data);
    endmethod

    method Action clear(CamAddr#(size) addr);
        clearReq[0] <= tagged Valid addr;
    endmethod

    method Maybe#(CamAddr#(size)) searchEmpty;
        Maybe#(CamAddr#(size)) addr = tagged Invalid;
        for(Integer i=0; i < valueOf(size); i=i+1) begin
            if (!validArray[i]) addr = tagged Valid fromInteger(i);
        end
        return addr;
    endmethod

    method Maybe#(CamAddr#(size)) searchTag(tagType tag);
        Maybe#(CamAddr#(size)) addr = tagged Invalid;
        for(Integer i=0; i < valueOf(size); i=i+1) begin
            if (validArray[i] && tagArray[i]==tag) begin
                addr = tagged Valid fromInteger(i);
            end
        end
        return addr;
    endmethod

    method dataType read(CamAddr#(size) addr);
        return dataArray[addr];
    endmethod

endmodule