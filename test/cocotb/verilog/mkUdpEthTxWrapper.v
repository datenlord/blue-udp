
module mkUdpEthTxWrapper#(
    parameter AXIS_TDATA_WIDTH = 512,
    parameter AXIS_TKEEP_WIDTH = 64,
    parameter DATA_WIDTH = 256,
    parameter KEEP_WIDTH = 32,
    parameter UDP_LEN_WIDTH  = 16,
    parameter IP_ADDR_WIDTH  = 32,
    parameter UDP_PORT_WIDTH = 16,
    parameter MAC_ADDR_WIDTH = 48,
    parameter ETH_TYPE_WIDTH = 16
)(
    input clk,
    input reset_n,

    // configuration ports
    input  s_udp_config_valid,
    output s_udp_config_ready,
    input [MAC_ADDR_WIDTH - 1 : 0] s_udp_config_mac_addr,
    input [IP_ADDR_WIDTH  - 1 : 0] s_udp_config_ip_addr,
    input [IP_ADDR_WIDTH  - 1 : 0] s_udp_config_net_mask,
    input [IP_ADDR_WIDTH  - 1 : 0] s_udp_config_gate_way,

    // tx ports
    input  s_udp_meta_valid,
    output s_udp_meta_ready,
    input [IP_ADDR_WIDTH - 1  : 0] s_udp_meta_ip_addr,
    input [UDP_PORT_WIDTH - 1 : 0] s_udp_meta_dst_port,
    input [UDP_PORT_WIDTH - 1 : 0] s_udp_meta_src_port,
    input [UDP_LEN_WIDTH - 1  : 0] s_udp_meta_data_len,

    input  s_mac_meta_valid,
    output s_mac_meta_ready,
    input [MAC_ADDR_WIDTH - 1 : 0] s_mac_meta_mac_addr,
    input [ETH_TYPE_WIDTH - 1 : 0] s_mac_meta_eth_type,

    input  s_data_stream_tvalid,
    output s_data_stream_tready,
    input [DATA_WIDTH - 1 : 0] s_data_stream_tdata,
    input [KEEP_WIDTH - 1 : 0] s_data_stream_tkeep,
    input s_data_stream_tfirst,
    input s_data_stream_tlast,

    output m_axi_stream_tvalid,
    input  m_axi_stream_tready,
    output m_axi_stream_tlast,
    output m_axi_stream_tuser,
    output [AXIS_TDATA_WIDTH - 1 : 0] m_axi_stream_tdata,
    output [AXIS_TKEEP_WIDTH - 1 : 0] m_axi_stream_tkeep
);
    mkUdpEthTx udpEthTxInst(
        .CLK  (    clk),
		.RST_N(reset_n),

		.udpConfig_put(
            {
                s_udp_config_mac_addr, 
                s_udp_config_ip_addr,
                s_udp_config_net_mask,
                s_udp_config_gate_way
            }
        ),
		.EN_udpConfig_put (s_udp_config_valid & s_udp_config_ready),
		.RDY_udpConfig_put(s_udp_config_ready),


		.udpMetaDataInTx_put(
            {
                s_udp_meta_data_len,
                s_udp_meta_ip_addr,
                s_udp_meta_dst_port,
                s_udp_meta_src_port
            }
        ),
		.EN_udpMetaDataInTx_put (s_udp_meta_valid & s_udp_meta_ready),
		.RDY_udpMetaDataInTx_put(s_udp_meta_ready),


		.macMetaDataInTx_put(
            {
                s_mac_meta_mac_addr,
                s_mac_meta_eth_type
            }
        ),
		.EN_macMetaDataInTx_put (s_mac_meta_valid & s_mac_meta_ready),
		.RDY_macMetaDataInTx_put(s_mac_meta_ready),


		.dataStreamInTx_put(
            {
                s_data_stream_tdata,
                s_data_stream_tkeep,
                s_data_stream_tfirst,
                s_data_stream_tlast
            }
        ),
		.EN_dataStreamInTx_put (s_data_stream_tvalid & s_data_stream_tready),
		.RDY_dataStreamInTx_put(s_data_stream_tready),


		.axiStreamOutTx_first({
            m_axi_stream_tdata,
            m_axi_stream_tkeep,
            m_axi_stream_tuser,
            m_axi_stream_tlast
        }),
		.RDY_axiStreamOutTx_first(),
		.EN_axiStreamOutTx_deq(m_axi_stream_tready & m_axi_stream_tvalid),
		.RDY_axiStreamOutTx_deq(m_axi_stream_tvalid),
		.axiStreamOutTx_notEmpty(),
		.RDY_axiStreamOutTx_notEmpty()
    );

    // initial begin            
    //     $dumpfile("udpEthTx.vcd");
    //     $dumpvars(0);
    // end
endmodule