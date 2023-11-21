`timescale 1ps / 1ps

`define MAC_ADDR_WIDTH 48
`define IP_ADDR_WIDTH  32
`define IP_DSCP_WIDTH  6
`define IP_ECN_WIDTH   2
`define UDP_PORT_WIDTH 16
`define UDP_LEN_WIDTH  16
`define STREAM_DATA_WIDTH 256
`define STREAM_KEEP_WIDTH 32

module TestUdpIpArpEthCmacRxTxWrapper();
    localparam GT_LANE_WIDTH = 4;

    reg udp_clk;
    reg udp_reset;

    reg gt_ref_clk_p;
    reg gt_ref_clk_n;
    reg gt_init_clk;
    reg gt_sys_reset;

    wire [GT_LANE_WIDTH - 1 : 0] gt_n_loop, gt_p_loop;

    wire  udp_config_valid;
    wire  udp_config_ready;
    wire  [`MAC_ADDR_WIDTH - 1 : 0] udp_config_mac_addr;
    wire  [`IP_ADDR_WIDTH  - 1 : 0] udp_config_ip_addr;
    wire  [`IP_ADDR_WIDTH  - 1 : 0] udp_config_net_mask;
    wire  [`IP_ADDR_WIDTH  - 1 : 0] udp_config_gate_way;

    // Tx Channel
    wire tx_udp_meta_valid;
    wire [`IP_ADDR_WIDTH  - 1 : 0] tx_udp_meta_ip_addr;
    wire [`IP_DSCP_WIDTH  - 1 : 0] tx_udp_meta_ip_dscp;
    wire [`IP_ECN_WIDTH   - 1 : 0] tx_udp_meta_ip_ecn;
    wire [`UDP_PORT_WIDTH - 1 : 0] tx_udp_meta_dst_port;
    wire [`UDP_PORT_WIDTH - 1 : 0] tx_udp_meta_src_port;
    wire [`UDP_LEN_WIDTH  - 1 : 0] tx_udp_meta_data_len;
    wire tx_udp_meta_ready;

    
    wire  tx_data_stream_tvalid;
    wire  [`STREAM_DATA_WIDTH - 1 : 0] tx_data_stream_tdata;
    wire  [`STREAM_KEEP_WIDTH - 1 : 0] tx_data_stream_tkeep;
    wire  tx_data_stream_tfirst;
    wire  tx_data_stream_tlast;
    wire  tx_data_stream_tready;

    // Rx Channel
    wire  rx_udp_meta_valid;
    wire  [`IP_ADDR_WIDTH  - 1 : 0] rx_udp_meta_ip_addr;
    wire  [`IP_DSCP_WIDTH  - 1 : 0] rx_udp_meta_ip_dscp;
    wire  [`IP_ECN_WIDTH   - 1 : 0] rx_udp_meta_ip_ecn;
    wire  [`UDP_PORT_WIDTH - 1 : 0] rx_udp_meta_dst_port;
    wire  [`UDP_PORT_WIDTH - 1 : 0] rx_udp_meta_src_port;
    wire  [`UDP_LEN_WIDTH  - 1 : 0] rx_udp_meta_data_len;
    wire  rx_udp_meta_ready;
    
    wire  rx_data_stream_tvalid;
    wire  rx_data_stream_tfirst;
    wire  rx_data_stream_tlast;
    wire  rx_data_stream_tready;
    wire  [`STREAM_DATA_WIDTH - 1 : 0] rx_data_stream_tdata;
    wire  [`STREAM_KEEP_WIDTH - 1 : 0] rx_data_stream_tkeep;

    mkTestUdpIpArpEthCmacRxTx testbench(
        .m_udp_config_valid   (udp_config_valid   ),
        .m_udp_config_mac_addr(udp_config_mac_addr),
		.m_udp_config_ip_addr (udp_config_ip_addr ),
		.m_udp_config_net_mask(udp_config_net_mask),
		.m_udp_config_gate_way(udp_config_gate_way),
		.m_udp_config_ready   (udp_config_ready   ),

		.m_udp_meta_valid     (tx_udp_meta_valid   ),
		.m_udp_meta_ip_addr   (tx_udp_meta_ip_addr ),
		.m_udp_meta_ip_dscp   (tx_udp_meta_ip_dscp ),
		.m_udp_meta_ip_ecn    (tx_udp_meta_ip_ecn  ),
		.m_udp_meta_dst_port  (tx_udp_meta_dst_port),
		.m_udp_meta_src_port  (tx_udp_meta_src_port),
		.m_udp_meta_data_len  (tx_udp_meta_data_len),
		.m_udp_meta_ready     (tx_udp_meta_ready   ),

		.m_data_stream_tvalid (tx_data_stream_tvalid),
		.m_data_stream_tdata  (tx_data_stream_tdata ),
		.m_data_stream_tkeep  (tx_data_stream_tkeep ),
		.m_data_stream_tfirst (tx_data_stream_tfirst),
		.m_data_stream_tlast  (tx_data_stream_tlast ),
		.m_data_stream_tready (tx_data_stream_tready),

		.s_udp_meta_valid     (rx_udp_meta_valid   ),
		.s_udp_meta_ip_addr   (rx_udp_meta_ip_addr ),
		.s_udp_meta_ip_dscp   (rx_udp_meta_ip_dscp ),
		.s_udp_meta_ip_ecn    (rx_udp_meta_ip_ecn  ),
		.s_udp_meta_dst_port  (rx_udp_meta_dst_port),
		.s_udp_meta_src_port  (rx_udp_meta_src_port),
		.s_udp_meta_data_len  (rx_udp_meta_data_len),
		.s_udp_meta_ready     (rx_udp_meta_ready   ),

		.s_data_stream_tvalid (rx_data_stream_tvalid),
		.s_data_stream_tdata  (rx_data_stream_tdata ),
		.s_data_stream_tkeep  (rx_data_stream_tkeep ),
		.s_data_stream_tfirst (rx_data_stream_tfirst),
		.s_data_stream_tlast  (rx_data_stream_tlast ),
		.s_data_stream_tready (rx_data_stream_tready),

        .udp_clk  (udp_clk),
        .udp_reset(udp_reset)
    );

    UdpIpArpEthCmacRxTxWrapper#(
        GT_LANE_WIDTH
    ) udpCmacInst(

        .udp_clk     (udp_clk  ),
        .udp_reset   (udp_reset),

        .gt_ref_clk_p(gt_ref_clk_p),
        .gt_ref_clk_n(gt_ref_clk_n),
        .gt_init_clk (gt_init_clk ),
        .gt_sys_reset(gt_sys_reset),

        // Config
        .s_udp_config_valid   (udp_config_valid   ),
        .s_udp_config_mac_addr(udp_config_mac_addr),
        .s_udp_config_ip_addr (udp_config_ip_addr ),
        .s_udp_config_net_mask(udp_config_net_mask),
        .s_udp_config_gate_way(udp_config_gate_way),
        .s_udp_config_ready   (udp_config_ready   ),

        // Tx Channel
        .s_udp_meta_valid   (tx_udp_meta_valid   ),
        .s_udp_meta_ip_addr (tx_udp_meta_ip_addr ),
        .s_udp_meta_ip_dscp (tx_udp_meta_ip_dscp ),
        .s_udp_meta_ip_ecn  (tx_udp_meta_ip_ecn  ),
        .s_udp_meta_dst_port(tx_udp_meta_dst_port),
        .s_udp_meta_src_port(tx_udp_meta_src_port),
        .s_udp_meta_data_len(tx_udp_meta_data_len),
        .s_udp_meta_ready   (tx_udp_meta_ready   ),

    
        .s_data_stream_tvalid(tx_data_stream_tvalid),
        .s_data_stream_tdata (tx_data_stream_tdata ),
        .s_data_stream_tkeep (tx_data_stream_tkeep ),
        .s_data_stream_tfirst(tx_data_stream_tfirst),
        .s_data_stream_tlast (tx_data_stream_tlast ),
        .s_data_stream_tready(tx_data_stream_tready),

        // Rx Channel
        .m_udp_meta_valid   (rx_udp_meta_valid   ),
        .m_udp_meta_ip_addr (rx_udp_meta_ip_addr ),
        .m_udp_meta_ip_dscp (rx_udp_meta_ip_dscp ),
        .m_udp_meta_ip_ecn  (rx_udp_meta_ip_ecn  ),
        .m_udp_meta_dst_port(rx_udp_meta_dst_port),
        .m_udp_meta_src_port(rx_udp_meta_src_port),
        .m_udp_meta_data_len(rx_udp_meta_data_len),
        .m_udp_meta_ready   (rx_udp_meta_ready   ),

        .m_data_stream_tvalid(rx_data_stream_tvalid),
        .m_data_stream_tdata (rx_data_stream_tdata ),
        .m_data_stream_tkeep (rx_data_stream_tkeep ),
        .m_data_stream_tfirst(rx_data_stream_tfirst),
        .m_data_stream_tlast (rx_data_stream_tlast ),
        .m_data_stream_tready(rx_data_stream_tready),

        // Serdes
        .gt_rxn_in (gt_n_loop),
        .gt_rxp_in (gt_p_loop),
        .gt_txn_out(gt_n_loop),
        .gt_txp_out(gt_p_loop)
    );
    
    initial
    begin
        gt_ref_clk_p =1;
        forever #3200 gt_ref_clk_p = ~ gt_ref_clk_p;
    end

    initial
    begin
        gt_ref_clk_n =0;
        forever #3200 gt_ref_clk_n = ~ gt_ref_clk_n;
    end

    initial
    begin
        udp_clk =0;
        forever #1000 udp_clk = ~udp_clk;
    end

    initial
    begin
        udp_reset = 0;
        #201000;
        udp_reset = 1;
    end

    initial
    begin
        gt_init_clk = 0;
        forever #5000 gt_init_clk = ~gt_init_clk;
    end

    initial
    begin
        gt_sys_reset = 1;
        #1001000;
        gt_sys_reset = 0;
    end
endmodule
