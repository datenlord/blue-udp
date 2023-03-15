function Bool isZero(Bit#(nSz) bits) provisos(Add#(1, anysize, nSz));
    // TODO: consider using fold
    Bool ret = unpack(|bits);
    return !ret;
endfunction

function Bool isLessOrEqOne(Bit#(nSz) bits) provisos(Add#(1, anysize, nSz));
    Bool ret = isZero(bits >> 1);
    // Bool ret = isZero(bits >> 1) && unpack(bits[0]);
    return ret;
endfunction

function Bool isOne(Bit#(nSz) bits) provisos(Add#(1, anysize, nSz));
    return isLessOrEqOne(bits) && unpack(bits[0]);
endfunction

function Bool isAllOnes(Bit#(nSz) bits);
    Bool ret = unpack(&bits);
    return ret;
endfunction

function Bool isLargerThanOne(Bit#(tSz) bits) provisos(Add#(1, anysize, tSz));
    return !isZero(bits >> 1);
endfunction

function Bit#(nSz) zeroExtendLSB(Bit#(mSz) bits) provisos(Add#(mSz, anysize, nSz));
    return { bits, 0 };
endfunction

function Bit#(1) getMSB(Bit#(nSz) bits) provisos(Add#(1, anysize, nSz));
    return (reverseBits(bits))[0];
endfunction

function Bit#(TSub#(nSz, 1)) removeMSB(Bit#(nSz) bits) provisos(Add#(1, anysize, nSz));
    return truncateLSB(bits << 1);
endfunction

function anytype dontCareValue() provisos(Bits#(anytype, anysize));
    return ?;
endfunction

function anytype unwrapMaybe(Maybe#(anytype) maybe) provisos(Bits#(anytype, anysize));
    return fromMaybe(?, maybe);
endfunction

function anytype unwrapMaybeWithDefault(
    Maybe#(anytype) maybe, anytype defaultVal
) provisos(Bits#(anytype, nSz));
    return fromMaybe(defaultVal, maybe);
endfunction

function anytype1 getTupleFirst(Tuple2#(anytype1, anytype2) tupleVal);
    return tpl_1(tupleVal);
endfunction

function anytype2 getTupleSecond(Tuple2#(anytype1, anytype2) tupleVal);
    return tpl_2(tupleVal);
endfunction

function anytype identityFunc(anytype inputVal);
    return inputVal;
endfunction

function Action immAssert(Bool condition, String assertName, Fmt assertFmtMsg);
    action
        let pos = printPosition(getStringPosition(assertName));
        // let pos = printPosition(getEvalPosition(condition));
        if (!condition) begin
            $display(
              "ImmAssert failed in %m @time=%0t: %s-- %s: ",
              $time, pos, assertName, assertFmtMsg
            );
            $finish(1);
        end
    endaction
endfunction

function Action immFail(String assertName, Fmt assertFmtMsg);
    action
        let pos = printPosition(getStringPosition(assertName));
        // let pos = printPosition(getEvalPosition(condition));
        $display(
            "ImmAssert failed in %m @time=%0t: %s-- %s: ",
            $time, pos, assertName, assertFmtMsg
        );
        $finish(1);
    endaction
endfunction
