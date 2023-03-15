import PAClib::*;

import Ports::*;



interface ArpProcessor;
    interface DataStreamPipeOut dataStreamOut;
    interface MacMetaDataPipeOut macMetaDataOut;
endinterface


module mkArpProcessor#(
    DataStreamPipeOut dataStreamIn,

)(ArpProcessor);

endmodule