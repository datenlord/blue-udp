
module mkStandardCrc32SynWrapper#(
    parameter DATA_WIDTH = 256,
    parameter KEEP_WIDTH = 32,
    parameter CRC_WIDTH  = 32
)(
    input clk,
    input reset_n,

    input  s_data_stream_tvalid,
    output s_data_stream_tready,
    input  s_data_stream_tlast,
    input [DATA_WIDTH - 1 : 0] s_data_stream_tdata,
    input [KEEP_WIDTH - 1 : 0] s_data_stream_tkeep,

    output m_crc_stream_valid,
    input  m_crc_stream_ready,
    output [CRC_WIDTH - 1 : 0] m_crc_stream_data
);
    mkStandardCrc32Syn crc32Inst(
        .CLK  (    clk),
        .RST_N(reset_n),
        
        .dataStreamIn_put(
            {
                s_data_stream_tdata,
                s_data_stream_tkeep,
                1'b0,
                s_data_stream_tlast
            }
        ),
		.EN_dataStreamIn_put (s_data_stream_tvalid),
		.RDY_dataStreamIn_put(s_data_stream_tready),
		.crcCheckSumOut_first(m_crc_stream_data),
		.RDY_crcCheckSumOut_first(),
		.EN_crcCheckSumOut_deq (m_crc_stream_ready & m_crc_stream_valid),
		.RDY_crcCheckSumOut_deq(m_crc_stream_valid),

		.crcCheckSumOut_notEmpty(),
		.RDY_crcCheckSumOut_notEmpty()
    );

endmodule