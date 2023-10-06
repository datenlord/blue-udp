`timescale 1ps / 1ps

module TestUdpIpArpEthCmacRxTxWrapper();
    localparam GT_LANE_WIDTH = 4;
    localparam XDMA_AXIS_TDATA_WIDTH = 512;
    localparam XDMA_AXIS_TKEEP_WIDTH = 64;
    localparam XDMA_AXIS_TUSER_WIDTH = 1;

    wire udp_clk;
    wire udp_reset;

    wire gt_ref_clk_p;
    wire gt_ref_clk_n;
    wire init_clk;
    wire sys_reset;

    wire xdma_rx_axis_tready;
    wire xdma_rx_axis_tvalid;
    wire xdma_rx_axis_tlast;
    wire [XDMA_AXIS_TDATA_WIDTH - 1 : 0] xdma_rx_axis_tdata;
    wire [XDMA_AXIS_TKEEP_WIDTH - 1 : 0] xdma_rx_axis_tkeep;
    wire [XDMA_AXIS_TUSER_WIDTH - 1 : 0] xdma_rx_axis_tuser;

    wire xdma_tx_axis_tvalid;
    wire xdma_tx_axis_tready;
    wire xdma_tx_axis_tlast;
    wire [XDMA_AXIS_TDATA_WIDTH - 1 : 0] xdma_tx_axis_tdata;
    wire [XDMA_AXIS_TKEEP_WIDTH - 1 : 0] xdma_tx_axis_tkeep;
    wire [XDMA_AXIS_TUSER_WIDTH - 1 : 0]xdma_tx_axis_tuser;

    wire [GT_LANE_WIDTH - 1 : 0] gt1_rx_n, gt1_rx_p, gt1_tx_n, gt1_tx_p;


    UdpIpArpEthCmacRxTxWrapper#(
        GT_LANE_WIDTH, 
        XDMA_AXIS_TDATA_WIDTH,
        XDMA_AXIS_TKEEP_WIDTH,
        XDMA_AXIS_TUSER_WIDTH
    ) udpIpArpEthCmacRxTxWrapperInst(
        .udp_clk   (  udp_clk),
        .udp_reset (udp_reset),

        .gt1_ref_clk_p(gt_ref_clk_p),
        .gt1_ref_clk_n(gt_ref_clk_n),
        .gt1_init_clk (init_clk    ),
        .gt1_sys_reset(sys_reset   ),

        .gt2_ref_clk_p(gt_ref_clk_p),
        .gt2_ref_clk_n(gt_ref_clk_n),
        .gt2_init_clk (init_clk    ),
        .gt2_sys_reset(sys_reset   ),

        .xdma_rx_axis_tready(xdma_rx_axis_tready),
        .xdma_rx_axis_tvalid(xdma_rx_axis_tvalid),
        .xdma_rx_axis_tdata (xdma_rx_axis_tdata),
        .xdma_rx_axis_tkeep (xdma_rx_axis_tkeep),
        .xdma_rx_axis_tlast (xdma_rx_axis_tlast),
        .xdma_rx_axis_tuser (xdma_rx_axis_tuser),

        .xdma_tx_axis_tvalid(xdma_tx_axis_tvalid),
        .xdma_tx_axis_tready(xdma_tx_axis_tready),
        .xdma_tx_axis_tlast (xdma_tx_axis_tlast),
        .xdma_tx_axis_tdata (xdma_tx_axis_tdata),
        .xdma_tx_axis_tkeep (xdma_tx_axis_tkeep),
        .xdma_tx_axis_tuser (xdma_tx_axis_tuser),

        // Serdes
        .gt1_rxn_in (gt1_rx_n),
        .gt1_rxp_in (gt1_rx_p),
        .gt1_txn_out(gt1_tx_n),
        .gt1_txp_out(gt1_tx_p),
        
        .gt2_rxn_in (gt1_tx_n),
        .gt2_rxp_in (gt1_tx_p),
        .gt2_txn_out(gt1_rx_n),
        .gt2_txp_out(gt1_rx_p)
    );

    mkTestXdmaUdpIpArpEthCmacRxTxWithClk testbench (
        
        .xdma_rx_axis_tready(xdma_rx_axis_tready),
        .xdma_rx_axis_tvalid(xdma_rx_axis_tvalid),
        .xdma_rx_axis_tdata (xdma_rx_axis_tdata),
        .xdma_rx_axis_tkeep (xdma_rx_axis_tkeep),
        .xdma_rx_axis_tlast (xdma_rx_axis_tlast),
        .xdma_rx_axis_tuser (xdma_rx_axis_tuser),

        .xdma_tx_axis_tvalid(xdma_tx_axis_tvalid),
        .xdma_tx_axis_tready(xdma_tx_axis_tready),
        .xdma_tx_axis_tlast (xdma_tx_axis_tlast),
        .xdma_tx_axis_tdata (xdma_tx_axis_tdata),
        .xdma_tx_axis_tkeep (xdma_tx_axis_tkeep),
        .xdma_tx_axis_tuser (xdma_tx_axis_tuser),

		.gt_ref_clk_p(gt_ref_clk_p),
		.gate_gt_ref_clk_p(),

		.gt_ref_clk_n(gt_ref_clk_n),
		.gate_gt_ref_clk_n(),

		.init_clk(init_clk),
		.gate_init_clk(),

		.udp_clk(udp_clk),
		.gate_udp_clk(),

		.sys_reset(sys_reset),
		.udp_reset(udp_reset)
    );



endmodule
