import FIFOF::*;
import GetPut::*;
import ClientServer::*;
import PAClib::*;

import Utils::*;
import HeaderGenerator::*;
import Ports::*;
import FragmentTypes::*;


interface UdpTransmitter;
    interface Put#( UdpConfig  ) udpConfig;
    interface Put#( MetaData   ) metaDataIn;
    interface Put#( DataStream ) dataStreamIn;
    interface DataStreamPipeOut dataStreamOut;
endinterface

typedef enum{
    HEADER, PAYLOAD, UNALIGN
} DataStreamSel deriving(Bits, Eq);

module mkUdpTransmitter( UdpTransmitter );
    Reg#(Maybe#(UdpConfig)) udpConfigReg <- mkReg(Invalid);
    Reg#(DataStreamSel) dataStreamSel <- mkReg(HEADER);
    Reg#(Unalignment) unalignDataBuf <- mkReg(0);
    Reg#(UnalignByteEn) unalignByteEnBuf <- mkReg(0);
    FIFOF#( DataStream ) dataStreamInBuf <- mkFIFOF;
    FIFOF#( DataStream ) dataStreamOutBuf <- mkFIFOF;
    HeaderGenerator headerGen <- mkHeaderGenerator(udpConfigReg);

    rule doDataStreamMux;
        if (dataStreamSel == HEADER) begin
            DataStream header <- headerGen.response.get;
            if (header.isLast) begin
                header.isLast = False;

                DataStream data = dataStreamInBuf.first; dataStreamInBuf.deq;
                SepDataStream sepData = seperateDataStreamOut(data);
                header.data = {sepData.residue, truncate(header.data)};
                header.byteEn = {sepData.residueByteEn, truncate(header.byteEn)};
                unalignDataBuf <= sepData.unalignData;
                unalignByteEnBuf <= sepData.unalignByteEn;
                
                if (!data.isLast) begin 
                    dataStreamSel <= PAYLOAD;
                end
                else if (data.isLast && sepData.unalignByteEn!=0) begin
                    dataStreamSel <= UNALIGN;
                end 
            end
            dataStreamOutBuf.enq(header);
        end
        else if (dataStreamSel == PAYLOAD)begin
            DataStream data = dataStreamInBuf.first; dataStreamInBuf.deq;
            
            data.isFirst = False;
            SepDataStream sepData = seperateDataStreamOut(data);
            data.data = {sepData.residue, unalignDataBuf};
            data.byteEn = {sepData.residueByteEn, unalignByteEnBuf};
            unalignDataBuf <= sepData.unalignData;
            unalignByteEnBuf <= sepData.unalignByteEn;

            if (data.isLast) begin
                if(sepData.unalignByteEn == 0) begin
                    dataStreamSel <= HEADER;
                end
                else begin
                    data.isLast = False;
                    dataStreamSel <= UNALIGN;
                end
            end
            dataStreamOutBuf.enq(data);
        end
        else if (dataStreamSel == UNALIGN) begin
            DataStream data = DataStream {
                data: zeroExtend(unalignDataBuf),
                byteEn: zeroExtend(unalignByteEnBuf),
                isFirst: False,
                isLast: True
            };
            dataStreamOutBuf.enq(data);
            dataStreamSel <= HEADER;
        end
    endrule
    
    interface Put udpConfig;
        method Action put(UdpConfig x);
            udpConfigReg <= tagged Valid x;
        endmethod
    endinterface

    interface Put metaDataIn;
        method Action put(MetaData metaData);
            headerGen.request.put(metaData);
        endmethod
    endinterface

    interface Put dataStreamIn = toPut( dataStreamInBuf );
    interface PipeOut dataStreamOut = f_FIFOF_to_PipeOut(dataStreamOutBuf);

endmodule