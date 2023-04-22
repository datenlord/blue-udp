import Vector :: *;

typedef Bit#(TLog#(size)) CamAddr#(numeric type size);
interface ContentAddressMem#(
    numeric type size, type tagType, type dataType
);
    method Action write(tagType tag, dataType data);
    method Action clear(tagType tag);
    method Bool search(tagType tag);
    method Maybe#(dataType) read(tagType tag);

endinterface

module mkContentAddressMem(ContentAddressMem#(size, tagType, dataType)) 
    provisos(Bits#(tagType, tagSz), Bits#(dataType, dataSz), Eq#(tagType));
    Vector#(size, Reg#(dataType)) dataArray <- replicateM(mkRegU);
    Vector#(size, Reg#(tagType)) tagArray <- replicateM(mkRegU);
    Reg#(Bit#(size)) validReg <- mkReg(0);

    Reg#(Maybe#(Tuple3#(CamAddr#(size), tagType, dataType))) wrReq[2] <- mkCReg(2, Invalid);
    Reg#(Maybe#(CamAddr#(size))) clearReq[2] <- mkCReg(2, Invalid);

    let memFull = validReg == fromInteger(valueOf(TSub#(TExp#(size),1)));

    function Bool isTagExist(tagType tag);
        Bool result = False;
        for (Integer i = 0; i < valueOf(size); i = i + 1) begin
            if (validReg[i] == 1 && tagArray[i]==tag) begin
                result = True;
            end
        end
        return result;
    endfunction

    function Maybe#(CamAddr#(size)) getTagAddr(tagType tag);
        Maybe#(CamAddr#(size)) addr = tagged Invalid;
        for (Integer i = 0; i < valueOf(size); i = i + 1) begin
            if (validReg[i] == 1 && tagArray[i] == tag) begin
                addr = tagged Valid fromInteger(i);
            end
        end
        return addr;    
    endfunction

    (* fire_when_enabled *)
    (* no_implicit_conditions *)
    rule canonicalize;
        let nextValidReg = validReg;
        
        if (wrReq[1] matches tagged Valid .wrInfo) begin
            match {.addr, .tag, .data} = wrInfo;
            nextValidReg[addr] = 1;
            tagArray[addr] <= tag;
            dataArray[addr] <= data;
        end

        if (clearReq[1] matches tagged Valid .addr) begin
            nextValidReg[addr] = 0;
        end
        
        validReg <= nextValidReg;
        wrReq[1] <= tagged Invalid;
        clearReq[1] <= tagged Invalid;
    endrule

    method Action write(tagType tag, dataType data) if (!memFull);
        CamAddr#(size) addr = 0;
        for (Integer i = 0; i < valueOf(size); i = i + 1) begin
            if (validReg[i] == 0) begin
                addr = fromInteger(i);
            end
        end
        wrReq[0] <= tagged Valid tuple3(addr, tag, data);
    endmethod

    method Action clear(tagType tag);
        let addr = getTagAddr(tag);
        if (addr matches tagged Valid .addrVal) begin
            clearReq[0] <= tagged Valid addrVal;
        end
    endmethod

    method Bool search(tagType tag);
        return isTagExist(tag);
    endmethod

    method Maybe#(dataType) read(tagType tag);
        let addr = getTagAddr(tag);
        Maybe#(dataType) data = tagged Invalid;
        if (addr matches tagged Valid .addrVal) begin
            data = tagged Valid dataArray[addrVal];
        end
        return data;
    endmethod

endmodule