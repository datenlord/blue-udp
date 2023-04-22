
module mkUdpEthRxWrapper#(
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

    input  s_axi_stream_tvalid,
    output s_axi_stream_tready,
    input  s_axi_stream_tlast,
    input  s_axi_stream_tuser,
    input [AXIS_TDATA_WIDTH - 1 : 0] s_axi_stream_tdata,
    input [AXIS_TKEEP_WIDTH - 1 : 0] s_axi_stream_tkeep,

    output m_mac_meta_valid,
    input  m_mac_meta_ready,
    output [MAC_ADDR_WIDTH - 1 : 0] m_mac_meta_mac_addr,
    output [ETH_TYPE_WIDTH - 1 : 0] m_mac_meta_eth_type,

    output m_udp_meta_valid,
    input  m_udp_meta_ready,
    output [IP_ADDR_WIDTH  - 1 : 0] m_udp_meta_ip_addr,
    output [UDP_PORT_WIDTH - 1 : 0] m_udp_meta_dst_port,
    output [UDP_PORT_WIDTH - 1 : 0] m_udp_meta_src_port,
    output [UDP_LEN_WIDTH  - 1 : 0] m_udp_meta_data_len,

    output m_data_stream_tvalid,
    input  m_data_stream_tready,
    output [DATA_WIDTH - 1 : 0] m_data_stream_tdata,
    output [KEEP_WIDTH - 1 : 0] m_data_stream_tkeep,
    output m_data_stream_tfirst,
    output m_data_stream_tlast
);
    mkUdpEthRx udpEthRxInst(
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


        .axiStreamInRx_put(
            {
                s_axi_stream_tdata,
                s_axi_stream_tkeep,
                s_axi_stream_tuser,
                s_axi_stream_tlast
            }
        ),
		.EN_axiStreamInRx_put (s_axi_stream_tvalid & s_axi_stream_tready),
		.RDY_axiStreamInRx_put(s_axi_stream_tready),


        .macMetaDataOutRx_first(
            {
                m_mac_meta_mac_addr,
                m_mac_meta_eth_type
            }
        ),
		.RDY_macMetaDataOutRx_first(),
		.EN_macMetaDataOutRx_deq(m_mac_meta_ready & m_mac_meta_valid),
		.RDY_macMetaDataOutRx_deq(m_mac_meta_valid),
		.macMetaDataOutRx_notEmpty(),
		.RDY_macMetaDataOutRx_notEmpty(),


        .udpMetaDataOutRx_first(
            {
                m_udp_meta_data_len,
                m_udp_meta_ip_addr,
                m_udp_meta_dst_port,
                m_udp_meta_src_port
            }
        ),
		.RDY_udpMetaDataOutRx_first(m_udp_meta_valid),
		.EN_udpMetaDataOutRx_deq(m_udp_meta_ready & m_udp_meta_valid),
		.RDY_udpMetaDataOutRx_deq(),
		.udpMetaDataOutRx_notEmpty(),
		.RDY_udpMetaDataOutRx_notEmpty(),


		.dataStreamOutRx_first(
            {
                m_data_stream_tdata,
                m_data_stream_tkeep,
                m_data_stream_tfirst,
                m_data_stream_tlast
            }
        ),
		.RDY_dataStreamOutRx_first(),
		.EN_dataStreamOutRx_deq(m_data_stream_tready & m_data_stream_tvalid),
		.RDY_dataStreamOutRx_deq(m_data_stream_tvalid),
		.dataStreamOutRx_notEmpty(),
		.RDY_dataStreamOutRx_notEmpty()

    );

endmodule