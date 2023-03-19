import ContentAddressMem::*;

module mkTestContentAddressMem();
    ContentAddressMem#(8, Bit#(10), Bit#(10)) cam <- mkContentAddressMem;
endmodule